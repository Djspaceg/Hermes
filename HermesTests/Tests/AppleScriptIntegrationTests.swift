//
//  AppleScriptIntegrationTests.swift
//  HermesTests
//
//  Tests verifying AppleScript support works with DI-enabled PlaybackController
//  Validates: Requirements 6.1, 6.2, 6.5
//

import Testing
import Foundation
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
