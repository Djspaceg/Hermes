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

    @Test("stop keeps the widget snapshot idle after a retained song state notification")
    @MainActor
    func stopKeepsNowPlayingSnapshotIdle() throws {
        let suiteName = "com.hermes.tests.now-playing-stop.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HermesNowPlayingStopTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false
        )
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: directory)
        }

        let store = NowPlayingSnapshotStore(containerURL: directory)
        let controller = PlaybackController(
            userDefaults: userDefaults,
            nowPlayingSnapshotStore: store
        )
        let station = Station()
        station.name = "Test Station"
        let song = Song.mock(
            title: "Retained Song",
            artist: "Test Artist",
            album: "Test Album"
        )
        station.setPlayingSongForTesting(song)
        controller.selectStationForSystemEventTesting(station)
        try store.write(
            snapshot: NowPlayingSnapshot(
                title: song.title,
                artist: song.artist,
                album: song.album,
                stationName: station.name,
                playbackState: .paused,
                rating: song.rating,
                duration: 120,
                elapsedTime: 30,
                playbackStartDate: Date(),
                artworkFilename: nil
            ),
            artworkData: Data([1, 2, 3])
        )

        controller.setup()
        controller.stop()
        NotificationCenter.default.post(name: ASStatusChangedNotification, object: station)

        #expect(store.readSnapshot() == .idle)
    }
}

@Suite("Playback Progress Watchdog")
struct PlaybackProgressWatchdogTests {

    @Test("Progress beyond duration tolerance advances stalled playback")
    @MainActor
    func testProgressBeyondDurationToleranceIsStalled() {
        #expect(
            PlaybackController.progressExceededStallTolerance(
                progress: 396.0,
                duration: 393.5
            )
        )
        #expect(
            !PlaybackController.progressExceededStallTolerance(
                progress: 395.5,
                duration: 393.5
            )
        )
        #expect(
            !PlaybackController.progressExceededStallTolerance(
                progress: 1.0,
                duration: 0
            )
        )
    }
}

@Suite("System Event Resume Ownership", .serialized)
struct SystemEventResumeOwnershipTests {
    @MainActor
    private func makeController(
        userDefaults: UserDefaults,
        notificationCenter: NotificationCenter
    ) -> (PlaybackController, Station) {
        let controller = PlaybackController(
            userDefaults: userDefaults,
            systemEventNotificationSource: LocalSystemEventNotificationSource(
                center: notificationCenter
            )
        )
        let station = Station()
        station.name = "System event test station"
        station.stationId = "system-event-test-station"
        controller.selectStationForSystemEventTesting(station)
        controller.setupSystemEventObservers()
        return (controller, station)
    }

    private func observePlayAttempts(
        for station: Station
    ) -> (ThreadSafeNotificationCount, NSObjectProtocol) {
        let playAttempts = ThreadSafeNotificationCount()
        let observer = NotificationCenter.default.addObserver(
            forName: ASNoSongsLeft,
            object: station,
            queue: nil
        ) { _ in
            playAttempts.increment()
        }
        return (playAttempts, observer)
    }

    @Test("unlock does not play when lock did not pause")
    @MainActor
    func testUnlockDoesNotPlayWhenLockDidNotPause() async throws {
        let suiteName = "com.hermes.tests.system-events.\(UUID().uuidString)"
        let testDefaults = try #require(UserDefaults(suiteName: suiteName))
        let notificationCenter = NotificationCenter()

        testDefaults.set(true, forKey: UserDefaultsKeys.pauseOnScreenLock)
        testDefaults.set(true, forKey: UserDefaultsKeys.playOnScreenUnlock)

        defer {
            testDefaults.removePersistentDomain(forName: suiteName)
        }

        let (_, station) = makeController(
            userDefaults: testDefaults,
            notificationCenter: notificationCenter
        )

        let (playAttempts, playAttemptObserver) = observePlayAttempts(for: station)

        defer {
            NotificationCenter.default.removeObserver(playAttemptObserver)
        }

        notificationCenter.post(name: .screenIsLocked, object: nil)
        notificationCenter.post(name: .screenIsUnlocked, object: nil)
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(playAttempts.value() == 0)
    }

    @Test("screensaver stop clears its ownership flag when resume is disabled")
    @MainActor
    func testScreensaverStopClearsOwnershipWhenResumeIsDisabled() throws {
        let suiteName = "com.hermes.tests.system-events.\(UUID().uuidString)"
        let testDefaults = try #require(UserDefaults(suiteName: suiteName))
        let notificationCenter = NotificationCenter()

        testDefaults.set(false, forKey: UserDefaultsKeys.playOnScreensaverStop)

        defer {
            testDefaults.removePersistentDomain(forName: suiteName)
        }

        let (controller, station) = makeController(
            userDefaults: testDefaults,
            notificationCenter: notificationCenter
        )
        let (playAttempts, playAttemptObserver) = observePlayAttempts(for: station)

        defer {
            NotificationCenter.default.removeObserver(playAttemptObserver)
        }

        controller.pausedByScreensaver = true
        notificationCenter.post(name: .screensaverDidStop, object: nil)

        #expect(!controller.pausedByScreensaver)

        testDefaults.set(true, forKey: UserDefaultsKeys.playOnScreensaverStop)
        notificationCenter.post(name: .screensaverDidStop, object: nil)

        #expect(playAttempts.value() == 0)
    }

    @Test("enabling screensaver resume after a system pause does not resume")
    @MainActor
    func testEnablingScreensaverResumeAfterSystemPauseDoesNotResume() throws {
        let suiteName = "com.hermes.tests.system-events.\(UUID().uuidString)"
        let testDefaults = try #require(UserDefaults(suiteName: suiteName))
        let notificationCenter = NotificationCenter()

        testDefaults.set(false, forKey: UserDefaultsKeys.playOnScreensaverStop)

        defer {
            testDefaults.removePersistentDomain(forName: suiteName)
        }

        let (controller, station) = makeController(
            userDefaults: testDefaults,
            notificationCenter: notificationCenter
        )
        let (playAttempts, playAttemptObserver) = observePlayAttempts(for: station)

        defer {
            NotificationCenter.default.removeObserver(playAttemptObserver)
        }

        controller.pausedByScreensaver = true
        testDefaults.set(true, forKey: UserDefaultsKeys.playOnScreensaverStop)
        notificationCenter.post(name: .screensaverDidStop, object: nil)

        #expect(!controller.pausedByScreensaver)
        #expect(playAttempts.value() == 0)
    }

    @Test("manual play invalidates a screensaver ownership flag")
    @MainActor
    func testManualPlayInvalidatesScreensaverOwnership() throws {
        let suiteName = "com.hermes.tests.system-events.\(UUID().uuidString)"
        let testDefaults = try #require(UserDefaults(suiteName: suiteName))
        let notificationCenter = NotificationCenter()

        testDefaults.set(true, forKey: UserDefaultsKeys.playOnScreensaverStop)

        defer {
            testDefaults.removePersistentDomain(forName: suiteName)
        }

        let (controller, station) = makeController(
            userDefaults: testDefaults,
            notificationCenter: notificationCenter
        )
        let (playAttempts, playAttemptObserver) = observePlayAttempts(for: station)

        defer {
            NotificationCenter.default.removeObserver(playAttemptObserver)
        }

        controller.pausedByScreensaver = true

        #expect(controller.play())
        #expect(!controller.pausedByScreensaver)
        #expect(playAttempts.value() == 1)

        notificationCenter.post(name: .screensaverDidStop, object: nil)

        #expect(playAttempts.value() == 1)
    }

    @Test("manual stop invalidates a lock ownership flag")
    @MainActor
    func testManualStopInvalidatesScreenLockOwnership() throws {
        let suiteName = "com.hermes.tests.system-events.\(UUID().uuidString)"
        let testDefaults = try #require(UserDefaults(suiteName: suiteName))
        let notificationCenter = NotificationCenter()

        testDefaults.set(true, forKey: UserDefaultsKeys.playOnScreenUnlock)

        defer {
            testDefaults.removePersistentDomain(forName: suiteName)
        }

        let (controller, station) = makeController(
            userDefaults: testDefaults,
            notificationCenter: notificationCenter
        )
        let (playAttempts, playAttemptObserver) = observePlayAttempts(for: station)

        defer {
            NotificationCenter.default.removeObserver(playAttemptObserver)
        }

        controller.pausedByScreenLock = true
        controller.stop()

        #expect(!controller.pausedByScreenLock)

        notificationCenter.post(name: .screenIsUnlocked, object: nil)

        #expect(playAttempts.value() == 0)
    }

    @Test("overlapping screen events resume after both conditions end")
    @MainActor
    func testOverlappingScreenEventsResumeAfterBothConditionsEnd() throws {
        let suiteName = "com.hermes.tests.system-events.\(UUID().uuidString)"
        let testDefaults = try #require(UserDefaults(suiteName: suiteName))
        let notificationCenter = NotificationCenter()

        testDefaults.set(true, forKey: UserDefaultsKeys.playOnScreensaverStop)
        testDefaults.set(true, forKey: UserDefaultsKeys.playOnScreenUnlock)

        defer {
            testDefaults.removePersistentDomain(forName: suiteName)
        }

        let (controller, station) = makeController(
            userDefaults: testDefaults,
            notificationCenter: notificationCenter
        )
        let (playAttempts, playAttemptObserver) = observePlayAttempts(for: station)

        defer {
            NotificationCenter.default.removeObserver(playAttemptObserver)
        }

        controller.pausedByScreensaver = true
        controller.canResumeAfterScreensaverPause = true
        notificationCenter.post(name: .screenIsLocked, object: nil)
        notificationCenter.post(name: .screensaverDidStop, object: nil)

        #expect(playAttempts.value() == 0)

        notificationCenter.post(name: .screenIsUnlocked, object: nil)

        #expect(playAttempts.value() == 1)
    }
}
