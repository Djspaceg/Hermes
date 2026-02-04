//
//  Playlist.swift
//  Hermes
//
//  Swift implementation of playlist management for audio streaming.
//  Migrated from Objective-C ASPlaylist.{h,m}
//
//  Manages a queue of audio streams with automatic advancement.
//

import Foundation

// MARK: - Playlist Notifications

/// Notification posted when a new song starts playing (after bitrate is ready)
public let ASNewSongPlaying = Notification.Name("ASNewSongPlaying")

/// Notification posted when there are no songs left in the queue
public let ASNoSongsLeft = Notification.Name("ASNoSongsLeft")

/// Notification posted when the queue is running low on songs (< 2 remaining)
public let ASRunningOutOfSongs = Notification.Name("ASRunningOutOfSongs")

/// Notification posted when a new audio stream is created
public let ASCreatedNewStream = Notification.Name("ASCreatedNewStream")

/// Notification posted when a stream error occurs (network failure or timeout)
public let ASStreamError = Notification.Name("ASStreamError")

/// Notification posted when attempting to play a new song
public let ASAttemptingNewSong = Notification.Name("ASAttemptingNewSong")

// MARK: - PlaylistProtocol

/// Protocol for playlist operations
///
/// This protocol defines the interface for managing a queue of audio streams
/// with automatic advancement between songs.
public protocol PlaylistProtocol: AnyObject {
    
    /// The currently playing URL, or nil if nothing has played yet
    var playing: URL? { get }
    
    /// Volume level for all streams (0.0 to 1.0)
    var volume: Double { get set }
    
    /// Start playing songs on the playlist, or resume playback
    ///
    /// This will send out notifications for more songs if we're running low on songs
    /// or are out of songs completely to play.
    func play()
    
    /// Pause playback on the playlist
    ///
    /// This has no effect if the playlist is already paused or wasn't playing a song.
    func pause()
    
    /// Stop playing the current song and forget about it
    ///
    /// The song is stopped and internally all state about the song is thrown away.
    func stop()
    
    /// Go to the next song in the playlist
    ///
    /// This can trigger notifications about songs running low or associated events.
    func next()
    
    /// Returns true if the stream is currently paused
    func isPaused() -> Bool
    
    /// Returns true if the stream is currently playing
    func isPlaying() -> Bool
    
    /// Returns true if the stream is idle (done)
    func isIdle() -> Bool
    
    /// Returns true if the stream has an error
    func isError() -> Bool
    
    /// Returns the total duration of the current song in seconds
    func duration() -> Double?
    
    /// Returns the current playback progress in seconds
    func progress() -> Double?
    
    /// Retry playing the current stream if it stopped due to a network error
    func retry()
    
    /// Remove all songs from the internal list
    ///
    /// This does not trigger notifications about songs running low.
    func clearSongList()
    
    /// Add a new song to the playlist
    ///
    /// - Parameters:
    ///   - url: The URL of the song to add
    ///   - play: If true and not currently playing, start playback
    func addSong(_ url: URL, play: Bool)
}

// MARK: - Playlist Implementation

/// Manages a queue of audio streams with automatic advancement
///
/// The Playlist class wraps the AudioStreamer for a more robust interface.
/// It manages a queue of songs to play and automatically switches from one
/// song to the next when playback finishes.
///
/// ## Notifications
///
/// The playlist posts the following notifications:
/// - `ASNewSongPlaying`: When a new song starts playing (after bitrate is ready)
/// - `ASNoSongsLeft`: When there are no songs left in the queue
/// - `ASRunningOutOfSongs`: When the queue is running low (< 2 remaining)
/// - `ASCreatedNewStream`: When a new audio stream is created
/// - `ASStreamError`: When a stream error occurs
/// - `ASAttemptingNewSong`: When attempting to play a new song
///
/// ## Usage
///
/// ```swift
/// let playlist = Playlist()
/// playlist.addSong(url1, play: true)
/// playlist.addSong(url2, play: false)
/// // Playlist will automatically advance to url2 when url1 finishes
/// ```
@objc(SwiftPlaylist)
@objcMembers
open class Playlist: NSObject, PlaylistProtocol {
    
    // MARK: - Public Properties
    
    /// The currently playing URL
    public private(set) var playing: URL?
    
    /// Volume level for all streams (0.0 to 1.0)
    public var volume: Double = 1.0 {
        didSet {
            volumeSet = stream?.setVolume(volume) ?? false
        }
    }
    
    // MARK: - Protected Properties (for subclasses)
    
    /// Queue of URLs to play (accessible to subclasses)
    var urls: [URL] = []
    
    /// Number of URLs in the queue
    var urlCount: Int { urls.count }
    
    /// Current audio stream (accessible to subclasses)
    var currentStream: AudioStreamer? { stream }
    
    /// Time to seek to when retrying (accessible to subclasses)
    var lastKnownSeekTime: Double = 0
    
    // MARK: - Private Properties
    
    /// Current audio stream
    private var stream: AudioStreamer?
    
    /// Are we retrying the current URL?
    private var retrying = false
    
    /// Are we in the middle of advancing to the next song?
    private var nexting = false
    
    /// Are we in the middle of stopping?
    private var stopping = false
    
    /// Has the volume been set on the current stream?
    private var volumeSet = false
    
    /// Number of retry attempts
    private var tries: Int = 0
    
    /// Maximum number of retry attempts before giving up
    private let maxRetries = 2
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        urls.reserveCapacity(10)
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Queue Management
    
    /// Remove all songs from the internal list
    open func clearSongList() {
        urls.removeAll()
    }
    
    /// Add a new song to the playlist
    ///
    /// - Parameters:
    ///   - url: The URL of the song to add
    ///   - play: If true and not currently playing, start playback
    public func addSong(_ url: URL, play shouldPlay: Bool) {
        urls.append(url)
        
        if shouldPlay && !isPlaying() {
            play()
        }
    }
    
    // MARK: - Playback Control
    
    /// Start playing songs on the playlist, or resume playback
    public func play() {
        // If we have an existing stream, just resume it
        if let stream = stream {
            stream.play()
            return
        }
        
        // No songs to play
        if urls.isEmpty {
            NotificationCenter.default.post(
                name: ASNoSongsLeft,
                object: self
            )
            return
        }
        
        // Get the next URL from the queue
        playing = urls.removeFirst()
        setAudioStream()
        tries = 0
        
        NotificationCenter.default.post(
            name: ASAttemptingNewSong,
            object: self
        )
        
        stream?.start()
        
        // Notify if running low on songs
        if urls.count < 2 {
            NotificationCenter.default.post(
                name: ASRunningOutOfSongs,
                object: self
            )
        }
    }
    
    /// Pause playback on the playlist
    public func pause() {
        stream?.pause()
    }
    
    /// Stop playing the current song and forget about it
    public func stop() {
        assert(!stopping, "Already stopping")
        stopping = true
        
        stream?.stop()
        
        if let stream = stream {
            NotificationCenter.default.removeObserver(
                self,
                name: nil,
                object: stream
            )
        }
        
        stream = nil
        playing = nil
        stopping = false
    }
    
    /// Go to the next song in the playlist
    public func next() {
        assert(!nexting, "Already advancing to next song")
        nexting = true
        lastKnownSeekTime = 0
        retrying = false
        stop()
        play()
        nexting = false
    }
    
    // MARK: - State Queries
    
    /// Returns true if the stream is currently paused
    public func isPaused() -> Bool {
        return stream?.isPaused ?? false
    }
    
    /// Returns true if the stream is currently playing
    public func isPlaying() -> Bool {
        return stream?.isPlaying ?? false
    }
    
    /// Returns true if the stream is idle (done)
    public func isIdle() -> Bool {
        return stream?.isDone ?? true
    }
    
    /// Returns true if the stream has an error
    public func isError() -> Bool {
        guard let stream = stream else { return false }
        
        if case .done(let reason) = stream.state {
            if case .error = reason {
                return true
            }
        }
        return false
    }
    
    // MARK: - Progress
    
    /// Returns the total duration of the current song in seconds
    public func duration() -> Double? {
        return stream?.duration()
    }
    
    /// Returns the current playback progress in seconds
    public func progress() -> Double? {
        return stream?.progress()
    }
    
    // MARK: - Retry
    
    /// Retry playing the current stream if it stopped due to a network error
    public func retry() {
        if tries > maxRetries {
            // Too many retries means just skip to the next song
            clearSongList()
            next()
            return
        }
        
        tries += 1
        retrying = true
        setAudioStream()
        stream?.start()
    }
    
    // MARK: - Private Methods
    
    /// Set up a new audio stream for the current URL
    private func setAudioStream() {
        // Clean up existing stream
        if let existingStream = stream {
            NotificationCenter.default.removeObserver(
                self,
                name: nil,
                object: existingStream
            )
            existingStream.stop()
        }
        
        guard let url = playing else { return }
        
        // Create new stream
        stream = AudioStreamer.stream(with: url)
        
        guard let stream = stream else { return }
        
        // Post notification about new stream
        NotificationCenter.default.post(
            name: ASCreatedNewStream,
            object: self,
            userInfo: ["stream": stream]
        )
        
        // Set volume
        volumeSet = stream.setVolume(volume)
        
        // Watch for status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStateChanged(_:)),
            name: ASStatusChangedNotification,
            object: stream
        )
        
        // Watch for bitrate ready
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(bitrateReady(_:)),
            name: ASBitrateReadyNotification,
            object: stream
        )
    }
    
    /// Handle bitrate ready notification
    @objc private func bitrateReady(_ notification: Notification) {
        guard notification.object as? AudioStreamer === stream else {
            assertionFailure("Should only receive notifications for the current stream")
            return
        }
        
        guard let url = playing else { return }
        
        // Post new song playing notification
        NotificationCenter.default.post(
            name: ASNewSongPlaying,
            object: self,
            userInfo: ["url": url]
        )
        
        // Seek to last known position if retrying
        if lastKnownSeekTime > 0 {
            if stream?.seekToTime(lastKnownSeekTime) == true {
                retrying = false
                lastKnownSeekTime = 0
            }
        }
    }
    
    /// Handle playback state changes
    @objc private func playbackStateChanged(_ notification: Notification) {
        guard notification.object as? AudioStreamer === stream else {
            assertionFailure("Should only receive notifications for the current stream")
            return
        }
        
        guard let stream = stream else { return }
        
        // Try to set volume if not yet set
        if !volumeSet {
            volumeSet = stream.setVolume(volume)
        }
        
        // Ignore if we're stopping
        if stopping {
            return
        }
        
        // Check for errors
        if case .done(let reason) = stream.state {
            switch reason {
            case .error(let error):
                handleStreamError(error)
                
            case .endOfFile:
                // Song finished naturally, advance to next
                DispatchQueue.main.async { [weak self] in
                    self?.next()
                }
                
            case .stopped:
                // Explicitly stopped, do nothing
                break
            }
        }
    }
    
    /// Handle stream errors
    private func handleStreamError(_ error: AudioStreamerError) {
        // Record current progress for potential retry
        if !retrying {
            lastKnownSeekTime = stream?.progress() ?? 0
        }
        
        switch error {
        case .networkConnectionFailed, .timeout:
            // Network trouble - post error notification so user can retry
            NotificationCenter.default.post(
                name: ASStreamError,
                object: self
            )
            
        default:
            // Other errors - try automatic retry
            DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
                self?.retry()
            }
        }
    }
}
