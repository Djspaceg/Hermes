//
//  PlaylistManagementTests.swift
//  HermesTests
//
//  Additional tests for Playlist management functionality
//  **Validates: Requirements 20.2**
//

import Testing
import Foundation
@testable import Hermes

@Suite("PlaylistManagementTests", .serialized)
struct PlaylistManagementTests {

    private func confirmNotification(
        _ name: Notification.Name,
        object: Any?,
        action: () -> Void
    ) async {
        await confirmation("Notification \(name.rawValue)") { confirm in
            let observer = NotificationCenter.default.addObserver(
                forName: name,
                object: object,
                queue: nil
            ) { _ in
                confirm()
            }
            defer {
                NotificationCenter.default.removeObserver(observer)
            }
            action()
        }
    }
    
    // MARK: - Initial State Tests
    
    /// Test playlist initial state
    @Test("Initial State")
    func testInitialState() throws {
        let playlist = Playlist()
        
        // Initial state checks
        #expect((playlist.playing) == nil, "Nothing should be playing initially")
        #expect((playlist.urlCount) == (0), "Queue should be empty initially")
        #expect((playlist.volume) == (1.0), "Default volume should be 1.0")
        #expect(playlist.isIdle(), "Should be idle initially")
        #expect(!(playlist.isPlaying()), "Should not be playing initially")
        #expect(!(playlist.isPaused()), "Should not be paused initially")
        #expect(!(playlist.isError()), "Should not have error initially")
        #expect((playlist.progress()) == nil, "Progress should be nil initially")
        #expect((playlist.duration()) == nil, "Duration should be nil initially")
    }
    
    // MARK: - Queue Management Tests
    
    /// Test adding songs maintains FIFO order
    @Test("Add Song Maintains FIFO Order")
    func testAddSongMaintainsFIFOOrder() async throws {
        let playlist = Playlist()
        
        let urls = (1...5).map { URL(string: "http://example.com/song\($0).mp3")! }
        
        // Add songs without playing
        for url in urls {
            playlist.addSong(url, play: false)
        }
        
        #expect((playlist.urlCount) == (5), "Should have 5 songs in queue")
        
        // Start playing - should play first song
        await confirmNotification(ASAttemptingNewSong, object: playlist) {
            playlist.play()
        }
        
        #expect((playlist.playing) == (urls[0]), "Should be playing first song added")
        #expect((playlist.urlCount) == (4), "Queue should have 4 songs remaining")
        
        // Next should play second song
        await confirmNotification(ASAttemptingNewSong, object: playlist) {
            playlist.next()
        }
        
        #expect((playlist.playing) == (urls[1]), "Should be playing second song")
        #expect((playlist.urlCount) == (3), "Queue should have 3 songs remaining")
        
        playlist.stop()
    }
    
    /// Test addSong with play: true starts playback
    @Test("Add Song With Play True")
    func testAddSongWithPlayTrue() async throws {
        let playlist = Playlist()
        let testURL = URL(string: "http://example.com/song.mp3")!
        
        #expect(!(playlist.isPlaying()), "Should not be playing initially")
        
        // Add song with play: true
        await confirmNotification(ASAttemptingNewSong, object: playlist) {
            playlist.addSong(testURL, play: true)
        }
        
        #expect((playlist.playing) == (testURL), "Should be playing the added song")
        #expect((playlist.urlCount) == (0), "Queue should be empty (song moved to playing)")
        
        playlist.stop()
    }
    
    /// Test addSong with play: true doesn't restart if already playing
    @Test("Add Song With Play True Does Not Restart If Playing")
    func testAddSongWithPlayTrueDoesNotRestartIfPlaying() async throws {
        let playlist = Playlist()
        let url1 = URL(string: "http://example.com/song1.mp3")!
        let url2 = URL(string: "http://example.com/song2.mp3")!
        
        // Start playing first song
        await confirmNotification(ASAttemptingNewSong, object: playlist) {
            playlist.addSong(url1, play: true)
        }
        
        #expect((playlist.playing) == (url1), "Should be playing first song")
        
        // Add second song with play: true - should NOT switch to it
        playlist.addSong(url2, play: true)
        
        // Give a moment for any potential state changes
        try await Task.sleep(for: .milliseconds(100))
        
        #expect((playlist.playing) == (url1), "Should still be playing first song")
        #expect((playlist.urlCount) == (1), "Second song should be in queue")
        
        playlist.stop()
    }
    
    /// Test clearSongList removes all queued songs
    @Test("Clear Song List Removes All Queued Songs")
    func testClearSongListRemovesAllQueuedSongs() throws {
        let playlist = Playlist()
        
        // Add multiple songs
        for i in 1...10 {
            let url = URL(string: "http://example.com/song\(i).mp3")!
            playlist.addSong(url, play: false)
        }
        
        #expect((playlist.urlCount) == (10), "Should have 10 songs in queue")
        
        // Clear the list
        playlist.clearSongList()
        
        #expect((playlist.urlCount) == (0), "Queue should be empty after clear")
    }
    
    /// Test clearSongList doesn't affect currently playing song
    @Test("Clear Song List Does Not Affect Currently Playing")
    func testClearSongListDoesNotAffectCurrentlyPlaying() async throws {
        let playlist = Playlist()
        let url1 = URL(string: "http://example.com/song1.mp3")!
        let url2 = URL(string: "http://example.com/song2.mp3")!
        let url3 = URL(string: "http://example.com/song3.mp3")!
        
        // Add songs and start playing
        playlist.addSong(url1, play: false)
        playlist.addSong(url2, play: false)
        playlist.addSong(url3, play: false)
        
        await confirmNotification(ASAttemptingNewSong, object: playlist) {
            playlist.play()
        }
        
        #expect((playlist.playing) == (url1), "Should be playing first song")
        #expect((playlist.urlCount) == (2), "Should have 2 songs in queue")
        
        // Clear the queue
        playlist.clearSongList()
        
        #expect((playlist.playing) == (url1), "Should still be playing first song")
        #expect((playlist.urlCount) == (0), "Queue should be empty")
        
        playlist.stop()
    }
    
    // MARK: - Volume Tests
    
    /// Test volume can be set before playback
    @Test("Volume Can Be Set Before Playback")
    func testVolumeCanBeSetBeforePlayback() throws {
        let playlist = Playlist()
        
        playlist.volume = 0.5
        #expect((playlist.volume) == (0.5), "Volume should be set to 0.5")
        
        playlist.volume = 0.0
        #expect((playlist.volume) == (0.0), "Volume should be set to 0.0")
        
        playlist.volume = 1.0
        #expect((playlist.volume) == (1.0), "Volume should be set to 1.0")
    }
    
    /// Test volume persists across songs
    @Test("Volume Persists Across Songs")
    func testVolumePersistsAcrossSongs() async throws {
        let playlist = Playlist()
        let url1 = URL(string: "http://example.com/song1.mp3")!
        let url2 = URL(string: "http://example.com/song2.mp3")!
        
        // Set volume before adding songs
        playlist.volume = 0.7
        
        playlist.addSong(url1, play: false)
        playlist.addSong(url2, play: false)
        
        await confirmNotification(ASAttemptingNewSong, object: playlist) {
            playlist.play()
        }
        
        #expect((playlist.volume) == (0.7), "Volume should still be 0.7")
        
        // Move to next song
        await confirmNotification(ASAttemptingNewSong, object: playlist) {
            playlist.next()
        }
        
        #expect((playlist.volume) == (0.7), "Volume should still be 0.7 after next()")
        
        playlist.stop()
    }
    
    // MARK: - Stop Tests
    
    /// Test stop clears playing state
    @Test("Stop Clears Playing State")
    func testStopClearsPlayingState() async throws {
        let playlist = Playlist()
        let testURL = URL(string: "http://example.com/song.mp3")!
        
        playlist.addSong(testURL, play: false)
        
        await confirmNotification(ASAttemptingNewSong, object: playlist) {
            playlist.play()
        }
        
        #expect((playlist.playing) == (testURL), "Should be playing")
        
        playlist.stop()
        
        #expect((playlist.playing) == nil, "Playing should be nil after stop")
        #expect(playlist.isIdle(), "Should be idle after stop")
    }
    
    // MARK: - Pause Tests
    
    /// Test pause when not playing has no effect
    @Test("Pause When Not Playing Has No Effect")
    func testPauseWhenNotPlayingHasNoEffect() throws {
        let playlist = Playlist()
        
        // Pause when nothing is playing
        playlist.pause()
        
        #expect(!(playlist.isPaused()), "Should not be paused")
        #expect(playlist.isIdle(), "Should still be idle")
    }
    
    // MARK: - Notification Tests
    
    /// Test ASRunningOutOfSongs notification when queue is low
    @Test("Running Out Of Songs Notification")
    func testRunningOutOfSongsNotification() async throws {
        let playlist = Playlist()
        let url1 = URL(string: "http://example.com/song1.mp3")!
        
        // Add only one song
        playlist.addSong(url1, play: false)
        
        // Should get running out of songs notification when playing
        await confirmNotification(ASRunningOutOfSongs, object: playlist) {
            playlist.play()
        }
        
        playlist.stop()
    }
    
    /// Test ASCreatedNewStream notification when stream is created
    @Test("Created New Stream Notification")
    func testCreatedNewStreamNotification() async throws {
        let playlist = Playlist()
        let testURL = URL(string: "http://example.com/song.mp3")!
        
        playlist.addSong(testURL, play: false)
        
        await confirmNotification(ASCreatedNewStream, object: playlist) {
            playlist.play()
        }
        
        playlist.stop()
    }
    
    /// Test notification userInfo contains expected data
    @Test("Created New Stream Notification Contains Stream")
    func testCreatedNewStreamNotificationContainsStream() async throws {
        let playlist = Playlist()
        let testURL = URL(string: "http://example.com/song.mp3")!
        
        playlist.addSong(testURL, play: false)
        
        var receivedStream: AudioStreamer?
        await confirmation("Created stream notification") { confirm in
            let observer = NotificationCenter.default.addObserver(
                forName: ASCreatedNewStream,
                object: playlist,
                queue: nil
            ) { notification in
                receivedStream = notification.userInfo?["stream"] as? AudioStreamer
                confirm()
            }
            defer {
                NotificationCenter.default.removeObserver(observer)
            }
            playlist.play()
        }
        
        #expect((receivedStream) != nil, "Notification should contain stream in userInfo")
        
        playlist.stop()
    }
    
    // MARK: - Edge Cases
    
    /// Test playing empty playlist posts ASNoSongsLeft
    @Test("Playing Empty Playlist Posts No Songs Left")
    func testPlayingEmptyPlaylistPostsNoSongsLeft() async throws {
        let playlist = Playlist()

        await confirmNotification(ASNoSongsLeft, object: playlist) {
            playlist.play()
        }
    }
    
    /// Test next() on empty queue posts ASNoSongsLeft
    @Test("Next On Empty Queue Posts No Songs Left")
    func testNextOnEmptyQueuePostsNoSongsLeft() async throws {
        let playlist = Playlist()
        let testURL = URL(string: "http://example.com/song.mp3")!
        
        // Add and play one song
        playlist.addSong(testURL, play: false)
        
        await confirmNotification(ASAttemptingNewSong, object: playlist) {
            playlist.play()
        }
        
        // Now call next() - queue is empty
        await confirmNotification(ASNoSongsLeft, object: playlist) {
            playlist.next()
        }
        
        playlist.stop()
    }
    
    /// Test adding same URL multiple times
    @Test("Adding Same URL Multiple Times")
    func testAddingSameURLMultipleTimes() throws {
        let playlist = Playlist()
        let testURL = URL(string: "http://example.com/song.mp3")!
        
        // Add same URL multiple times
        playlist.addSong(testURL, play: false)
        playlist.addSong(testURL, play: false)
        playlist.addSong(testURL, play: false)
        
        #expect((playlist.urlCount) == (3), "Should have 3 entries for the same URL")
    }
    
    /// Test protocol conformance
    @Test("Playlist Protocol Conformance")
    func testPlaylistProtocolConformance() throws {
        let playlist: PlaylistProtocol = Playlist()
        
        // Verify protocol methods are accessible
        #expect((playlist.playing) == nil)
        #expect((playlist.volume) == (1.0))
        #expect(playlist.isIdle())
        #expect(!(playlist.isPlaying()))
        #expect(!(playlist.isPaused()))
        #expect(!(playlist.isError()))
        #expect((playlist.progress()) == nil)
        #expect((playlist.duration()) == nil)
        
        // Test mutable operations
        playlist.volume = 0.5
        #expect((playlist.volume) == (0.5))
        
        playlist.clearSongList()
        playlist.stop()
    }
}
