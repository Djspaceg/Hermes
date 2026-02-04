//
//  PlaybackController.swift
//  Hermes
//
//  Modern Swift implementation of PlaybackController
//  Replaces Controllers/PlaybackController.{h,m}
//
//  Manages playback state, media keys, and coordination between
//  audio streaming and the Pandora API.
//

import Foundation
import AppKit
import MediaPlayer
import Combine
import OSLog

// MARK: - Notification Names

extension Notification.Name {
    /// Notification posted when playback state changes (playing/paused/stopped)
    static let playbackStateDidChange = Notification.Name("PlaybackStateDidChangeNotification")
    
    /// Notification posted when a new song starts playing
    static let playbackSongDidChange = Notification.Name("PlaybackSongDidChangeNotification")
    
    /// Notification posted when song progress updates
    static let playbackProgressDidChange = Notification.Name("PlaybackProgressDidChangeNotification")
    
    /// Notification posted when album art is loaded
    static let playbackArtDidLoad = Notification.Name("PlaybackArtDidLoadNotification")
}

// MARK: - PlaybackController

/// Playback controller managing audio playback and media integration
///
/// This controller handles the business logic for playing stations,
/// managing playback state, and coordinating with the Pandora API.
/// UI is handled separately by SwiftUI views.
///
/// ## Usage
///
/// ```swift
/// let controller = PlaybackController.shared
/// controller.setup()
/// controller.playStation(station)
/// ```
@MainActor
final class PlaybackController: ObservableObject {
    
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.alexcrichton.Hermes", category: "PlaybackController")
    
    // MARK: - Singleton
    
    /// Shared instance for production use
    static let shared = PlaybackController()
    
    // MARK: - Published Properties
    
    /// The currently playing station
    @Published private(set) var playing: Station?
    
    /// The current song being played
    @Published private(set) var currentSong: Song?
    
    /// The current song's album art as NSImage
    @Published private(set) var artImage: NSImage?
    
    /// Current playback progress in seconds
    @Published private(set) var currentProgress: Double = 0
    
    /// Current song duration in seconds
    @Published private(set) var currentDuration: Double = 0
    
    /// Current volume (0-100)
    @Published var volume: Int {
        didSet {
            var vol = volume
            if vol < 0 { vol = 0 }
            if vol > 100 { vol = 100 }
            
            if vol != volume {
                volume = vol
            }
            
            playing?.volume = Double(vol) / 100.0
            userDefaults.set(vol, forKey: "hermes.volume")
            postStateChange()
        }
    }
    
    // MARK: - Public Properties
    
    /// The current song's album art image data (for Objective-C compatibility)
    private(set) var lastImg: NSData?
    
    /// Whether playback was paused by screensaver
    var pausedByScreensaver: Bool = false
    
    /// Whether playback was paused by screen lock
    var pausedByScreenLock: Bool = false
    
    /// Media remote command center for system media controls
    private(set) var remoteCommandCenter: MPRemoteCommandCenter?
    
    // MARK: - Class Properties
    
    /// Whether to start playing automatically when a station is selected
    static var playOnStart: Bool {
        get { UserDefaults.standard.bool(forKey: "playOnStart") }
        set { UserDefaults.standard.set(newValue, forKey: "playOnStart") }
    }
    
    // MARK: - Private Properties
    
    private let userDefaults: UserDefaults
    private var progressUpdateTimer: Timer?
    private var scrobbleSent: Bool = false
    private var lastImgSrc: String?
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Initialize volume from UserDefaults
        let saved = userDefaults.integer(forKey: "hermes.volume")
        self.volume = saved == 0 ? 100 : saved
        
        logger.info("PlaybackController initialized")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        progressUpdateTimer?.invalidate()
    }
}

// MARK: - Lifecycle

extension PlaybackController {
    
    /// Initialize the controller and set up notification observers
    func setup() {
        logger.info("Setting up PlaybackController")
        
        let center = NotificationCenter.default
        
        // Observe audio stream state changes
        center.addObserver(
            self,
            selector: #selector(playbackStateChanged(_:)),
            name: ASStatusChangedNotification,
            object: nil
        )
        
        // Observe when a new song starts
        center.addObserver(
            self,
            selector: #selector(songPlayed(_:)),
            name: .stationDidPlaySong,
            object: nil
        )
        
        // Observe Pandora API responses
        center.addObserver(
            self,
            selector: #selector(handlePandoraResponse(_:)),
            name: .pandoraDidRateSong,
            object: nil
        )
        
        center.addObserver(
            self,
            selector: #selector(handlePandoraResponse(_:)),
            name: .pandoraDidDeleteFeedback,
            object: nil
        )
        
        center.addObserver(
            self,
            selector: #selector(handlePandoraResponse(_:)),
            name: .pandoraDidTireSong,
            object: nil
        )
        
        // Observe app lifecycle for progress timer management
        center.addObserver(
            self,
            selector: #selector(stopUpdatingProgress),
            name: NSApplication.didHideNotification,
            object: NSApp
        )
        
        center.addObserver(
            self,
            selector: #selector(startUpdatingProgress),
            name: NSApplication.didUnhideNotification,
            object: NSApp
        )
        
        // Screensaver and screen lock notifications
        let distCenter = DistributedNotificationCenter.default()
        
        distCenter.addObserver(
            self,
            selector: #selector(pauseOnScreensaverStart(_:)),
            name: .screensaverDidStart,
            object: nil
        )
        
        distCenter.addObserver(
            self,
            selector: #selector(playOnScreensaverStop(_:)),
            name: .screensaverDidStop,
            object: nil
        )
        
        distCenter.addObserver(
            self,
            selector: #selector(pauseOnScreenLock(_:)),
            name: .screenIsLocked,
            object: nil
        )
        
        distCenter.addObserver(
            self,
            selector: #selector(playOnScreenUnlock(_:)),
            name: .screenIsUnlocked,
            object: nil
        )
        
        // Set up media key handling
        setupMediaKeys()
        
        logger.info("PlaybackController setup complete")
    }
    
    /// Prepare for first use (already handled in init)
    func prepareFirst() {
        // Volume is now loaded in init
        logger.debug("prepareFirst called (volume already loaded)")
    }
}

// MARK: - Media Keys

extension PlaybackController {
    
    /// Set up or tear down media key handlers based on user preference
    func setupMediaKeys() {
        // Use MPRemoteCommandCenter for system media controls
        // This is the modern, built-in macOS API for media key handling
        remoteCommandCenter = MPRemoteCommandCenter.shared()
        
        guard let commandCenter = remoteCommandCenter else { return }
        
        let enabled = userDefaults.bool(forKey: "pleaseBindMedia")
        
        // Remove all existing handlers first to ensure clean state
        // This allows other apps to receive media key events when disabled
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.likeCommand.removeTarget(nil)
        commandCenter.dislikeCommand.removeTarget(nil)
        
        if !enabled {
            logger.info("Media keys disabled - handlers removed")
            return
        }
        
        // Add handlers when enabled using closure-based API
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            return self.play() ? .success : .commandFailed
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            return self.pause() ? .success : .commandFailed
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.next()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.playpause()
            return .success
        }
        
        commandCenter.likeCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.likeCurrent()
            return .success
        }
        
        commandCenter.dislikeCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.dislikeCurrent()
            return .success
        }
        
        logger.info("Media keys enabled via MPRemoteCommandCenter")
    }
}

// MARK: - Station Management

extension PlaybackController {
    
    /// Play a station (or nil to stop)
    func playStation(_ station: Station?) {
        if playing?.stationId == station?.stationId {
            return
        }
        
        if let currentStation = playing {
            currentStation.stop()
            if let art = currentStation.playingSong?.art {
                ImageCache.shared.cancel(art)
            }
        }
        
        playing = station
        
        guard let station = station else {
            userDefaults.removeObject(forKey: "lastStation")
            lastImgSrc = nil
            postStateChange()
            return
        }
        
        userDefaults.set(station.stationId, forKey: "lastStation")
        
        if Self.playOnStart {
            station.play()
        } else {
            Self.playOnStart = true
        }
        
        station.volume = Double(volume) / 100.0
        postStateChange()
    }
    
    /// Reset playback state and clear saved station
    func reset() {
        playStation(nil)
        
        if let path = stateDirectory("station.savestate") {
            try? FileManager.default.removeItem(atPath: path)
        }
    }
    
    /// Save current playback state
    @discardableResult
    func saveState() -> Bool {
        guard let path = stateDirectory("station.savestate"),
              let station = playing else {
            return false
        }
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: station, requiringSecureCoding: true)
            try data.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            NSLog("Failed to save state: \(error)")
            return false
        }
    }
    
    /// Get the state directory path for a file
    private func stateDirectory(_ file: String) -> String? {
        let fileManager = FileManager.default
        let folder = NSString(string: "~/Library/Application Support/Hermes/").expandingTildeInPath
        
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: folder, isDirectory: &isDirectory) {
            try? fileManager.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
        }
        
        return (folder as NSString).appendingPathComponent(file)
    }
}

// MARK: - Playback Controls

extension PlaybackController {
    
    /// Start or resume playback
    @discardableResult
    func play() -> Bool {
        guard let station = playing, !station.isPlaying() else {
            return false
        }
        
        station.play()
        postStateChange()
        return true
    }
    
    /// Pause playback
    @discardableResult
    func pause() -> Bool {
        guard let station = playing, station.isPlaying() else {
            return false
        }
        
        station.pause()
        postStateChange()
        return true
    }
    
    /// Stop playback
    func stop() {
        playing?.stop()
        postStateChange()
    }
    
    /// Toggle play/pause
    func playpause() {
        guard let station = playing else { return }
        
        if station.isPaused() {
            play()
        } else {
            pause()
        }
    }
    
    /// Skip to next song
    func next() {
        if let song = playing?.playingSong, let art = song.art {
            ImageCache.shared.cancel(art)
        }
        playing?.next()
    }
}

// MARK: - Song Rating

extension PlaybackController {
    
    /// Rate a song (like or dislike)
    func rate(_ song: Song, as liked: Bool) {
        guard let station = song.station(), !station.shared else { return }
        
        var rating = liked ? 1 : -1
        
        // Toggle rating if already set
        if song.nrating?.intValue == rating {
            rating = 0
        }
        
        let songIsPlaying = playing?.playingSong === song
        
        if rating == -1 {
            pandora?.rateSong(song, as: false)
            if songIsPlaying {
                next()
            }
        } else if rating == 0 {
            pandora?.deleteRating(song)
        } else if rating == 1 {
            pandora?.rateSong(song, as: true)
        }
        
        postStateChange()
    }
    
    /// Like the current song
    func likeCurrent() {
        guard let song = playing?.playingSong else { return }
        rate(song, as: true)
    }
    
    /// Dislike the current song
    func dislikeCurrent() {
        guard let song = playing?.playingSong else { return }
        playing?.clearSongList()
        rate(song, as: false)
    }
    
    /// Mark current song as "tired of"
    func tiredOfCurrent() {
        guard let station = playing, let song = station.playingSong else { return }
        
        pandora?.tired(of: song)
        next()
    }
    
    /// Get the Pandora client
    private var pandora: PandoraProtocol? {
        // Access AppState on main actor
        return AppState.shared.pandora
    }
}

// MARK: - Volume Control

extension PlaybackController {
    
    /// Increase volume by 5%
    func increaseVolume() {
        volume = volume + 5
    }
    
    /// Decrease volume by 5%
    func decreaseVolume() {
        volume = volume - 5
    }
}

// MARK: - Progress

extension PlaybackController {
    
    /// Start updating progress periodically
    @objc func startUpdatingProgress() {
        guard progressUpdateTimer == nil else { return }
        
        progressUpdateTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
        
        RunLoop.current.add(progressUpdateTimer!, forMode: .common)
    }
    
    /// Stop updating progress
    @objc func stopUpdatingProgress() {
        progressUpdateTimer?.invalidate()
        progressUpdateTimer = nil
    }
    
    /// Update progress and post notification
    private func updateProgress() {
        let prog = playing?.progress() ?? 0
        let dur = playing?.duration() ?? 0
        
        currentProgress = prog
        currentDuration = dur
        
        // Post progress notification
        NotificationCenter.default.post(
            name: .playbackProgressDidChange,
            object: self,
            userInfo: [
                "progress": prog,
                "duration": dur
            ]
        )
        
        // Handle scrobbling
        if !scrobbleSent && dur > 30 && (prog * 2 > dur || prog > 4 * 60) {
            scrobbleSent = true
            // Scrobbling handled by Scrobbler class observing notifications
        }
    }
}

// MARK: - Notification Handlers

extension PlaybackController {
    
    @objc private func playbackStateChanged(_ notification: Notification) {
        let currentlyPlaying = playing?.isPlaying() ?? false
        let currentlyPaused = playing?.isPaused() ?? false
        
        logger.debug("Playback state changed - isPlaying=\(currentlyPlaying), isPaused=\(currentlyPaused)")
        
        if currentlyPlaying {
            startUpdatingProgress()
        } else {
            stopUpdatingProgress()
        }
        
        postStateChange()
        updateNowPlayingInfo()
    }
    
    @objc private func songPlayed(_ notification: Notification) {
        guard let song = playing?.playingSong else { return }
        
        logger.info("Song played - \(song.title) by \(song.artist)")
        
        // Update published property
        currentSong = song
        
        song.playDate = Date()
        scrobbleSent = false
        
        // Load album art
        loadArt(for: song)
        
        // Post song change notification
        postSongChange()
        updateNowPlayingInfo()
    }
    
    private func loadArt(for song: Song) {
        guard song.art != lastImgSrc else { return } // Already loaded
        
        lastImgSrc = song.art
        lastImg = nil
        artImage = nil
        
        guard let artUrl = song.art, !artUrl.isEmpty else {
            postArtLoaded()
            return
        }
        
        ImageCache.shared.loadImageURL(artUrl) { [weak self] data in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.lastImg = data as NSData?
                if let data = data {
                    self.artImage = NSImage(data: data)
                }
                
                self.postArtLoaded()
                self.updateNowPlayingInfo()
            }
        }
    }
    
    @objc private func handlePandoraResponse(_ notification: Notification) {
        postStateChange()
    }
}

// MARK: - System Event Handlers

extension PlaybackController {
    
    @objc private func pauseOnScreensaverStart(_ notification: Notification) {
        guard userDefaults.bool(forKey: "pauseOnScreensaverStart") else { return }
        
        if pause() {
            pausedByScreensaver = true
        }
    }
    
    @objc private func playOnScreensaverStop(_ notification: Notification) {
        guard userDefaults.bool(forKey: "playOnScreensaverStop") else { return }
        
        if pausedByScreensaver {
            play()
        }
        pausedByScreensaver = false
    }
    
    @objc private func pauseOnScreenLock(_ notification: Notification) {
        guard userDefaults.bool(forKey: "pauseOnScreenLock") else { return }
        
        if pause() {
            pausedByScreenLock = true
        }
    }
    
    @objc private func playOnScreenUnlock(_ notification: Notification) {
        guard userDefaults.bool(forKey: "playOnScreenUnlock") else { return }
        
        if pausedByScreenLock {
            play()
        }
        pausedByScreenLock = false
    }
}

// MARK: - Now Playing Info

extension PlaybackController {
    
    /// Update the Now Playing info center with current song info
    private func updateNowPlayingInfo() {
        guard let song = playing?.playingSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var info: [String: Any] = [:]
        
        info[MPMediaItemPropertyTitle] = song.title
        info[MPMediaItemPropertyArtist] = song.artist
        info[MPMediaItemPropertyAlbumTitle] = song.album
        
        let duration = currentDuration
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentProgress
        }
        
        info[MPNowPlayingInfoPropertyPlaybackRate] = (playing?.isPlaying() ?? false) ? 1.0 : 0.0
        
        if let image = artImage {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { [weak self] _ in
                return self?.artImage ?? NSImage()
            }
            info[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

// MARK: - Notification Posting

extension PlaybackController {
    
    /// Post state change notification
    private func postStateChange() {
        NotificationCenter.default.post(
            name: .playbackStateDidChange,
            object: self
        )
    }
    
    /// Post song change notification
    private func postSongChange() {
        NotificationCenter.default.post(
            name: .playbackSongDidChange,
            object: self
        )
    }
    
    /// Post art loaded notification
    private func postArtLoaded() {
        NotificationCenter.default.post(
            name: .playbackArtDidLoad,
            object: self
        )
    }
}
