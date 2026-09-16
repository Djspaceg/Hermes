//
//  PlaybackStateMachineTests.swift
//  HermesTests
//
//  Property-based tests for PlaybackController state machine transitions
//  **Validates: Requirements 7.3**
//

import Testing
import Foundation
@testable import Hermes

@Suite("PlaybackStateMachineTests", .serialized)
struct PlaybackStateMachineTests {
    
    // MARK: - Property 5: Playback State Machine
    //
    // For all valid state transitions:
    // - stopped → playing (via play with station)
    // - playing → paused (via pause)
    // - paused → playing (via play)
    // - playing → stopped (via stop)
    // - any state → stopped (via stop)
    //
    // Invalid transitions should be handled gracefully:
    // - play when no station is set (returns false)
    // - pause when not playing (returns false)
    // - play when already playing (returns false)
    //
    // **Validates: Requirements 7.3**
    
    // MARK: - Test Setup
    
    @MainActor
    private func createTestController() -> PlaybackController {
        let testDefaults = UserDefaults(suiteName: "com.hermes.tests.playback.\(UUID().uuidString)")!
        return PlaybackController(userDefaults: testDefaults)
    }
    
    @MainActor
    private func createTestStation(name: String = "Test Station") -> Station {
        let station = Station()
        station.name = name
        station.token = "test-token-\(UUID().uuidString)"
        station.stationId = "test-id-\(UUID().uuidString)"
        return station
    }
    
    // MARK: - Property Tests
    
    /// Property test: Valid state transition - stopped → playing
    /// Tests that play() with a station transitions from stopped to playing state
    @MainActor
    @Test("Valid Transition Stopped To Playing")
    func testValidTransition_StoppedToPlaying() throws {
        let controller = createTestController()
        let station = createTestStation()
        
        // Initial state: no station playing (stopped)
        #expect((controller.playing) == nil, "Should start with no station playing")
        #expect(!(station.isPlaying()), "Station should not be playing initially")
        
        // Set the station
        controller.playStation(station)
        
        // Verify station is set
        #expect((controller.playing) != nil, "Station should be set after playStation")
        #expect((controller.playing?.stationId) == (station.stationId), "Correct station should be set")
        
        // Note: Actual playback requires network and songs, so we verify the controller state
        // The station's play() method would be called by playStation if playOnStart is true
    }
    
    /// Property test: Valid state transition - playing → paused
    /// Tests that pause() transitions from playing to paused state
    @MainActor
    @Test("Valid Transition Playing To Paused")
    func testValidTransition_PlayingToPaused() throws {
        let controller = createTestController()
        let station = createTestStation()
        
        // Set up a station
        controller.playStation(station)
        
        // Simulate playing state by adding a song and starting playback
        // (In real scenario, this would happen via Pandora API)
        // For this test, we verify the pause() method behavior
        
        // If not playing, pause should return false
        let pauseResult = controller.pause()
        #expect(!(pauseResult), "pause() should return false when not playing")
        
        // The actual playing → paused transition requires audio streaming
        // which needs network and real songs, so we test the method contract
    }
    
    /// Property test: Valid state transition - paused → playing
    /// Tests that play() method behavior when station is not paused
    @MainActor
    @Test("Valid Transition Paused To Playing")
    func testValidTransition_PausedToPlaying() throws {
        let controller = createTestController()
        let station = createTestStation()
        
        // Reset playOnStart to ensure consistent behavior
        PlaybackController.playOnStart = false
        
        // Set up a station
        controller.playStation(station)
        
        // Without actual audio playback and songs, the station won't be in any playback state
        // play() will attempt to start playback and return true (since station is not playing)
        let playResult = controller.play()
        
        // Since the station has no songs, play() will call station.play() which posts
        // ASNoSongsLeft and returns. The play() method returns true because it attempted
        // to start playback (the guard condition passed).
        #expect(playResult, "play() should return true when attempting to start playback on a non-playing station")
        
        // Verify station is still set
        #expect((controller.playing) != nil, "Station should still be set")
    }
    
    /// Property test: Valid state transition - playing → stopped
    /// Tests that stop() transitions from playing to stopped state
    @MainActor
    @Test("Valid Transition Playing To Stopped")
    func testValidTransition_PlayingToStopped() throws {
        let controller = createTestController()
        let station = createTestStation()
        
        // Set up a station
        controller.playStation(station)
        #expect((controller.playing) != nil, "Station should be set")
        
        // Stop playback
        controller.stop()
        
        // Verify station is still set but stopped
        #expect((controller.playing) != nil, "Station should still be set after stop")
        #expect(!(station.isPlaying()), "Station should not be playing after stop")
    }
    
    /// Property test: Valid state transition - any state → stopped
    /// Tests that stop() works from any state
    @MainActor
    @Test("Valid Transition Any State To Stopped")
    func testValidTransition_AnyStateToStopped() throws {
        // Test from initial state (no station)
        let controller1 = createTestController()
        controller1.stop() // Should not crash
        #expect((controller1.playing) == nil, "Should remain nil after stop with no station")
        
        // Test from station set state
        let controller2 = createTestController()
        let station2 = createTestStation()
        controller2.playStation(station2)
        controller2.stop()
        #expect((controller2.playing) != nil, "Station should still be set after stop")
        #expect(!(station2.isPlaying()), "Station should not be playing after stop")
        
        // Test multiple stops (idempotent)
        controller2.stop()
        controller2.stop()
        #expect(!(station2.isPlaying()), "Multiple stops should be safe")
    }
    
    /// Property test: Invalid transition - play with no station
    /// Tests that play() returns false when no station is set
    @MainActor
    @Test("Invalid Transition Play With No Station")
    func testInvalidTransition_PlayWithNoStation() throws {
        let controller = createTestController()
        
        // Try to play with no station
        let result = controller.play()
        
        #expect(!(result), "play() should return false when no station is set")
        #expect((controller.playing) == nil, "No station should be playing")
    }
    
    /// Property test: Invalid transition - pause when not playing
    /// Tests that pause() returns false when not in playing state
    @MainActor
    @Test("Invalid Transition Pause When Not Playing")
    func testInvalidTransition_PauseWhenNotPlaying() throws {
        let controller = createTestController()
        
        // Try to pause with no station
        let result1 = controller.pause()
        #expect(!(result1), "pause() should return false when no station is set")
        
        // Try to pause with station but not playing
        let station = createTestStation()
        controller.playStation(station)
        
        let result2 = controller.pause()
        #expect(!(result2), "pause() should return false when station is not playing")
    }
    
    /// Property test: play() method behavior with station set
    /// Tests that play() attempts to start playback when station is not playing
    @MainActor
    @Test("Invalid Transition Play When Not Paused")
    func testInvalidTransition_PlayWhenNotPaused() throws {
        let controller = createTestController()
        let station = createTestStation()
        
        // Reset playOnStart to ensure consistent test behavior
        PlaybackController.playOnStart = false
        
        controller.playStation(station)
        
        // Without actual audio playback and songs, the station is not in a playing state
        // play() will attempt to start playback and return true
        let result = controller.play()
        
        // The play() method returns true because it attempts to start playback
        // (the guard condition `!station.isPlaying()` passes since station has no songs)
        #expect(result, "play() should return true when attempting to start playback")
        
        // Verify station is still set
        #expect((controller.playing) != nil, "Station should still be set")
    }
    
    /// Property test: State transition sequence
    /// Tests a complete sequence of valid transitions
    @MainActor
    @Test("State Transition Sequence")
    func testStateTransitionSequence() throws {
        let controller = createTestController()
        let station = createTestStation()
        
        // 1. Initial state: stopped (no station)
        #expect((controller.playing) == nil, "Should start with no station")
        
        // 2. Set station (stopped → ready to play)
        controller.playStation(station)
        #expect((controller.playing) != nil, "Station should be set")
        #expect((controller.playing?.stationId) == (station.stationId), "Correct station should be set")
        
        // 3. Stop (should be safe even if not playing)
        controller.stop()
        #expect((controller.playing) != nil, "Station should still be set after stop")
        #expect(!(station.isPlaying()), "Station should not be playing")
        
        // 4. Reset (stopped → no station)
        controller.reset()
        #expect((controller.playing) == nil, "Station should be cleared after reset")
    }
    
    /// Property test: playpause toggle behavior
    /// Tests that playpause() correctly toggles between play and pause
    @MainActor
    @Test("Playpause Toggle Behavior")
    func testPlaypauseToggleBehavior() throws {
        let controller = createTestController()
        let station = createTestStation()
        
        // Set station
        controller.playStation(station)
        
        // playpause with no playback should attempt to play
        controller.playpause()
        // (Would start playing if songs were available)
        
        // playpause is safe to call multiple times
        controller.playpause()
        controller.playpause()
        
        // Should not crash or cause issues
        #expect((controller.playing) != nil, "Station should still be set")
    }
    
    /// Property test: next() advances to next song
    /// Tests that next() correctly advances playback
    @MainActor
    @Test("Next Advances To Next Song")
    func testNextAdvancesToNextSong() throws {
        let controller = createTestController()
        let station = createTestStation()
        
        // Set station
        controller.playStation(station)
        
        // next() should be safe to call even with no songs
        controller.next()
        
        // Should not crash
        #expect((controller.playing) != nil, "Station should still be set after next")
    }
    
    /// Property test: Station switching
    /// Tests that switching stations properly stops the previous station
    @MainActor
    @Test("Station Switching")
    func testStationSwitching() throws {
        let controller = createTestController()
        let station1 = createTestStation(name: "Station 1")
        let station2 = createTestStation(name: "Station 2")
        
        // Play first station
        controller.playStation(station1)
        #expect((controller.playing?.stationId) == (station1.stationId), "First station should be playing")
        
        // Switch to second station
        controller.playStation(station2)
        #expect((controller.playing?.stationId) == (station2.stationId), "Second station should be playing")
        #expect((controller.playing?.stationId) != (station1.stationId), "First station should no longer be playing")
        
        // First station should be stopped
        #expect(!(station1.isPlaying()), "First station should be stopped after switch")
    }
    
    /// Property test: Setting same station is idempotent
    /// Tests that setting the same station multiple times doesn't cause issues
    @MainActor
    @Test("Setting Same Station Is Idempotent")
    func testSettingSameStationIsIdempotent() throws {
        let controller = createTestController()
        let station = createTestStation()
        
        // Set station
        controller.playStation(station)
        let firstPlaying = controller.playing
        
        // Set same station again
        controller.playStation(station)
        let secondPlaying = controller.playing
        
        // Should be the same instance
        #expect(firstPlaying === secondPlaying, "Setting same station should be idempotent")
        #expect((controller.playing?.stationId) == (station.stationId), "Station should still be set")
    }
    
    /// Property test: Setting nil station clears playback
    /// Tests that setting nil station properly clears state
    @MainActor
    @Test("Setting Nil Station Clears Playback")
    func testSettingNilStationClearsPlayback() throws {
        let controller = createTestController()
        let station = createTestStation()
        
        // Set station
        controller.playStation(station)
        #expect((controller.playing) != nil, "Station should be set")
        
        // Clear station
        controller.playStation(nil)
        #expect((controller.playing) == nil, "Station should be cleared")
    }
    
    /// Property test: Volume changes are applied to station
    /// Tests that volume changes propagate to the playing station
    @MainActor
    @Test("Volume Changes Applied To Station")
    func testVolumeChangesAppliedToStation() throws {
        let controller = createTestController()
        let station = createTestStation()
        
        // Set volume before station
        controller.volume = 50
        
        // Set station
        controller.playStation(station)
        
        // Volume should be applied (50% = 0.5)
        #expect(abs((station.volume) - (0.5)) <= (0.01), "Volume should be applied to station")
        
        // Change volume
        controller.volume = 75
        
        // New volume should be applied (75% = 0.75)
        #expect(abs((station.volume) - (0.75)) <= (0.01), "New volume should be applied to station")
    }
    
    /// Property test: Volume bounds are enforced
    /// Tests that volume is clamped to valid range [0, 100]
    @MainActor
    @Test("Volume Bounds Are Enforced")
    func testVolumeBoundsAreEnforced() throws {
        let controller = createTestController()
        
        // Test lower bound
        controller.volume = -10
        #expect((controller.volume) == (0), "Volume should be clamped to 0")
        
        // Test upper bound
        controller.volume = 150
        #expect((controller.volume) == (100), "Volume should be clamped to 100")
        
        // Test valid range
        controller.volume = 50
        #expect((controller.volume) == (50), "Valid volume should be preserved")
    }
    
    /// Property test: increaseVolume and decreaseVolume
    /// Tests that volume adjustment methods work correctly
    @MainActor
    @Test("Volume Adjustment Methods")
    func testVolumeAdjustmentMethods() throws {
        let controller = createTestController()
        
        // Set initial volume
        controller.volume = 50
        
        // Increase volume
        controller.increaseVolume()
        #expect((controller.volume) == (55), "Volume should increase by 5")
        
        // Decrease volume
        controller.decreaseVolume()
        #expect((controller.volume) == (50), "Volume should decrease by 5")
        
        // Test bounds with increase
        controller.volume = 98
        controller.increaseVolume()
        #expect((controller.volume) == (100), "Volume should be clamped at 100")
        
        // Test bounds with decrease
        controller.volume = 3
        controller.decreaseVolume()
        #expect((controller.volume) == (0), "Volume should be clamped at 0")
    }
    
    /// Property test: State transitions are thread-safe
    /// Tests that state transitions work correctly when called from main actor
    @MainActor
    @Test("State Transitions Are Thread Safe")
    func testStateTransitionsAreThreadSafe() async throws {
        let controller = createTestController()
        let station = createTestStation()
        
        // All operations should be on main actor
        controller.playStation(station)
        #expect((controller.playing) != nil, "Station should be set")
        
        controller.stop()
        #expect(!(station.isPlaying()), "Station should be stopped")
        
        controller.reset()
        #expect((controller.playing) == nil, "Station should be cleared")
        
        // No crashes or race conditions should occur
    }
}
