//
//  PlaylistManagementTests.swift
//  HermesTests
//
//  Additional tests for Playlist management functionality
//  **Validates: Requirements 20.2**
//

import XCTest
@testable import Hermes

final class PlaylistManagementTests: XCTestCase {
    
    // MARK: - Test Lifecycle
    
    override func setUp() {
        super.setUp()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func tearDown() {
        NotificationCenter.default.removeObserver(self)
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    /// Test playlist initial state
    func testInitialState() throws {
        let playlist = Playlist()
        
        // Initial state checks
        XCTAssertNil(playlist.playing, "Nothing should be playing initially")
        XCTAssertEqual(playlist.urlCount, 0, "Queue should be empty initially")
        XCTAssertEqual(playlist.volume, 1.0, "Default volume should be 1.0")
        XCTAssertTrue(playlist.isIdle(), "Should be idle initially")
        XCTAssertFalse(playlist.isPlaying(), "Should not be playing initially")
        XCTAssertFalse(playlist.isPaused(), "Should not be paused initially")
        XCTAssertFalse(playlist.isError(), "Should not have error initially")
        XCTAssertNil(playlist.progress(), "Progress should be nil initially")
        XCTAssertNil(playlist.duration(), "Duration should be nil initially")
    }
    
    // MARK: - Queue Management Tests
    
    /// Test adding songs maintains FIFO order
    func testAddSongMaintainsFIFOOrder() throws {
        let playlist = Playlist()
        
        let urls = (1...5).map { URL(string: "http://example.com/song\($0).mp3")! }
        
        // Add songs without playing
        for url in urls {
            playlist.addSong(url, play: false)
        }
        
        XCTAssertEqual(playlist.urlCount, 5, "Should have 5 songs in queue")
        
        // Start playing - should play first song
        let attemptingExpectation = expectation(forNotification: ASAttemptingNewSong, object: playlist)
        playlist.play()
        wait(for: [attemptingExpectation], timeout: 1.0)
        
        XCTAssertEqual(playlist.playing, urls[0], "Should be playing first song added")
        XCTAssertEqual(playlist.urlCount, 4, "Queue should have 4 songs remaining")
        
        // Next should play second song
        let attemptingExpectation2 = expectation(forNotification: ASAttemptingNewSong, object: playlist)
        playlist.next()
        wait(for: [attemptingExpectation2], timeout: 1.0)
        
        XCTAssertEqual(playlist.playing, urls[1], "Should be playing second song")
        XCTAssertEqual(playlist.urlCount, 3, "Queue should have 3 songs remaining")
        
        playlist.stop()
    }
    
    /// Test addSong with play: true starts playback
    func testAddSongWithPlayTrue() throws {
        let playlist = Playlist()
        let testURL = URL(string: "http://example.com/song.mp3")!
        
        XCTAssertFalse(playlist.isPlaying(), "Should not be playing initially")
        
        // Add song with play: true
        let attemptingExpectation = expectation(forNotification: ASAttemptingNewSong, object: playlist)
        playlist.addSong(testURL, play: true)
        wait(for: [attemptingExpectation], timeout: 1.0)
        
        XCTAssertEqual(playlist.playing, testURL, "Should be playing the added song")
        XCTAssertEqual(playlist.urlCount, 0, "Queue should be empty (song moved to playing)")
        
        playlist.stop()
    }
    
    /// Test addSong with play: true doesn't restart if already playing
    func testAddSongWithPlayTrueDoesNotRestartIfPlaying() throws {
        let playlist = Playlist()
        let url1 = URL(string: "http://example.com/song1.mp3")!
        let url2 = URL(string: "http://example.com/song2.mp3")!
        
        // Start playing first song
        let attemptingExpectation = expectation(forNotification: ASAttemptingNewSong, object: playlist)
        playlist.addSong(url1, play: true)
        wait(for: [attemptingExpectation], timeout: 1.0)
        
        XCTAssertEqual(playlist.playing, url1, "Should be playing first song")
        
        // Add second song with play: true - should NOT switch to it
        playlist.addSong(url2, play: true)
        
        // Give a moment for any potential state changes
        Thread.sleep(forTimeInterval: 0.1)
        
        XCTAssertEqual(playlist.playing, url1, "Should still be playing first song")
        XCTAssertEqual(playlist.urlCount, 1, "Second song should be in queue")
        
        playlist.stop()
    }
    
    /// Test clearSongList removes all queued songs
    func testClearSongListRemovesAllQueuedSongs() throws {
        let playlist = Playlist()
        
        // Add multiple songs
        for i in 1...10 {
            let url = URL(string: "http://example.com/song\(i).mp3")!
            playlist.addSong(url, play: false)
        }
        
        XCTAssertEqual(playlist.urlCount, 10, "Should have 10 songs in queue")
        
        // Clear the list
        playlist.clearSongList()
        
        XCTAssertEqual(playlist.urlCount, 0, "Queue should be empty after clear")
    }
    
    /// Test clearSongList doesn't affect currently playing song
    func testClearSongListDoesNotAffectCurrentlyPlaying() throws {
        let playlist = Playlist()
        let url1 = URL(string: "http://example.com/song1.mp3")!
        let url2 = URL(string: "http://example.com/song2.mp3")!
        let url3 = URL(string: "http://example.com/song3.mp3")!
        
        // Add songs and start playing
        playlist.addSong(url1, play: false)
        playlist.addSong(url2, play: false)
        playlist.addSong(url3, play: false)
        
        let attemptingExpectation = expectation(forNotification: ASAttemptingNewSong, object: playlist)
        playlist.play()
        wait(for: [attemptingExpectation], timeout: 1.0)
        
        XCTAssertEqual(playlist.playing, url1, "Should be playing first song")
        XCTAssertEqual(playlist.urlCount, 2, "Should have 2 songs in queue")
        
        // Clear the queue
        playlist.clearSongList()
        
        XCTAssertEqual(playlist.playing, url1, "Should still be playing first song")
        XCTAssertEqual(playlist.urlCount, 0, "Queue should be empty")
        
        playlist.stop()
    }
    
    // MARK: - Volume Tests
    
    /// Test volume can be set before playback
    func testVolumeCanBeSetBeforePlayback() throws {
        let playlist = Playlist()
        
        playlist.volume = 0.5
        XCTAssertEqual(playlist.volume, 0.5, "Volume should be set to 0.5")
        
        playlist.volume = 0.0
        XCTAssertEqual(playlist.volume, 0.0, "Volume should be set to 0.0")
        
        playlist.volume = 1.0
        XCTAssertEqual(playlist.volume, 1.0, "Volume should be set to 1.0")
    }
    
    /// Test volume persists across songs
    func testVolumePersistsAcrossSongs() throws {
        let playlist = Playlist()
        let url1 = URL(string: "http://example.com/song1.mp3")!
        let url2 = URL(string: "http://example.com/song2.mp3")!
        
        // Set volume before adding songs
        playlist.volume = 0.7
        
        playlist.addSong(url1, play: false)
        playlist.addSong(url2, play: false)
        
        let attemptingExpectation = expectation(forNotification: ASAttemptingNewSong, object: playlist)
        playlist.play()
        wait(for: [attemptingExpectation], timeout: 1.0)
        
        XCTAssertEqual(playlist.volume, 0.7, "Volume should still be 0.7")
        
        // Move to next song
        let attemptingExpectation2 = expectation(forNotification: ASAttemptingNewSong, object: playlist)
        playlist.next()
        wait(for: [attemptingExpectation2], timeout: 1.0)
        
        XCTAssertEqual(playlist.volume, 0.7, "Volume should still be 0.7 after next()")
        
        playlist.stop()
    }
    
    // MARK: - Stop Tests
    
    /// Test stop clears playing state
    func testStopClearsPlayingState() throws {
        let playlist = Playlist()
        let testURL = URL(string: "http://example.com/song.mp3")!
        
        playlist.addSong(testURL, play: false)
        
        let attemptingExpectation = expectation(forNotification: ASAttemptingNewSong, object: playlist)
        playlist.play()
        wait(for: [attemptingExpectation], timeout: 1.0)
        
        XCTAssertEqual(playlist.playing, testURL, "Should be playing")
        
        playlist.stop()
        
        XCTAssertNil(playlist.playing, "Playing should be nil after stop")
        XCTAssertTrue(playlist.isIdle(), "Should be idle after stop")
    }
    
    // MARK: - Pause Tests
    
    /// Test pause when not playing has no effect
    func testPauseWhenNotPlayingHasNoEffect() throws {
        let playlist = Playlist()
        
        // Pause when nothing is playing
        playlist.pause()
        
        XCTAssertFalse(playlist.isPaused(), "Should not be paused")
        XCTAssertTrue(playlist.isIdle(), "Should still be idle")
    }
    
    // MARK: - Notification Tests
    
    /// Test ASRunningOutOfSongs notification when queue is low
    func testRunningOutOfSongsNotification() throws {
        let playlist = Playlist()
        let url1 = URL(string: "http://example.com/song1.mp3")!
        
        // Add only one song
        playlist.addSong(url1, play: false)
        
        // Should get running out of songs notification when playing
        let runningOutExpectation = expectation(forNotification: ASRunningOutOfSongs, object: playlist)
        playlist.play()
        wait(for: [runningOutExpectation], timeout: 1.0)
        
        playlist.stop()
    }
    
    /// Test ASCreatedNewStream notification when stream is created
    func testCreatedNewStreamNotification() throws {
        let playlist = Playlist()
        let testURL = URL(string: "http://example.com/song.mp3")!
        
        playlist.addSong(testURL, play: false)
        
        let createdStreamExpectation = expectation(forNotification: ASCreatedNewStream, object: playlist)
        playlist.play()
        wait(for: [createdStreamExpectation], timeout: 1.0)
        
        playlist.stop()
    }
    
    /// Test notification userInfo contains expected data
    func testCreatedNewStreamNotificationContainsStream() throws {
        let playlist = Playlist()
        let testURL = URL(string: "http://example.com/song.mp3")!
        
        playlist.addSong(testURL, play: false)
        
        var receivedStream: AudioStreamer?
        let createdStreamExpectation = expectation(forNotification: ASCreatedNewStream, object: playlist) { notification in
            receivedStream = notification.userInfo?["stream"] as? AudioStreamer
            return true
        }
        
        playlist.play()
        wait(for: [createdStreamExpectation], timeout: 1.0)
        
        XCTAssertNotNil(receivedStream, "Notification should contain stream in userInfo")
        
        playlist.stop()
    }
    
    // MARK: - Edge Cases
    
    /// Test playing empty playlist posts ASNoSongsLeft
    func testPlayingEmptyPlaylistPostsNoSongsLeft() throws {
        let playlist = Playlist()
        
        let noSongsExpectation = expectation(forNotification: ASNoSongsLeft, object: playlist)
        playlist.play()
        wait(for: [noSongsExpectation], timeout: 1.0)
    }
    
    /// Test next() on empty queue posts ASNoSongsLeft
    func testNextOnEmptyQueuePostsNoSongsLeft() throws {
        let playlist = Playlist()
        let testURL = URL(string: "http://example.com/song.mp3")!
        
        // Add and play one song
        playlist.addSong(testURL, play: false)
        
        let attemptingExpectation = expectation(forNotification: ASAttemptingNewSong, object: playlist)
        playlist.play()
        wait(for: [attemptingExpectation], timeout: 1.0)
        
        // Now call next() - queue is empty
        let noSongsExpectation = expectation(forNotification: ASNoSongsLeft, object: playlist)
        playlist.next()
        wait(for: [noSongsExpectation], timeout: 1.0)
        
        playlist.stop()
    }
    
    /// Test adding same URL multiple times
    func testAddingSameURLMultipleTimes() throws {
        let playlist = Playlist()
        let testURL = URL(string: "http://example.com/song.mp3")!
        
        // Add same URL multiple times
        playlist.addSong(testURL, play: false)
        playlist.addSong(testURL, play: false)
        playlist.addSong(testURL, play: false)
        
        XCTAssertEqual(playlist.urlCount, 3, "Should have 3 entries for the same URL")
    }
    
    /// Test protocol conformance
    func testPlaylistProtocolConformance() throws {
        let playlist: PlaylistProtocol = Playlist()
        
        // Verify protocol methods are accessible
        XCTAssertNil(playlist.playing)
        XCTAssertEqual(playlist.volume, 1.0)
        XCTAssertTrue(playlist.isIdle())
        XCTAssertFalse(playlist.isPlaying())
        XCTAssertFalse(playlist.isPaused())
        XCTAssertFalse(playlist.isError())
        XCTAssertNil(playlist.progress())
        XCTAssertNil(playlist.duration())
        
        // Test mutable operations
        playlist.volume = 0.5
        XCTAssertEqual(playlist.volume, 0.5)
        
        playlist.clearSongList()
        playlist.stop()
    }
}
