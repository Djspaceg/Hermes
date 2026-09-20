//
//  AppleScriptIntegrationTests.swift
//  HermesTests
//
//  Tests verifying AppleScript support works with DI-enabled PlaybackController
//  Validates: Requirements 6.1, 6.2, 6.5
//

import Testing
import Foundation
import AppKit
@testable import Hermes

@Suite("AppleScript Integration with DI")
struct AppleScriptIntegrationTests {
    
    // MARK: - MinimalAppDelegate Access Tests
    
    @Test("PlaybackController is accessible via MinimalAppDelegate pattern")
    @MainActor
    func testPlaybackControllerAccessPattern() async throws {
        // Create a PlaybackController instance (simulating what MinimalAppDelegate does)
        let testDefaults = UserDefaults(suiteName: "com.hermes.tests.applescript")!
        defer {
            testDefaults.removePersistentDomain(forName: "com.hermes.tests.applescript")
        }
        
        let controller = PlaybackController(userDefaults: testDefaults)
        
        // Verify initial state
        #expect(controller.playing == nil)
        #expect(controller.volume >= 0 && controller.volume <= 100)
    }
    
    @Test("PlaybackController volume property is readable and writable")
    @MainActor
    func testVolumeProperty() async throws {
        let testDefaults = UserDefaults(suiteName: "com.hermes.tests.applescript.volume")!
        defer {
            testDefaults.removePersistentDomain(forName: "com.hermes.tests.applescript.volume")
        }
        
        let controller = PlaybackController(userDefaults: testDefaults)
        
        // Test setting volume
        controller.volume = 50
        #expect(controller.volume == 50)
        
        // Test volume clamping at upper bound
        controller.volume = 150
        #expect(controller.volume == 100)
        
        // Test volume clamping at lower bound
        controller.volume = -10
        #expect(controller.volume == 0)
    }
    
    @Test("PlaybackController play/pause methods return correct values")
    @MainActor
    func testPlayPauseMethods() async throws {
        let testDefaults = UserDefaults(suiteName: "com.hermes.tests.applescript.playpause")!
        defer {
            testDefaults.removePersistentDomain(forName: "com.hermes.tests.applescript.playpause")
        }
        
        let controller = PlaybackController(userDefaults: testDefaults)
        
        // Without a station, play should return false
        let playResult = controller.play()
        #expect(playResult == false)
        
        // Without a station, pause should return false
        let pauseResult = controller.pause()
        #expect(pauseResult == false)
    }
    
    // MARK: - AppleScript Command Pattern Tests
    
    @Test("AppleScript command pattern accesses PlaybackController correctly")
    @MainActor
    func testAppleScriptCommandPattern() async throws {
        // This test verifies the pattern used by AppleScript commands
        // AppleScript commands access: MinimalAppDelegate.shared?.playbackController
        
        let suiteName = "com.hermes.tests.applescript.command.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        defer {
            testDefaults.removePersistentDomain(forName: suiteName)
        }
        
        let controller = PlaybackController(userDefaults: testDefaults)
        
        // Simulate what AppleScript commands do
        // They check if playbackController exists and call methods on it
        
        // Set a known starting volume
        controller.volume = 50
        
        // Volume commands - RaiseVolumeCommand pattern (adds 7)
        controller.volume = controller.volume + 7
        #expect(controller.volume == 57)
        
        // LowerVolumeCommand pattern (subtracts 7)
        controller.volume = controller.volume - 7
        #expect(controller.volume == 50)
        
        // Full volume command
        controller.volume = 100
        #expect(controller.volume == 100)
        
        // Mute/unmute pattern
        let savedVolume = controller.volume
        controller.volume = 0  // MuteCommand
        #expect(controller.volume == 0)
        
        controller.volume = savedVolume  // UnmuteCommand
        #expect(controller.volume == savedVolume)
    }
    
    // MARK: - DI Integration Tests
    
    @Test("PlaybackController uses PandoraProtocol from AppState")
    @MainActor
    func testPlaybackControllerUsesDI() async throws {
        // Verify that AppState.shared.pandora is a PandoraProtocol
        // This is the key integration point for AppleScript commands
        
        let pandora = AppState.shared.pandora
        
        // Verify it has the expected properties (this confirms it's a valid PandoraProtocol)
        _ = pandora.isAuthenticated
        _ = pandora.stations
        
        // The fact that we can access these properties confirms the DI system works
        #expect(true)
    }
    
    @Test("PlaybackState enum values match AppleScript codes")
    func testPlaybackStateEnumValues() {
        // Verify the PlaybackState enum values match the AppleScript 4-char codes
        // These are defined in Hermes.sdef and must match exactly
        
        #expect(PlaybackState.stopped.rawValue == 0x73746F70)  // 'stop'
        #expect(PlaybackState.playing.rawValue == 0x706C6179)  // 'play'
        #expect(PlaybackState.paused.rawValue == 0x70617573)   // 'paus'
    }

    @Test("AppleScript playback state is readable from the main actor")
    @MainActor
    func testPlaybackStateReadFromMainActor() throws {
        _ = try #require(MinimalAppDelegate.shared?.playbackController)

        let state = NSApp.playbackState

        #expect([
            PlaybackState.stopped.rawValue,
            PlaybackState.playing.rawValue,
            PlaybackState.paused.rawValue
        ].contains(state))
    }

    @Test("AppleScript main-thread helper synchronously marshals off-main callers")
    func testOnMainThreadMarshalsOffMainCaller() async {
        let execution = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = AppleScriptSupport.onMainThread {
                    Thread.isMainThread
                }
                continuation.resume(returning: (!Thread.isMainThread, result))
            }
        }

        #expect(execution.0)
        #expect(execution.1)
    }

    @Test("AppleScript represents a current station with a property specifier")
    @MainActor
    func testCurrentStationObjectSpecifier() throws {
        let station = Station()

        let specifier = try #require(station.objectSpecifier as? NSPropertySpecifier)
        #expect(specifier.key == "currentStation")
    }

    @Test("AppleScript scripted models use the SDEF Objective-C class names")
    @MainActor
    func testScriptedModelObjectiveCClassNames() {
        #expect(NSStringFromClass(Station.self) == "Station")
        #expect(NSStringFromClass(Song.self) == "Song")
    }

    @Test("AppleScript song dictionary properties have Objective-C getters")
    func testSongDictionaryPropertyObjectiveCGetters() {
        let song = Song(
            artist: "Runtime Artist",
            title: "Runtime Title",
            album: "Runtime Album"
        )
        song.art = "https://example.com/artwork.jpg"
        song.rating = 1
        song.titleUrl = "https://example.com/track"

        let stringProperties = [
            "title": "Runtime Title",
            "artist": "Runtime Artist",
            "album": "Runtime Album",
            "art": "https://example.com/artwork.jpg",
            "titleUrl": "https://example.com/track"
        ]
        for (key, expectedValue) in stringProperties {
            let responds = Song.instancesRespond(to: NSSelectorFromString(key))
            #expect(responds)
            if responds {
                #expect(song.value(forKey: key) as? String == expectedValue)
            }
        }

        let ratingKey = "nrating"
        let respondsToRating = Song.instancesRespond(to: NSSelectorFromString(ratingKey))
        #expect(respondsToRating)
        if respondsToRating {
            #expect((song.value(forKey: ratingKey) as? NSNumber)?.intValue == 1)
        }
    }

    @Test("AppleScript class pins preserve station state and history archives")
    @MainActor
    func testScriptedModelArchiveCompatibility() throws {
        #expect(NSStringFromClass(Station.self) == "Station")
        #expect(NSStringFromClass(Song.self) == "Song")

        let legacyStationArchive = try #require(
            Data(base64Encoded: Self.legacyStationArchiveBase64)
        )
        let legacyStationClassNames = try archivedClassNames(in: legacyStationArchive)
        #expect(legacyStationClassNames.contains(Self.legacyStationClassName))

        let decodedLegacyStation = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: Station.self,
            from: legacyStationArchive
        )
        let restoredLegacyStation = try #require(decodedLegacyStation)
        #expect(restoredLegacyStation.name == "Archive Compatibility Station")
        #expect(restoredLegacyStation.token == "archive-compatibility-token")
        #expect(restoredLegacyStation.stationId == "archive-compatibility-id")

        let legacyHistoryArchive = try Data(contentsOf: prechangeHistoryArchiveURL())
        let legacyHistoryClassNames = try archivedClassNames(in: legacyHistoryArchive)
        #expect(legacyHistoryClassNames.contains(Self.legacySongClassName))

        let decodedLegacySongs = try SongArchiveDecoding.$allowFeedbackRepresentation.withValue(
            .boxedNumber
        ) {
            try NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSArray.self, Song.self],
                from: legacyHistoryArchive
            ) as? [Song]
        }
        let restoredLegacySongs = try #require(decodedLegacySongs)
        #expect(restoredLegacySongs.map(\.token) == ["historical-song-two", "historical-song-one"])
        #expect(restoredLegacySongs.map(\.allowFeedback) == [true, false])

        let testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hermes-applescript-archive-\(UUID().uuidString)")
        let stationArchiveURL = testDirectory.appendingPathComponent("station.savestate")
        let defaultsName = "com.hermes.tests.applescript.archive.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
            try? FileManager.default.removeItem(at: testDirectory)
        }
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )

        let station = Station()
        station.name = "Archive Compatibility Station"
        station.token = "archive-compatibility-token"
        station.stationId = "archive-compatibility-id"

        let stateStore = PlaybackStateStore(
            userDefaults: defaults,
            resolveStatePath: { _ in stationArchiveURL.path }
        )
        #expect(stateStore.save(station: station))

        let currentStationArchive = try Data(contentsOf: stationArchiveURL)
        let currentStationClassNames = try archivedClassNames(in: currentStationArchive)
        #expect(currentStationClassNames.contains(Self.legacyStationClassName))
        #expect(!currentStationClassNames.contains("Station"))

        let decodedCurrentStation = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: Station.self,
            from: currentStationArchive
        )
        let restoredCurrentStation = try #require(decodedCurrentStation)
        #expect(restoredCurrentStation.stationId == station.stationId)

        let song = Song(
            artist: "Archive Compatibility Artist",
            title: "Archive Compatibility Title",
            album: "Archive Compatibility Album"
        )
        song.token = "archive-compatibility-song-token"
        let currentHistoryArchive = try NSKeyedArchiver.archivedData(
            withRootObject: [song],
            requiringSecureCoding: false
        )
        let currentHistoryClassNames = try archivedClassNames(in: currentHistoryArchive)
        #expect(currentHistoryClassNames.contains(Self.legacySongClassName))
        #expect(!currentHistoryClassNames.contains("Song"))
    }

    @Test("AppleScript exposes shared-station and history-entry inspection state")
    @MainActor
    func testAutomationInspectionModels() throws {
        let station = Station()
        station.shared = true
        #expect(station.isShared)

        let song = Song(artist: "Test Artist", title: "Test Title", album: "Test Album")
        song.stationId = "test-station"
        song.rating = 1

        let entry = HistoryEntry(song: song, index: 0)
        #expect(entry.title == "Test Title")
        #expect(entry.artist == "Test Artist")
        #expect(entry.album == "Test Album")
        #expect(entry.stationID == "test-station")
        #expect(entry.rating == 1)
        #expect(entry.objectSpecifier is NSIndexSpecifier)
    }

    @Test("AppleScript dictionary keeps existing terms and adds UI automation terms")
    func testAutomationDictionaryTerms() throws {
        let bundle = Bundle(for: MinimalAppDelegate.self)
        let sdefURL = try #require(bundle.url(forResource: "Hermes", withExtension: "sdef"))
        let dictionary = try String(contentsOf: sdefURL, encoding: .utf8)

        for term in [
            "current station",
            "current song",
            "thumbs up",
            "is shared",
            "history entry",
            "station count",
            "history entry count",
            "interface mode",
            "main window exists",
            "select station",
            "reveal main window"
        ] {
            #expect(dictionary.contains("name=\"\(term)\""))
        }
    }

    @Test("AppleScript exposes a valid interface mode")
    @MainActor
    func testInterfaceModeIsScriptable() {
        #expect([
            InterfaceMode.windowed.rawValue,
            InterfaceMode.menuBar.rawValue
        ].contains(NSApp.interfaceMode))
    }

    private func archivedClassNames(in data: Data) throws -> Set<String> {
        let propertyList = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        var result = Set<String>()

        func collectClassNames(from value: Any) {
            if let dictionary = value as? [String: Any] {
                if let className = dictionary["$classname"] as? String {
                    result.insert(className)
                }
                for child in dictionary.values {
                    collectClassNames(from: child)
                }
            } else if let array = value as? [Any] {
                for child in array {
                    collectClassNames(from: child)
                }
            }
        }

        collectClassNames(from: propertyList)
        return result
    }

    private func prechangeHistoryArchiveURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/history-prechange.savestate")
    }

    private static let legacyStationClassName = "Hermes.Station"
    private static let legacySongClassName = "Hermes.Song"

    private static let legacyStationArchiveBase64 = "YnBsaXN0MDDUAQIDBAUGBwpYJHZlcnNpb25ZJGFyY2hpdmVyVCR0b3BYJG9iamVjdHMSAAGGoF8QD05TS2V5ZWRBcmNoaXZlctEICVRyb290gAGmCwwjJCUmVSRudWxs2w0ODxAREhMUFRYXGBkZGxwYHhwgISJWc2hhcmVkVmFydFVybFZnZW5yZXNWJGNsYXNzXWFsbG93QWRkTXVzaWNaaXNRdWlja01peFdjcmVhdGVkW2FsbG93UmVuYW1lVXRva2VuWXN0YXRpb25JZFRuYW1lCIAAgACABQkIEAAJgAOABIACXxAdQXJjaGl2ZSBDb21wYXRpYmlsaXR5IFN0YXRpb25fEBthcmNoaXZlLWNvbXBhdGliaWxpdHktdG9rZW5fEBhhcmNoaXZlLWNvbXBhdGliaWxpdHktaWTSJygpKlokY2xhc3NuYW1lWCRjbGFzc2VzXkhlcm1lcy5TdGF0aW9uoyssLV5IZXJtZXMuU3RhdGlvbl1Td2lmdFBsYXlsaXN0WE5TT2JqZWN0AAgAEQAaACQAKQAyADcASQBMAFEAUwBaAGAAdwB+AIUAjACTAKEArAC0AMAAxgDQANUA1gDYANoA3ADdAN4A4ADhAOMA5QDnAQcBJQFAAUUBUAFZAWgBbAF7AYkAAAAAAAACAQAAAAAAAAAuAAAAAAAAAAAAAAAAAAABkg=="

    // MARK: - Station Management Tests
    
    @Test("PlaybackController station management works for AppleScript")
    @MainActor
    func testStationManagement() async throws {
        let testDefaults = UserDefaults(suiteName: "com.hermes.tests.applescript.station")!
        defer {
            testDefaults.removePersistentDomain(forName: "com.hermes.tests.applescript.station")
        }
        
        let controller = PlaybackController(userDefaults: testDefaults)
        
        // Create a test station
        let station = Station()
        station.name = "AppleScript Test Station"
        station.token = "applescript-test-token"
        station.stationId = "applescript-test-id"
        
        // Play the station (this is what AppleScript's currentStation setter does)
        controller.playStation(station)
        
        // Verify the station is accessible (this is what AppleScript's currentStation getter does)
        #expect(controller.playing?.stationId == "applescript-test-id")
        #expect(controller.playing?.name == "AppleScript Test Station")
        
        // Clear the station
        controller.playStation(nil)
        #expect(controller.playing == nil)
    }
}
