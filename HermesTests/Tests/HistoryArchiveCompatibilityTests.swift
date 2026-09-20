//
//  HistoryArchiveCompatibilityTests.swift
//  HermesTests
//

import XCTest
@testable import Hermes

@MainActor
final class HistoryArchiveCompatibilityTests: XCTestCase {
    private var historyURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let environment = ProcessInfo.processInfo.environment
        let testRoot = try XCTUnwrap(environment["HERMES_TEST_ROOT"])
        let canonicalTemporaryDirectory = try XCTUnwrap(
            environment["HERMES_TEST_CANONICAL_TMP"]
        )
        let expectedHome = try XCTUnwrap(environment["HERMES_TEST_HOME"])
        let expectedState = try XCTUnwrap(environment["HERMES_TEST_STATE_PATH"])
        let rootURL = canonicalURL(testRoot)
        let canonicalTemporaryDirectoryURL = canonicalURL(canonicalTemporaryDirectory)
        guard rootURL.path.hasPrefix(canonicalTemporaryDirectoryURL.path + "/hermes-tests."),
              isDescendant(rootURL, of: canonicalTemporaryDirectoryURL) else {
            throw isolationError("Test root is outside the canonical temporary directory")
        }

        let actualHome = canonicalURL(NSHomeDirectory()).path
        let expectedHomePath = canonicalURL(expectedHome).path
        guard actualHome == expectedHomePath else {
            throw isolationError("Expected isolated home \(expectedHomePath), found \(actualHome)")
        }

        let historyPath = NSString(string: "~/Library/Application Support/Hermes/history.savestate")
            .expandingTildeInPath
        let productionHistoryURL = canonicalURL(historyPath)
        let actualStatePath = productionHistoryURL.deletingLastPathComponent().path
        let expectedStatePath = canonicalURL(expectedState).path
        guard actualStatePath == expectedStatePath else {
            throw isolationError("Expected isolated state \(expectedStatePath), found \(actualStatePath)")
        }

        guard isDescendant(productionHistoryURL, of: rootURL) else {
            throw isolationError("History archive path is outside the isolated test root")
        }

        historyURL = rootURL
            .appendingPathComponent("history-archive-compatibility")
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.savestate")
        try FileManager.default.createDirectory(
            at: historyURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try removeHistoryArchives()
    }

    override func tearDownWithError() throws {
        if historyURL != nil {
            try removeHistoryArchives()
        }
        try super.tearDownWithError()
    }

    func testLoadSavedHistoryDecodesPreChangeArchive() async throws {
        try Data(contentsOf: historicalArchiveURL()).write(to: historyURL)

        let history = HistoryViewModel(saveStateURL: historyURL)

        try await waitUntil {
            history.historyItems.map(\.token) == ["historical-song-two", "historical-song-one"]
        }

        XCTAssertEqual(history.historyItems.map(\.allowFeedback), [true, false])
        XCTAssertEqual(history.historyItems.map(\.title), ["Historical Song Two", "Historical Song One"])
    }

    func testUnreadableHistoryArchiveIsPreserved() async throws {
        let unreadableData = Data("not a keyed archive".utf8)
        try unreadableData.write(to: historyURL)

        let history = HistoryViewModel(saveStateURL: historyURL)

        let preservedURL = try await waitForPreservedHistoryArchive()
        XCTAssertEqual(try Data(contentsOf: preservedURL), unreadableData)
        XCTAssertEqual(try Data(contentsOf: historyURL), unreadableData)

        let replacementSong = Song(artist: "Replacement Artist", title: "Replacement Song", album: "Replacement Album")
        replacementSong.token = "replacement-song"
        history.addToHistory(replacementSong)

        try await waitUntil {
            (try? Data(contentsOf: self.historyURL)) != unreadableData
        }
        XCTAssertEqual(try Data(contentsOf: preservedURL), unreadableData)
    }

    func testRepeatedDecodeFailuresDoNotDuplicatePreservedHistory() async throws {
        let unreadableData = Data("not a keyed archive".utf8)
        try unreadableData.write(to: historyURL)

        let firstHistory = HistoryViewModel(saveStateURL: historyURL)
        let secondHistory = HistoryViewModel(saveStateURL: historyURL)
        _ = try await waitForPreservedHistoryArchive()
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertNotNil(firstHistory)
        XCTAssertNotNil(secondHistory)
        XCTAssertEqual(try preservedHistoryURLs().count, 1)
    }

    func testProductionHistoryReaderDecodesPrimitiveBoolArchive() async throws {
        try Data(contentsOf: primitiveBoolArchiveURL()).write(to: historyURL)

        let history = HistoryViewModel(saveStateURL: historyURL)

        try await waitUntil {
            history.historyItems.map(\.allowFeedback) == [true, false]
        }
    }

    private func historicalArchiveURL() -> URL {
        fixtureDirectoryURL().appendingPathComponent("history-prechange.savestate")
    }

    private func primitiveBoolArchiveURL() -> URL {
        fixtureDirectoryURL().appendingPathComponent("history-primitive-bool.savestate")
    }

    private func fixtureDirectoryURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    private func removeHistoryArchives() throws {
        let directory = historyURL.deletingLastPathComponent()
        for url in try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) where url.lastPathComponent == historyURL.lastPathComponent ||
                    url.lastPathComponent.hasPrefix("\(historyURL.lastPathComponent).unreadable-") {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func preservedHistoryURLs() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: historyURL.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        ).filter {
            $0.lastPathComponent.hasPrefix("\(historyURL.lastPathComponent).unreadable-")
        }
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTFail("Timed out waiting for history to load")
    }

    private func waitForPreservedHistoryArchive() async throws -> URL {
        let deadline = Date().addingTimeInterval(2)

        while Date() < deadline {
            if let url = try preservedHistoryURLs().first {
                return url
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        throw NSError(
            domain: "HistoryArchiveCompatibilityTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for unreadable history to be preserved"]
        )
    }

    private func isolationError(_ description: String) -> NSError {
        NSError(
            domain: "HistoryArchiveCompatibilityTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }

    private func canonicalURL(_ path: String) -> URL {
        URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
    }

    private func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        candidate.path.hasPrefix(root.path + "/")
    }
}
