//
//  PlaybackStatePersistenceCharacterizationTests.swift
//  HermesTests
//
//  Characterization coverage for PlaybackController persistence ownership.
//

import Foundation
import Testing
import Darwin
@testable import Hermes

@Suite("Playback State Persistence Characterization", .serialized)
struct PlaybackStatePersistenceCharacterizationTests {

    private struct IsolatedPaths {
        let rootDirectory: URL
        let stateDirectory: URL
        let archive: URL
        let lockFile: URL
    }

    private struct ArchiveOwnership {
        enum Contents {
            case file(Data)
            case emptyDirectory
        }

        let systemNumber: UInt64
        let fileNumber: UInt64
        let contents: Contents
    }

    private func requireIsolatedPaths() throws -> IsolatedPaths {
        let environment = ProcessInfo.processInfo.environment
        let rootPath = try #require(environment["HERMES_TEST_ROOT"])
        let canonicalTemporaryDirectoryPath = try #require(
            environment["HERMES_TEST_CANONICAL_TMP"]
        )
        let expectedHomePath = try #require(environment["HERMES_TEST_HOME"])
        let expectedStatePath = try #require(environment["HERMES_TEST_STATE_PATH"])
        let configuredHomePath = try #require(environment["HOME"])
        let fixedHomePath = try #require(environment["CFFIXED_USER_HOME"])
        let configuredTemporaryDirectoryPath = try #require(environment["TMPDIR"])

        try #require(configuredHomePath == expectedHomePath)
        try #require(fixedHomePath == expectedHomePath)

        let rootDirectory = standardizedURL(rootPath)
        let canonicalTemporaryDirectory = standardizedURL(canonicalTemporaryDirectoryPath)
        let expectedHome = standardizedURL(expectedHomePath)
        let expectedStateDirectory = standardizedURL(expectedStatePath)
        let configuredHome = standardizedURL(configuredHomePath)
        let fixedHome = standardizedURL(fixedHomePath)
        let effectiveHome = standardizedURL(NSHomeDirectory())
        let configuredTemporaryDirectory = standardizedURL(configuredTemporaryDirectoryPath)

        try #require(
            rootDirectory.path.hasPrefix(canonicalTemporaryDirectory.path + "/hermes-tests.")
        )
        try #require(isDescendant(rootDirectory, of: canonicalTemporaryDirectory))
        try #require(configuredHome == expectedHome)
        try #require(fixedHome == expectedHome)
        try #require(effectiveHome == expectedHome)
        try #require(isDescendant(expectedHome, of: rootDirectory))
        try #require(isDescendant(configuredTemporaryDirectory, of: rootDirectory))

        let resolvedStateDirectory = standardizedURL(
            NSString(string: "~/Library/Application Support/Hermes/").expandingTildeInPath
        )

        try #require(resolvedStateDirectory == expectedStateDirectory)
        try #require(isDescendant(resolvedStateDirectory, of: expectedHome))
        try #require(isDescendant(resolvedStateDirectory, of: rootDirectory))

        let stateDirectory = rootDirectory.appendingPathComponent(
            "playback-state-characterization-\(UUID().uuidString)"
        )

        return IsolatedPaths(
            rootDirectory: rootDirectory,
            stateDirectory: stateDirectory,
            archive: stateDirectory.appendingPathComponent("station.savestate"),
            lockFile: rootDirectory.appendingPathComponent("playback-state.lock")
        )
    }

    private func standardizedURL(_ path: String) -> URL {
        URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
    }

    private func isDescendant(_ child: URL, of parent: URL) -> Bool {
        let childComponents = child.pathComponents
        let parentComponents = parent.pathComponents

        return childComponents.count > parentComponents.count
            && childComponents.prefix(parentComponents.count).elementsEqual(parentComponents)
    }

    @MainActor
    @Test("current save, read, defaults, failure, empty file, and delete behavior")
    func currentPersistenceContract() throws {
        let paths = try requireIsolatedPaths()
        let lockFileDescriptor = open(
            paths.lockFile.path,
            O_CREAT | O_RDWR,
            S_IRUSR | S_IWUSR
        )
        try #require(lockFileDescriptor >= 0)
        let lockResult = flock(lockFileDescriptor, LOCK_EX | LOCK_NB)
        if lockResult != 0 {
            close(lockFileDescriptor)
        }
        try #require(lockResult == 0)
        defer {
            flock(lockFileDescriptor, LOCK_UN)
            close(lockFileDescriptor)
        }

        let fileManager = FileManager.default
        try #require(!pathEntryExists(at: paths.archive))

        let suiteName = "com.hermes.tests.playback-state.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        var archiveOwnership: ArchiveOwnership?
        let originalPlayOnStart = PlaybackController.playOnStart

        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
            PlaybackController.playOnStart = originalPlayOnStart
        }

        #expect(UserDefaultsKeys.lastStation == "lastStation")
        #expect(UserDefaultsKeys.stationPlayTimestamps == "stationPlayTimestamps")

        PlaybackController.playOnStart = false
        let stateStore = PlaybackStateStore(
            userDefaults: userDefaults,
            resolveStatePath: { _ in
                try? fileManager.createDirectory(
                    at: paths.stateDirectory,
                    withIntermediateDirectories: true
                )
                return paths.archive.path
            }
        )
        let controller = PlaybackController(
            userDefaults: userDefaults,
            playbackStateStore: stateStore
        )

        #expect(!controller.saveState())
        #expect(fileManager.fileExists(atPath: paths.stateDirectory.path))

        let station = makeStation(id: "characterization-id")
        controller.playStation(station)

        let recordedTimestamp = try #require(station.lastPlayedTimestamp)
        #expect(userDefaults.string(forKey: "lastStation") == station.stationId)
        let timestamps = try #require(
            userDefaults.dictionary(forKey: "stationPlayTimestamps") as? [String: TimeInterval]
        )
        #expect(timestamps[station.stationId] == recordedTimestamp)

        let saved = controller.saveState()
        archiveOwnership = try captureArchiveOwnership(at: paths.archive)
        #expect(saved)
        let restoredStation = try readStation(at: paths.archive)
        expectEquivalent(restoredStation, station)

        try #require(
            archiveMatchesOwnership(try #require(archiveOwnership), at: paths.archive)
        )
        controller.reset()
        if !fileManager.fileExists(atPath: paths.archive.path) {
            archiveOwnership = nil
        }
        #expect(controller.playing == nil)
        #expect(userDefaults.string(forKey: "lastStation") == nil)
        #expect(
            userDefaults.dictionary(forKey: "stationPlayTimestamps") as? [String: TimeInterval]
                == timestamps
        )
        #expect(!fileManager.fileExists(atPath: paths.archive.path))

        try #require(!pathEntryExists(at: paths.archive))
        try Data().write(to: paths.archive)
        archiveOwnership = try captureArchiveOwnership(at: paths.archive)
        #expect(try Data(contentsOf: paths.archive).isEmpty)

        let emptyFileStation = makeStation(id: "empty-file-id")
        controller.playStation(emptyFileStation)
        let emptyFileSaved = controller.saveState()
        archiveOwnership = try captureArchiveOwnership(at: paths.archive)
        #expect(emptyFileSaved)
        #expect(!(try Data(contentsOf: paths.archive).isEmpty))
        expectEquivalent(try readStation(at: paths.archive), emptyFileStation)
        try #require(
            archiveMatchesOwnership(try #require(archiveOwnership), at: paths.archive)
        )
        controller.reset()
        if !fileManager.fileExists(atPath: paths.archive.path) {
            archiveOwnership = nil
        }
        #expect(!fileManager.fileExists(atPath: paths.archive.path))

        try #require(!pathEntryExists(at: paths.archive))
        try fileManager.createDirectory(at: paths.archive, withIntermediateDirectories: false)
        archiveOwnership = try captureArchiveOwnership(at: paths.archive)
        let failingStation = makeStation(id: "failure-id")
        controller.playStation(failingStation)
        #expect(!controller.saveState())
        try #require(
            archiveMatchesOwnership(try #require(archiveOwnership), at: paths.archive)
        )
        controller.reset()
        if !fileManager.fileExists(atPath: paths.archive.path) {
            archiveOwnership = nil
        }
        #expect(!fileManager.fileExists(atPath: paths.archive.path))
    }

    private func pathEntryExists(at url: URL) -> Bool {
        var fileStatus = stat()
        return lstat(url.path, &fileStatus) == 0
    }

    private func captureArchiveOwnership(at archive: URL) throws -> ArchiveOwnership {
        let fileManager = FileManager.default
        var fileStatus = stat()
        try #require(lstat(archive.path, &fileStatus) == 0)
        try #require((fileStatus.st_mode & S_IFMT) != S_IFLNK)

        let attributes = try fileManager.attributesOfItem(atPath: archive.path)
        let systemNumber = try #require(attributes[.systemNumber] as? NSNumber)
        let fileNumber = try #require(attributes[.systemFileNumber] as? NSNumber)
        let fileType = try #require(attributes[.type] as? FileAttributeType)

        let contents: ArchiveOwnership.Contents
        switch fileType {
        case .typeRegular:
            contents = .file(try Data(contentsOf: archive))
        case .typeDirectory:
            try #require(fileManager.contentsOfDirectory(atPath: archive.path).isEmpty)
            contents = .emptyDirectory
        default:
            Issue.record("Unexpected archive file type: \(fileType)")
            throw CancellationError()
        }

        return ArchiveOwnership(
            systemNumber: systemNumber.uint64Value,
            fileNumber: fileNumber.uint64Value,
            contents: contents
        )
    }

    private func archiveMatchesOwnership(
        _ ownership: ArchiveOwnership,
        at archive: URL
    ) throws -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: archive.path) else {
            return false
        }

        let attributes = try fileManager.attributesOfItem(atPath: archive.path)
        guard let systemNumber = attributes[.systemNumber] as? NSNumber,
              let fileNumber = attributes[.systemFileNumber] as? NSNumber,
              systemNumber.uint64Value == ownership.systemNumber,
              fileNumber.uint64Value == ownership.fileNumber,
              let fileType = attributes[.type] as? FileAttributeType else {
            return false
        }

        switch ownership.contents {
        case .file(let expectedData):
            guard fileType == .typeRegular else {
                return false
            }
            return try Data(contentsOf: archive) == expectedData
        case .emptyDirectory:
            guard fileType == .typeDirectory else {
                return false
            }
            return try fileManager.contentsOfDirectory(atPath: archive.path).isEmpty
        }
    }

    @MainActor
    private func makeStation(id: String) -> Station {
        let station = Station()
        station.name = "Characterization Station"
        station.token = "characterization-token-\(id)"
        station.stationId = id
        station.created = 1_234_567_890_000
        station.shared = true
        station.allowRename = false
        station.allowAddMusic = false
        station.isQuickMix = true
        station.artUrl = "https://example.com/characterization.jpg"
        station.genres = ["Ambient", "Electronic"]
        return station
    }

    private func readStation(at archive: URL) throws -> Station {
        let archivedData = try Data(contentsOf: archive)
        let station = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: Station.self,
            from: archivedData
        )
        return try #require(station)
    }

    private func expectEquivalent(_ restored: Station, _ original: Station) {
        #expect(restored.name == original.name)
        #expect(restored.token == original.token)
        #expect(restored.stationId == original.stationId)
        #expect(restored.created == original.created)
        #expect(restored.shared == original.shared)
        #expect(restored.allowRename == original.allowRename)
        #expect(restored.allowAddMusic == original.allowAddMusic)
        #expect(restored.isQuickMix == original.isQuickMix)
        #expect(restored.artUrl == original.artUrl)
        #expect(restored.genres == original.genres)
    }
}
