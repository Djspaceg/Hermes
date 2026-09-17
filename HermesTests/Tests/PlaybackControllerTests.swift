//
//  PlaybackControllerTests.swift
//  HermesTests
//
//  Tests for PlaybackController station management
//

import Testing
import Foundation
import Darwin
@testable import Hermes

final class PlaybackStateStoreStub: PlaybackStateStoring {
    var recordedStation: Station?
    var clearSelectionCallCount = 0
    var deleteSavedStateCallCount = 0
    var saveCallCount = 0
    var savedStation: Station?
    var saveResult: Bool

    init(saveResult: Bool = false) {
        self.saveResult = saveResult
    }

    func recordSelection(_ station: Station) {
        recordedStation = station
    }

    func clearSelection() {
        clearSelectionCallCount += 1
    }

    func deleteSavedState() {
        deleteSavedStateCallCount += 1
    }

    func save(station: Station?) -> Bool {
        saveCallCount += 1
        savedStation = station
        return saveResult
    }
}

private final class ThreadSafeNotificationCount: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    func value() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

@Suite("PlaybackController Station Management")
struct PlaybackControllerStationManagementTests {
    
    @Test("playStation sets the playing station")
    @MainActor
    func testPlayStation() async throws {
        let testDefaults = UserDefaults(suiteName: "com.hermes.tests.playback")!
        defer {
            testDefaults.removePersistentDomain(forName: "com.hermes.tests.playback")
        }
        
        let controller = PlaybackController(userDefaults: testDefaults)
        
        // Create a test station
        let station = Station()
        station.name = "Test Station"
        station.token = "test-token-123"
        station.stationId = "test-id-123"
        
        // Play the station
        controller.playStation(station)
        
        // Verify the station is set
        #expect(controller.playing?.stationId == "test-id-123")
        #expect(controller.playing?.name == "Test Station")
        
        // Verify it was saved to our test defaults
        #expect(testDefaults.string(forKey: "lastStation") == "test-id-123")
    }
    
    @Test("playStation with nil clears the playing station")
    @MainActor
    func testPlayStationNil() async throws {
        let testDefaults = UserDefaults(suiteName: "com.hermes.tests.playback")!
        defer {
            testDefaults.removePersistentDomain(forName: "com.hermes.tests.playback")
        }
        
        let controller = PlaybackController(userDefaults: testDefaults)
        
        // Create and set a station first
        let station = Station()
        station.name = "Test Station"
        station.token = "test-token-123"
        station.stationId = "test-id-123"
        controller.playStation(station)
        
        // Verify station is set
        #expect(controller.playing != nil)
        
        // Clear the station
        controller.playStation(nil)
        
        // Verify station is cleared
        #expect(controller.playing == nil)
        #expect(testDefaults.string(forKey: "lastStation") == nil)
    }
    
    @Test("reset clears the playing station")
    @MainActor
    func testReset() async throws {
        let testDefaults = UserDefaults(suiteName: "com.hermes.tests.playback")!
        defer {
            testDefaults.removePersistentDomain(forName: "com.hermes.tests.playback")
        }
        
        let stateStore = PlaybackStateStoreStub()
        let controller = PlaybackController(
            userDefaults: testDefaults,
            playbackStateStore: stateStore
        )
        
        // Create and set a station
        let station = Station()
        station.name = "Test Station"
        station.token = "test-token-123"
        station.stationId = "test-id-123"
        controller.playStation(station)
        
        // Verify station is set
        #expect(controller.playing != nil)
        
        // Reset
        controller.reset()
        
        // Verify station is cleared
        #expect(controller.playing == nil)
        #expect(stateStore.clearSelectionCallCount == 1)
        #expect(stateStore.deleteSavedStateCallCount == 1)
    }
    
    @Test("saveState returns false when no station is playing")
    @MainActor
    func testSaveStateNoStation() async throws {
        let testDefaults = UserDefaults(suiteName: "com.hermes.tests.playback")!
        defer {
            testDefaults.removePersistentDomain(forName: "com.hermes.tests.playback")
        }
        
        let stateStore = PlaybackStateStoreStub()
        let controller = PlaybackController(
            userDefaults: testDefaults,
            playbackStateStore: stateStore
        )
        
        // Try to save state with no station
        let result = controller.saveState()
        
        // Should return false
        #expect(result == false)
        #expect(stateStore.saveCallCount == 1)
        #expect(stateStore.savedStation == nil)
    }

    @Test("state store resolves the archive path before rejecting a missing station")
    func testStateStoreResolvesPathBeforeMissingStationCheck() throws {
        let testDefaults = UserDefaults(suiteName: "com.hermes.tests.playback-state-order")!
        let testDirectory = URL(
            fileURLWithPath: "/tmp/HermesStateOrder-\(UUID().uuidString)"
        )
        let fileManager = FileManager.default
        try #require(!fileManager.fileExists(atPath: testDirectory.path))
        var createdDirectoryIdentity: (systemNumber: UInt64, fileNumber: UInt64)?

        defer {
            testDefaults.removePersistentDomain(forName: "com.hermes.tests.playback-state-order")
            if let createdDirectoryIdentity,
               let attributes = try? fileManager.attributesOfItem(atPath: testDirectory.path),
               let systemNumber = attributes[.systemNumber] as? NSNumber,
               let fileNumber = attributes[.systemFileNumber] as? NSNumber,
               systemNumber.uint64Value == createdDirectoryIdentity.systemNumber,
               fileNumber.uint64Value == createdDirectoryIdentity.fileNumber,
               (try? fileManager.contentsOfDirectory(atPath: testDirectory.path).isEmpty) == true {
                _ = rmdir(testDirectory.path)
            }
        }

        let stateStore = PlaybackStateStore(
            userDefaults: testDefaults,
            resolveStatePath: { file in
                try? fileManager.createDirectory(
                    at: testDirectory,
                    withIntermediateDirectories: false
                )
                return testDirectory.appendingPathComponent(file).path
            }
        )

        #expect(!stateStore.save(station: nil))
        #expect(fileManager.fileExists(atPath: testDirectory.path))
        let createdDirectoryAttributes = try fileManager.attributesOfItem(
            atPath: testDirectory.path
        )
        createdDirectoryIdentity = (
            systemNumber: try #require(
                createdDirectoryAttributes[.systemNumber] as? NSNumber
            ).uint64Value,
            fileNumber: try #require(
                createdDirectoryAttributes[.systemFileNumber] as? NSNumber
            ).uint64Value
        )
    }
    
    @Test("saveState returns true when station is playing")
    @MainActor
    func testSaveStateWithStation() async throws {
        let testDefaults = UserDefaults(suiteName: "com.hermes.tests.playback")!
        defer {
            testDefaults.removePersistentDomain(forName: "com.hermes.tests.playback")
        }
        
        let stateStore = PlaybackStateStoreStub(saveResult: true)
        let controller = PlaybackController(
            userDefaults: testDefaults,
            playbackStateStore: stateStore
        )
        
        // Create and set a station
        let station = Station()
        station.name = "Test Station"
        station.token = "test-token-123"
        station.stationId = "test-id-123"
        controller.playStation(station)
        
        // Save state
        let result = controller.saveState()
        
        #expect(result)
        #expect(stateStore.saveCallCount == 1)
        #expect(stateStore.savedStation === station)
    }
    
    @Test("volume is applied to station when playing")
    @MainActor
    func testVolumeAppliedToStation() async throws {
        let testDefaults = UserDefaults(suiteName: "com.hermes.tests.playback")!
        defer {
            testDefaults.removePersistentDomain(forName: "com.hermes.tests.playback")
        }
        
        let controller = PlaybackController(userDefaults: testDefaults)
        
        // Set volume first
        controller.volume = 75
        
        // Create and play a station
        let station = Station()
        station.name = "Test Station"
        station.token = "test-token-123"
        station.stationId = "test-id-123"
        controller.playStation(station)
        
        // Verify volume was applied to station (75% = 0.75)
        #expect(station.volume == 0.75)
        
        // Verify it was saved to our test defaults
        #expect(testDefaults.integer(forKey: "hermes.volume") == 75)
    }
    
    @Test("playStation with same station does nothing")
    @MainActor
    func testPlayStationSameStation() async throws {
        let testDefaults = UserDefaults(suiteName: "com.hermes.tests.playback")!
        defer {
            testDefaults.removePersistentDomain(forName: "com.hermes.tests.playback")
        }
        
        let controller = PlaybackController(userDefaults: testDefaults)
        
        // Create and play a station
        let station = Station()
        station.name = "Test Station"
        station.token = "test-token-123"
        station.stationId = "test-id-123"
        controller.playStation(station)
        
        let firstPlaying = controller.playing
        
        // Play the same station again
        controller.playStation(station)
        
        // Should be the same instance
        #expect(controller.playing === firstPlaying)
    }
}

@Suite("System Event Resume Ownership", .serialized)
struct SystemEventResumeOwnershipTests {
    @Test("unlock does not play when lock did not pause")
    @MainActor
    func testUnlockDoesNotPlayWhenLockDidNotPause() async throws {
        let suiteName = "com.hermes.tests.system-events.\(UUID().uuidString)"
        let testDefaults = try #require(UserDefaults(suiteName: suiteName))
        let notificationCenter = NotificationCenter()
        let notificationSource = LocalSystemEventNotificationSource(center: notificationCenter)

        testDefaults.set(true, forKey: UserDefaultsKeys.pauseOnScreenLock)
        testDefaults.set(true, forKey: UserDefaultsKeys.playOnScreenUnlock)

        defer {
            testDefaults.removePersistentDomain(forName: suiteName)
        }

        let controller = PlaybackController(
            userDefaults: testDefaults,
            systemEventNotificationSource: notificationSource
        )
        let station = Station()
        station.name = "Selected but not playing"
        station.stationId = "system-event-test-station"
        controller.selectStationForSystemEventTesting(station)
        controller.setupSystemEventObservers()

        let playAttempts = ThreadSafeNotificationCount()
        let playAttemptObserver = NotificationCenter.default.addObserver(
            forName: ASNoSongsLeft,
            object: station,
            queue: nil
        ) { _ in
            playAttempts.increment()
        }

        defer {
            NotificationCenter.default.removeObserver(playAttemptObserver)
        }

        notificationCenter.post(name: .screenIsLocked, object: nil)
        notificationCenter.post(name: .screenIsUnlocked, object: nil)
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(playAttempts.value() == 0)
    }
}
