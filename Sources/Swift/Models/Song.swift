//
//  Song.swift
//  Hermes
//
//  Modern Swift implementation of Song model with @Observable support
//

import Foundation
import AppKit
import Observation
import Combine

/// Represents a Pandora song with metadata and playback information.
///
/// `Song` is the core model for representing music tracks in Hermes. It uses the `@Observable`
/// macro for automatic SwiftUI state tracking and extends `NSObject` for compatibility with
/// NSCoding-based persistence (used for listening history).
///
/// ## Topics
///
/// ### Creating Songs
/// - ``init()``
/// - ``init(artist:title:album:)``
/// - ``mock(title:artist:album:artworkURL:rating:)``
///
/// ### Song Metadata
/// - ``artist``
/// - ``title``
/// - ``album``
/// - ``art``
/// - ``artworkURL``
/// - ``token``
///
/// ### Playback Information
/// - ``highUrl``
/// - ``medUrl``
/// - ``lowUrl``
/// - ``trackGain``
///
/// ### Rating and Feedback
/// - ``rating``
/// - ``nrating``
/// - ``allowFeedback``
///
/// ### Station Association
/// - ``stationId``
/// - ``station()``
///
/// ### Play History
/// - ``playDate``
/// - ``playDateString``
///
/// ## Usage
///
/// ```swift
/// // Create a new song
/// let song = Song(artist: "Queen", title: "Bohemian Rhapsody", album: "A Night at the Opera")
///
/// // Access artwork
/// if let artworkURL = song.artworkURL {
///     // Load artwork from URL
/// }
///
/// // Rate the song
/// song.rating = 1  // Like
/// song.rating = -1 // Dislike
/// song.rating = 0  // No rating
///
/// // Get associated station
/// if let station = song.station() {
///     print("Playing on: \(station.name)")
/// }
/// ```
@Observable
final class Song: NSObject, Identifiable {
    // MARK: - Properties
    
    /// The artist name
    var artist: String
    
    /// The song title
    var title: String
    
    /// The album name
    /// The album name
    var album: String
    
    /// The album artwork URL string
    var art: String?
    
    /// The station ID this song belongs to
    var stationId: String?
    
    /// The station token for API calls (needed for rating)
    var stationToken: String?
    
    /// URL for album information
    var albumUrl: String?
    
    /// URL for artist information
    var artistUrl: String?
    
    /// URL for song/title information
    var titleUrl: String?
    
    /// Unique token identifying this song
    var token: String?
    
    /// High quality audio stream URL
    var highUrl: String?
    
    /// Medium quality audio stream URL
    var medUrl: String?
    
    /// Low quality audio stream URL
    var lowUrl: String?
    
    /// Track gain value for volume normalization
    var trackGain: String?
    
    /// Whether feedback (rating) is allowed for this song
    var allowFeedback: Bool = true
    
    /// The date and time this song was played
    var playDate: Date?
    
    /// Rating value: 0 = no rating, 1 = liked, -1 = disliked
    var rating: Int = 0
    
    // MARK: - Private Properties
    
    @ObservationIgnored
    private var ratingCancellable: AnyCancellable?
    
    // MARK: - Computed Properties
    
    /// Unique identifier for the song (uses token or generates UUID)
    var id: String { token ?? UUID().uuidString }
    
    /// Artwork URL computed from the art string
    ///
    /// Converts the `art` string property to a proper `URL` object for image loading.
    ///
    /// - Returns: A URL if `art` is a valid URL string, otherwise `nil`
    var artworkURL: URL? {
        guard let art = art else { return nil }
        return URL(string: art)
    }
    
    /// Legacy NSNumber accessor for backward compatibility with NSCoding
    ///
    /// Provides compatibility with older saved data that used NSNumber for ratings.
    var nrating: NSNumber? {
        get { NSNumber(value: rating) }
        set { rating = newValue?.intValue ?? 0 }
    }
    
    /// Formatted play date string for display
    ///
    /// Returns a localized, relative date string (e.g., "Today at 2:30 PM" or "Yesterday at 5:15 PM").
    ///
    /// - Returns: A formatted date string, or `nil` if `playDate` is not set
    var playDateString: String? {
        guard let playDate = playDate else { return nil }
        return Self.dateFormatter.string(from: playDate)
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
    
    // MARK: - Initialization
    
    /// Creates a new song with empty metadata
    override init() {
        self.artist = ""
        self.title = ""
        self.album = ""
        super.init()
        setupRatingObserver()
    }
    
    /// Creates a new song with the specified metadata
    ///
    /// - Parameters:
    ///   - artist: The artist name
    ///   - title: The song title
    ///   - album: The album name
    init(artist: String, title: String, album: String) {
        self.artist = artist
        self.title = title
        self.album = album
        super.init()
        setupRatingObserver()
    }
    
    // MARK: - Rating Observer
    
    /// Sets up observation of rating changes from the playback layer
    ///
    /// This method subscribes to rating change notifications to keep all instances
    /// of the same song synchronized when ratings are updated through the Pandora API.
    private func setupRatingObserver() {
        // Observe rating changes from the playback layer
        ratingCancellable = NotificationCenter.default.publisher(for: .pandoraDidRateSong)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let ratedSong = notification.object as? Song else { return }
                
                // Match by token (song ID) to update rating across all instances
                if let myToken = self.token,
                   let ratedToken = ratedSong.token,
                   myToken == ratedToken {
                    self.rating = ratedSong.rating
                }
            }
    }
    
    // MARK: - NSCoding (for backward compatibility with saved history)
    
    /// Decodes a song from archived data
    ///
    /// Supports loading songs from saved listening history using NSCoding.
    ///
    /// - Parameter coder: The decoder to read data from
    required init?(coder: NSCoder) {
        self.artist = coder.decodeObject(of: NSString.self, forKey: "artist") as String? ?? ""
        self.title = coder.decodeObject(of: NSString.self, forKey: "title") as String? ?? ""
        self.album = coder.decodeObject(of: NSString.self, forKey: "album") as String? ?? ""
        self.art = coder.decodeObject(of: NSString.self, forKey: "art") as String?
        self.highUrl = coder.decodeObject(of: NSString.self, forKey: "highUrl") as String?
        self.medUrl = coder.decodeObject(of: NSString.self, forKey: "medUrl") as String?
        self.lowUrl = coder.decodeObject(of: NSString.self, forKey: "lowUrl") as String?
        self.stationId = coder.decodeObject(of: NSString.self, forKey: "stationId") as String?
        self.stationToken = coder.decodeObject(of: NSString.self, forKey: "stationToken") as String?
        // Decode rating from legacy nrating key for backward compatibility
        self.rating = (coder.decodeObject(of: NSNumber.self, forKey: "nrating") as NSNumber?)?.intValue ?? 0
        self.albumUrl = coder.decodeObject(of: NSString.self, forKey: "albumUrl") as String?
        self.artistUrl = coder.decodeObject(of: NSString.self, forKey: "artistUrl") as String?
        self.titleUrl = coder.decodeObject(of: NSString.self, forKey: "titleUrl") as String?
        self.token = coder.decodeObject(of: NSString.self, forKey: "token") as String?
        self.trackGain = coder.decodeObject(of: NSString.self, forKey: "trackGain") as String?
        self.allowFeedback = coder.decodeBool(forKey: "allowFeedback")
        self.playDate = coder.decodeObject(of: NSDate.self, forKey: "playDate") as Date?
        super.init()
        setupRatingObserver()
    }
    
    /// Encodes the song for archival
    ///
    /// Supports saving songs to listening history using NSCoding.
    ///
    /// - Parameter coder: The encoder to write data to
    func encode(with coder: NSCoder) {
        let dict = toDictionary()
        for (key, value) in dict {
            coder.encode(value, forKey: key)
        }
    }
    
    // MARK: - Dictionary Conversion
    
    /// Converts the song to a dictionary representation
    ///
    /// Used for serialization and compatibility with Objective-C code.
    ///
    /// - Returns: A dictionary containing all non-nil song properties
    @objc func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "artist": artist,
            "title": title,
            "album": album,
            "allowFeedback": allowFeedback
        ]
        
        if let art = art { dict["art"] = art }
        if let lowUrl = lowUrl { dict["lowUrl"] = lowUrl }
        if let medUrl = medUrl { dict["medUrl"] = medUrl }
        if let highUrl = highUrl { dict["highUrl"] = highUrl }
        if let stationId = stationId { dict["stationId"] = stationId }
        if let stationToken = stationToken { dict["stationToken"] = stationToken }
        if let nrating = nrating { dict["nrating"] = nrating }
        if let albumUrl = albumUrl { dict["albumUrl"] = albumUrl }
        if let artistUrl = artistUrl { dict["artistUrl"] = artistUrl }
        if let titleUrl = titleUrl { dict["titleUrl"] = titleUrl }
        if let token = token { dict["token"] = token }
        if let trackGain = trackGain { dict["trackGain"] = trackGain }
        if let playDate = playDate { dict["playDate"] = playDate }
        
        return dict
    }
    
    // MARK: - Station Reference
    
    /// Returns the station this song belongs to
    ///
    /// Looks up the station from the global station registry using the song's `stationId`.
    ///
    /// - Returns: The associated `Station` object, or `nil` if no station is found
    @objc func station() -> Station? {
        guard let stationId = stationId else { return nil }
        return Station(forToken: stationId)
    }
    
    // MARK: - Equality
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Song else { return false }
        return token == other.token
    }
    
    override var hash: Int {
        return token?.hash ?? 0
    }
    
    // MARK: - Description
    
    override var description: String {
        return "<\(type(of: self)) \(Unmanaged.passUnretained(self).toOpaque()) \(artist) - \(title)>"
    }
    
    // MARK: - AppleScript Support
    
    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let appDesc = NSScriptClassDescription(for: type(of: NSApp)) else {
            return nil
        }
        
        return NSPropertySpecifier(
            containerClassDescription: appDesc,
            containerSpecifier: nil,
            key: "currentSong"
        )
    }
}

// MARK: - NSSecureCoding

extension Song: NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
}

// MARK: - Preview Helpers

extension Song {
    /// Creates a mock Song for SwiftUI previews and testing
    ///
    /// Generates a song with realistic default values for use in previews and unit tests.
    ///
    /// - Parameters:
    ///   - title: The song title (default: "Bohemian Rhapsody")
    ///   - artist: The artist name (default: "Queen")
    ///   - album: The album name (default: "A Night at the Opera")
    ///   - artworkURL: The artwork URL string (default: example URL)
    ///   - rating: The initial rating (default: 0 for no rating)
    /// - Returns: A configured `Song` instance ready for testing or previews
    ///
    /// ## Example
    ///
    /// ```swift
    /// #Preview {
    ///     PlayerView(song: .mock(title: "Test Song", rating: 1))
    /// }
    /// ```
    static func mock(
        title: String = "Bohemian Rhapsody",
        artist: String = "Queen",
        album: String = "A Night at the Opera",
        artworkURL: String? = "https://example.com/art.jpg",
        rating: Int = 0
    ) -> Song {
        let song = Song()
        song.title = title
        song.artist = artist
        song.album = album
        song.art = artworkURL
        song.rating = rating
        song.token = UUID().uuidString
        return song
    }
}
