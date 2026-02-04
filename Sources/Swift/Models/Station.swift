//
//  Station.swift
//  Hermes
//
//  Swift implementation of Station model
//  Extends Playlist for audio playback integration
//

import Foundation

// MARK: - Station

/// Represents a Pandora station with audio playback capabilities
///
/// Station extends Playlist to provide station-specific functionality
/// including song management, rating, and Pandora API integration.
///
/// Note: Named SwiftStation to avoid conflict with Objective-C Station class during migration.
/// Once migration is complete, this can be renamed to Station.
@objc(SwiftStation)
@objcMembers
final class Station: Playlist, NSSecureCoding {
    
    // MARK: - Static Properties
    
    static var supportsSecureCoding: Bool { true }
    
    /// Registry of all stations by token
    private static var stationRegistry: [String: Station] = [:]
    
    // MARK: - Station Properties
    
    /// Station name
    var name: String = ""
    
    /// Station token (used for API calls)
    var token: String = ""
    
    /// Station ID
    var stationId: String = ""
    
    /// Creation timestamp (milliseconds since epoch)
    var created: UInt64 = 0
    
    /// Whether the station is shared
    var shared: Bool = false
    
    /// Whether the station can be renamed
    var allowRename: Bool = true
    
    /// Whether music can be added to the station
    var allowAddMusic: Bool = true
    
    /// Whether this is the QuickMix/Shuffle station
    var isQuickMix: Bool = false
    
    /// Station artwork URL
    var artUrl: String?
    
    /// Station genres
    var genres: [String]?
    
    /// Currently playing song
    private(set) var playingSong: Song?
    
    /// Songs waiting to be played
    private var songs: [Song] = []
    
    /// Reference to the Pandora client
    private weak var radio: PandoraProtocol?
    
    /// Observer for fragment notifications
    private var fragmentObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupObservers()
    }
    
    deinit {
        if let observer = fragmentObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - NSSecureCoding
    
    required init?(coder: NSCoder) {
        super.init()
        
        name = coder.decodeObject(of: NSString.self, forKey: "name") as String? ?? ""
        token = coder.decodeObject(of: NSString.self, forKey: "token") as String? ?? ""
        stationId = coder.decodeObject(of: NSString.self, forKey: "stationId") as String? ?? ""
        created = UInt64(coder.decodeInt64(forKey: "created"))
        shared = coder.decodeBool(forKey: "shared")
        allowRename = coder.decodeBool(forKey: "allowRename")
        allowAddMusic = coder.decodeBool(forKey: "allowAddMusic")
        isQuickMix = coder.decodeBool(forKey: "isQuickMix")
        artUrl = coder.decodeObject(of: NSString.self, forKey: "artUrl") as String?
        
        if let genresArray = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: "genres") as? [String] {
            genres = genresArray
        }
        
        setupObservers()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name")
        coder.encode(token, forKey: "token")
        coder.encode(stationId, forKey: "stationId")
        coder.encode(Int64(created), forKey: "created")
        coder.encode(shared, forKey: "shared")
        coder.encode(allowRename, forKey: "allowRename")
        coder.encode(allowAddMusic, forKey: "allowAddMusic")
        coder.encode(isQuickMix, forKey: "isQuickMix")
        coder.encode(artUrl, forKey: "artUrl")
        coder.encode(genres as NSArray?, forKey: "genres")
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe new song playing notifications from Playlist
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewSongPlaying(_:)),
            name: ASNewSongPlaying,
            object: self
        )
        
        // Observe running out of songs
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRunningOutOfSongs(_:)),
            name: ASRunningOutOfSongs,
            object: self
        )
        
        // Observe no songs left
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNoSongsLeft(_:)),
            name: ASNoSongsLeft,
            object: self
        )
        
        // Observe stream errors
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStreamError(_:)),
            name: ASStreamError,
            object: self
        )
    }
    
    // MARK: - Radio Integration
    
    /// Set the Pandora client reference
    func setRadio(_ pandora: PandoraProtocol?) {
        radio = pandora
        
        // Set up fragment observer for this station
        if let observer = fragmentObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        let notificationName = Notification.Name("hermes.fragment-fetched.\(token)")
        fragmentObserver = NotificationCenter.default.addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleFragmentFetched(notification)
        }
    }
    
    /// Handle network error for the stream
    func streamNetworkError() {
        // Post error notification
        NotificationCenter.default.post(
            name: ASStreamError,
            object: self
        )
    }
    
    /// Apply track gain to the current song
    func applyTrackGain() {
        // Track gain is handled by the audio streamer
        // This is a placeholder for future implementation
    }
    
    // MARK: - Song Management
    
    /// Add a song to the station's queue
    func addSong(_ song: Song) {
        songs.append(song)
        song.stationId = stationId
        
        // Get the audio URL for the song
        if let url = audioURL(for: song) {
            addSong(url, play: false)
        }
    }
    
    /// Get the audio URL for a song based on quality preference
    private func audioURL(for song: Song) -> URL? {
        let quality = UserDefaults.standard.integer(forKey: "audioQuality")
        
        var urlString: String?
        var qualityName: String
        
        // Quality values from Constants.swift: 0=High, 1=Medium, 2=Low
        switch quality {
        case 2: // Low
            urlString = song.lowUrl ?? song.medUrl ?? song.highUrl
            qualityName = "Low"
        case 1: // Medium
            urlString = song.medUrl ?? song.highUrl ?? song.lowUrl
            qualityName = "Medium"
        default: // High (0 or any other value)
            urlString = song.highUrl ?? song.medUrl ?? song.lowUrl
            qualityName = "High"
        }
        
        guard let urlString = urlString, let url = URL(string: urlString) else {
            return nil
        }
        
        return url
    }
    
    /// Clear all songs from the queue
    override func clearSongList() {
        super.clearSongList()
        songs.removeAll()
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleNewSongPlaying(_ notification: Notification) {
        guard notification.object as? Station === self else { return }
        
        // Find the song that matches the playing URL
        if let url = playing, let song = songs.first(where: { audioURL(for: $0) == url }) {
            playingSong = song
            
            // Post station-specific notification
            NotificationCenter.default.post(
                name: .stationDidPlaySong,
                object: self,
                userInfo: ["song": song]
            )
        }
    }
    
    @objc private func handleRunningOutOfSongs(_ notification: Notification) {
        guard notification.object as? Station === self else { return }
        
        // Request more songs from Pandora
        radio?.fetchPlaylist(for: self)
    }
    
    @objc private func handleNoSongsLeft(_ notification: Notification) {
        guard notification.object as? Station === self else { return }
        
        // Request songs from Pandora
        radio?.fetchPlaylist(for: self)
    }
    
    @objc private func handleStreamError(_ notification: Notification) {
        guard notification.object as? Station === self else { return }
        
        // Skip to next song on stream error
        next()
    }
    
    private func handleFragmentFetched(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let newSongs = userInfo["songs"] as? [Song] else {
            return
        }
        
        // Add new songs to the queue
        for song in newSongs {
            addSong(song)
        }
        
        // Start playing if not already
        if !isPlaying() && !isPaused() {
            play()
        }
    }
    
    // MARK: - Static Registry Methods
    
    /// Get a station by token
    static func station(forToken token: String) -> Station? {
        return stationRegistry[token]
    }
    
    /// Convenience initializer for looking up by token
    convenience init?(forToken token: String) {
        guard let existing = Station.stationRegistry[token] else {
            return nil
        }
        // Return nil - caller should use the static method instead
        // This is just for compatibility with existing code
        return nil
    }
    
    /// Add a station to the registry
    static func addStation(_ station: Station) {
        stationRegistry[station.token] = station
    }
    
    /// Remove a station from the registry
    static func removeStation(_ station: Station) {
        stationRegistry.removeValue(forKey: station.token)
    }
    
    /// Clear all stations from the registry
    static func clearAllStations() {
        stationRegistry.removeAll()
    }
    
    // MARK: - Description
    
    override var description: String {
        return "<\(type(of: self)) \(Unmanaged.passUnretained(self).toOpaque()) \(name)>"
    }
}
