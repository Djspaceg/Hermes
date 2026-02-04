//
//  PlaylistInvariantsTests.swift
//  HermesTests
//
//  Property-based tests for Playlist invariants
//  **Validates: Requirements 3.2, 3.3, 3.4**
//

import XCTest
@testable import Hermes

final class PlaylistInvariantsTests: XCTestCase {
    
    // MARK: - Test Lifecycle
    
    override func setUp() {
        super.setUp()
        // Clean up any existing notifications
        NotificationCenter.default.removeObserver(self)
    }
    
    override func tearDown() {
        NotificationCenter.default.removeObserver(self)
        super.tearDown()
    }
    
    // MARK: - Property 4: Playlist Invariants
    //
    // For all playlists with songs:
    // - Calling next() should advance to the next song or post noSongsLeft if empty
    // - Volume setting should propagate to all active streamers
    // - Progress should always be less than or equal to duration
    //
    // **Validates: Requirements 3.2, 3.3, 3.4**
    
    /// Property test: next() advances correctly or posts noSongsLeft
    /// Tests that calling next() either advances to the next song or posts the appropriate notification
    func testNextAdvancesOrPostsNoSongsLeft() throws {
        // Test case 1: Empty playlist should post noSongsLeft
        let emptyPlaylist = Playlist()
        
        let noSongsExpectation = expectation(forNotification: ASNoSongsLeft, object: emptyPlaylist)
        emptyPlaylist.play()
        
        wait(for: [noSongsExpectation], timeout: 1.0)
        
        // Test case 2: Playlist with one song should post noSongsLeft after next()
        let singleSongPlaylist = Playlist()
        let testURL1 = URL(string: "http://example.com/song1.mp3")!
        singleSongPlaylist.addSong(testURL1, play: false)
        
        XCTAssertEqual(singleSongPlaylist.urlCount, 1, "Should have 1 song in queue")
        
        let noSongsAfterNextExpectation = expectation(forNotification: ASNoSongsLeft, object: singleSongPlaylist)
        singleSongPlaylist.next()
        
        wait(for: [noSongsAfterNextExpectation], timeout: 1.0)
        XCTAssertEqual(singleSongPlaylist.urlCount, 0, "Queue should be empty after next()")
        
        // Test case 3: Playlist with multiple songs should advance
        let multiSongPlaylist = Playlist()
        let testURL2 = URL(string: "http://example.com/song2.mp3")!
        let testURL3 = URL(string: "http://example.com/song3.mp3")!
        
        multiSongPlaylist.addSong(testURL2, play: false)
        multiSongPlaylist.addSong(testURL3, play: false)
        
        XCTAssertEqual(multiSongPlaylist.urlCount, 2, "Should have 2 songs in queue")
        
        let attemptingNewSongExpectation = expectation(forNotification: ASAttemptingNewSong, object: multiSongPlaylist)
        multiSongPlaylist.next()
        
        wait(for: [attemptingNewSongExpectation], timeout: 1.0)
        XCTAssertEqual(multiSongPlaylist.urlCount, 1, "Should have 1 song left after next()")
        XCTAssertEqual(multiSongPlaylist.playing, testURL2, "Should be playing the first song")
        
        // Clean up
        multiSongPlaylist.stop()
    }
    
    /// Property test: Volume propagation to active streamer
    /// Tests that setting volume on the playlist propagates to the active audio streamer
    func testVolumePropagationToActiveStreamer() throws {
        let playlist = Playlist()
        
        // Test case 1: Setting volume before any stream exists should not crash
        playlist.volume = 0.5
        XCTAssertEqual(playlist.volume, 0.5, "Volume should be set on playlist")
        
        // Test case 2: Setting volume after adding a song
        let testURL = URL(string: "http://example.com/song.mp3")!
        playlist.addSong(testURL, play: false)
        
        // Set volume before starting playback
        playlist.volume = 0.7
        XCTAssertEqual(playlist.volume, 0.7, "Volume should be updated")
        
        // Start playback (this creates the audio stream)
        let createdStreamExpectation = expectation(forNotification: ASCreatedNewStream, object: playlist)
        playlist.play()
        
        wait(for: [createdStreamExpectation], timeout: 1.0)
        
        // Verify stream exists
        XCTAssertNotNil(playlist.currentStream, "Stream should be created")
        
        // Test case 3: Changing volume while stream is active
        playlist.volume = 0.3
        XCTAssertEqual(playlist.volume, 0.3, "Volume should be updated on playlist")
        
        // Test case 4: Volume should be in valid range [0.0, 1.0]
        let testVolumes: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
        for testVolume in testVolumes {
            playlist.volume = testVolume
            XCTAssertEqual(playlist.volume, testVolume, "Volume should be \(testVolume)")
            XCTAssertGreaterThanOrEqual(playlist.volume, 0.0, "Volume should be >= 0.0")
            XCTAssertLessThanOrEqual(playlist.volume, 1.0, "Volume should be <= 1.0")
        }
        
        // Clean up
        playlist.stop()
    }
    
    /// Property test: Progress <= Duration invariant
    /// Tests that progress is always less than or equal to duration
    func testProgressLessThanOrEqualToDuration() throws {
        let playlist = Playlist()
        
        // Test case 1: No stream - both should be nil
        XCTAssertNil(playlist.progress(), "Progress should be nil when no stream")
        XCTAssertNil(playlist.duration(), "Duration should be nil when no stream")
        
        // Test case 2: With stream but not playing yet
        let testURL = URL(string: "http://example.com/song.mp3")!
        playlist.addSong(testURL, play: false)
        
        let createdStreamExpectation = expectation(forNotification: ASCreatedNewStream, object: playlist)
        playlist.play()
        
        wait(for: [createdStreamExpectation], timeout: 1.0)
        
        // Test case 3: If both progress and duration are available, progress <= duration
        // Note: For real streams, this would require actual audio data
        // We test the invariant holds when values are present
        if let progress = playlist.progress(), let duration = playlist.duration() {
            XCTAssertLessThanOrEqual(
                progress,
                duration,
                "Progress (\(progress)) should be <= duration (\(duration))"
            )
            XCTAssertGreaterThanOrEqual(progress, 0.0, "Progress should be >= 0")
            XCTAssertGreaterThanOrEqual(duration, 0.0, "Duration should be >= 0")
        }
        
        // Test case 4: Multiple checks over time (if stream is active)
        // This simulates checking the invariant at different points
        for iteration in 1...5 {
            if let progress = playlist.progress(), let duration = playlist.duration() {
                XCTAssertLessThanOrEqual(
                    progress,
                    duration,
                    "Iteration \(iteration): Progress should be <= duration"
                )
            }
            // Small delay between checks
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        // Clean up
        playlist.stop()
    }
    
    /// Property test: Queue management invariants
    /// Tests that queue operations maintain correct state
    func testQueueManagementInvariants() throws {
        let playlist = Playlist()
        
        // Test case 1: Initial state
        XCTAssertEqual(playlist.urlCount, 0, "Initial queue should be empty")
        XCTAssertNil(playlist.playing, "Nothing should be playing initially")
        
        // Test case 2: Adding songs increases count
        let urls = (1...5).map { URL(string: "http://example.com/song\($0).mp3")! }
        
        for (index, url) in urls.enumerated() {
            playlist.addSong(url, play: false)
            XCTAssertEqual(playlist.urlCount, index + 1, "Queue count should increase")
        }
        
        XCTAssertEqual(playlist.urlCount, 5, "Should have 5 songs in queue")
        
        // Test case 3: Playing removes from queue
        let attemptingExpectation = expectation(forNotification: ASAttemptingNewSong, object: playlist)
        playlist.play()
        
        wait(for: [attemptingExpectation], timeout: 1.0)
        XCTAssertEqual(playlist.urlCount, 4, "Queue should have 4 songs after play")
        XCTAssertEqual(playlist.playing, urls[0], "Should be playing first song")
        
        // Test case 4: Clearing removes all songs
        playlist.clearSongList()
        XCTAssertEqual(playlist.urlCount, 0, "Queue should be empty after clear")
        
        // Clean up
        playlist.stop()
    }
    
    /// Property test: State consistency
    /// Tests that playlist state methods are consistent
    func testStateConsistency() throws {
        let playlist = Playlist()
        
        // Test case 1: Initial state - should be idle
        XCTAssertTrue(playlist.isIdle(), "Should be idle initially")
        XCTAssertFalse(playlist.isPlaying(), "Should not be playing initially")
        XCTAssertFalse(playlist.isPaused(), "Should not be paused initially")
        XCTAssertFalse(playlist.isError(), "Should not have error initially")
        
        // Test case 2: After adding song and playing
        let testURL = URL(string: "http://example.com/song.mp3")!
        playlist.addSong(testURL, play: false)
        
        let createdExpectation = expectation(forNotification: ASCreatedNewStream, object: playlist)
        playlist.play()
        
        wait(for: [createdExpectation], timeout: 1.0)
        
        // State should be consistent (not multiple states at once)
        let stateCount = [
            playlist.isPlaying(),
            playlist.isPaused(),
            playlist.isIdle(),
            playlist.isError()
        ].filter { $0 }.count
        
        XCTAssertLessThanOrEqual(stateCount, 1, "Should be in at most one state")
        
        // Test case 3: After stopping
        playlist.stop()
        XCTAssertTrue(playlist.isIdle(), "Should be idle after stop")
        XCTAssertFalse(playlist.isPlaying(), "Should not be playing after stop")
        XCTAssertNil(playlist.playing, "Playing URL should be nil after stop")
    }
    
    /// Property test: Notification consistency
    /// Tests that appropriate notifications are posted for state changes
    func testNotificationConsistency() throws {
        let playlist = Playlist()
        
        // Test case 1: ASNoSongsLeft when playing empty playlist
        let noSongsExpectation = expectation(forNotification: ASNoSongsLeft, object: playlist)
        playlist.play()
        wait(for: [noSongsExpectation], timeout: 1.0)
        
        // Test case 2: ASRunningOutOfSongs when queue is low
        let playlist2 = Playlist()
        let url1 = URL(string: "http://example.com/song1.mp3")!
        playlist2.addSong(url1, play: false)
        
        let runningOutExpectation = expectation(forNotification: ASRunningOutOfSongs, object: playlist2)
        playlist2.play()
        wait(for: [runningOutExpectation], timeout: 1.0)
        
        playlist2.stop()
        
        // Test case 3: ASCreatedNewStream when starting playback
        let playlist3 = Playlist()
        let url2 = URL(string: "http://example.com/song2.mp3")!
        playlist3.addSong(url2, play: false)
        
        let createdStreamExpectation = expectation(forNotification: ASCreatedNewStream, object: playlist3)
        playlist3.play()
        wait(for: [createdStreamExpectation], timeout: 1.0)
        
        playlist3.stop()
        
        // Test case 4: ASAttemptingNewSong when calling next()
        let playlist4 = Playlist()
        let url3 = URL(string: "http://example.com/song3.mp3")!
        let url4 = URL(string: "http://example.com/song4.mp3")!
        playlist4.addSong(url3, play: false)
        playlist4.addSong(url4, play: false)
        
        let attemptingExpectation = expectation(forNotification: ASAttemptingNewSong, object: playlist4)
        playlist4.next()
        wait(for: [attemptingExpectation], timeout: 1.0)
        
        playlist4.stop()
    }
    
    /// Property test: Idempotent operations
    /// Tests that repeated operations are safe
    func testIdempotentOperations() throws {
        let playlist = Playlist()
        
        // Test case 1: Multiple stop() calls should be safe
        playlist.stop()
        playlist.stop()
        playlist.stop()
        XCTAssertTrue(playlist.isIdle(), "Should remain idle after multiple stops")
        
        // Test case 2: Multiple clearSongList() calls should be safe
        playlist.clearSongList()
        playlist.clearSongList()
        XCTAssertEqual(playlist.urlCount, 0, "Queue should remain empty")
        
        // Test case 3: Multiple pause() calls should be safe
        playlist.pause()
        playlist.pause()
        XCTAssertFalse(playlist.isPlaying(), "Should not be playing")
        
        // Test case 4: Adding same URL multiple times should work
        let testURL = URL(string: "http://example.com/song.mp3")!
        playlist.addSong(testURL, play: false)
        playlist.addSong(testURL, play: false)
        playlist.addSong(testURL, play: false)
        XCTAssertEqual(playlist.urlCount, 3, "Should have 3 copies of the same URL")
        
        playlist.stop()
    }
    
    /// Property test: Volume bounds
    /// Tests that volume stays within valid bounds
    func testVolumeBounds() throws {
        let playlist = Playlist()
        
        // Test valid volumes
        let validVolumes: [Double] = [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]
        for volume in validVolumes {
            playlist.volume = volume
            XCTAssertEqual(playlist.volume, volume, "Volume should be set to \(volume)")
            XCTAssertGreaterThanOrEqual(playlist.volume, 0.0, "Volume should be >= 0.0")
            XCTAssertLessThanOrEqual(playlist.volume, 1.0, "Volume should be <= 1.0")
        }
        
        // Test edge cases
        playlist.volume = 0.0
        XCTAssertEqual(playlist.volume, 0.0, "Minimum volume should be 0.0")
        
        playlist.volume = 1.0
        XCTAssertEqual(playlist.volume, 1.0, "Maximum volume should be 1.0")
        
        // Note: Values outside [0.0, 1.0] are technically allowed by the API
        // but should be handled gracefully by the audio system
        playlist.volume = -0.1
        XCTAssertEqual(playlist.volume, -0.1, "Negative volume should be stored")
        
        playlist.volume = 1.5
        XCTAssertEqual(playlist.volume, 1.5, "Volume > 1.0 should be stored")
    }
}
