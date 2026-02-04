//
//  PandoraProtocol.swift
//  Hermes
//
//  Protocol abstraction for Pandora API operations enabling dependency injection
//

import Foundation

/// Protocol abstraction for Pandora API operations
///
/// This protocol defines the interface for all Pandora music service operations,
/// enabling dependency injection and test isolation. The protocol mirrors the
/// existing Objective-C Pandora class API to ensure seamless conformance.
///
/// ## Usage
///
/// **Production code:**
/// ```swift
/// let pandora: PandoraProtocol = Pandora()
/// pandora.authenticate("user@example.com", password: "password", request: nil)
/// ```
///
/// **Test code:**
/// ```swift
/// let mockPandora = MockPandora()
/// let viewModel = LoginViewModel(pandora: mockPandora)
/// ```
///
/// ## Design Rationale
///
/// This protocol uses a single cohesive interface rather than multiple smaller
/// protocols because:
/// - Pandora operations are interdependent (authentication affects all operations)
/// - Simplifies dependency injection (one dependency instead of many)
/// - Matches the existing Pandora class structure
/// - Easier to mock (one mock class instead of coordinating multiple mocks)
///
/// ## Requirements
///
/// Validates Requirements 1.1, 1.2, 1.3, 1.4, 1.5 from the dependency-injection spec.
///
public protocol PandoraProtocol: AnyObject {
    
    // MARK: - Properties
    
    /// Array of stations for the authenticated user
    var stations: [Station] { get }
    
    /// Device configuration for API requests
    var device: NSDictionary? { get set }
    
    /// Cached subscriber status
    var cachedSubscriberStatus: NSNumber? { get set }
    
    // MARK: - Authentication
    
    /// Authenticates with Pandora using username and password
    ///
    /// When completed successfully, fires the "hermes.authenticated" notification
    /// (unless a retry request is provided). This method indirectly calls the
    /// "auth.partnerLogin", "auth.userLogin", and "user.canSubscribe" API methods.
    ///
    /// - Parameters:
    ///   - user: The username to log in with
    ///   - password: The password to log in with
    ///   - request: An optional request to retry once authentication completes
    /// - Returns: `true` if authentication was initiated successfully, `false` otherwise
    func authenticate(_ user: String, password: String, request: PandoraRequest?) -> Bool
    
    /// Checks if the user is currently authenticated
    ///
    /// - Returns: `true` if authenticated, `false` otherwise
    func isAuthenticated() -> Bool
    
    /// Logs out the current user
    ///
    /// Fires the "hermes.logged-out" notification when complete.
    func logout()
    
    /// Logs out the current user without posting notifications
    func logoutNoNotify()
    
    // MARK: - Station Management
    
    /// Fetches the list of stations for the logged-in user
    ///
    /// Fires the "hermes.stations" notification when complete. All stations
    /// are stored internally and accessible via the `stations` property.
    ///
    /// - Returns: `true` if the request was initiated successfully, `false` otherwise
    func fetchStations() -> Bool
    
    /// Creates a new station from a music identifier
    ///
    /// The music identifier must be obtained from a prior search. The identifier
    /// represents either an artist or song that will be the initial seed for the station.
    ///
    /// Fires the "hermes.station-created" notification when complete with userInfo
    /// containing the key "station" with the created Station object.
    ///
    /// - Parameter musicId: The identifier of the song/artist to create the station for
    /// - Returns: `true` if the request was initiated successfully, `false` otherwise
    func createStation(_ musicId: String) -> Bool
    
    /// Removes a station from the user's account
    ///
    /// Fires the "hermes.station-removed" notification when complete.
    ///
    /// - Parameter stationToken: The token of the station to remove
    /// - Returns: `true` if the request was initiated successfully, `false` otherwise
    func removeStation(_ stationToken: String) -> Bool
    
    /// Renames a station
    ///
    /// Fires the "hermes.station-renamed" notification when complete.
    ///
    /// - Parameters:
    ///   - stationToken: The token of the station to rename
    ///   - name: The new name for the station
    /// - Returns: `true` if the request was initiated successfully, `false` otherwise
    func renameStation(_ stationToken: String, to name: String) -> Bool
    
    /// Fetches detailed information about a station
    ///
    /// Returns information including likes, dislikes, seeds, genres, artwork, etc.
    /// Fires the "hermes.station-info" notification when complete with detailed
    /// information in the userInfo dictionary.
    ///
    /// - Parameter station: The station to fetch information for
    /// - Returns: `true` if the request was initiated successfully, `false` otherwise
    func fetchStationInfo(_ station: Station) -> Bool
    
    /// Fetches genre stations available from Pandora
    ///
    /// Pandora provides pre-defined genre stations that can be used to create
    /// new stations. Fires the "hermes.genre-stations" notification when complete.
    ///
    /// - Returns: `true` if the request was initiated successfully, `false` otherwise
    func fetchGenreStations() -> Bool
    
    /// Sorts stations according to the specified sort order
    ///
    /// - Parameter sort: The sort order to apply
    func sortStations(_ sort: Int)
    
    // MARK: - Playback
    
    /// Fetches a playlist of songs for a station
    ///
    /// Fires the "hermes.fragment-fetched.XX" notification (where XX is the station
    /// token) when complete. The userInfo contains the key "songs" with an array
    /// of Song objects.
    ///
    /// - Parameter station: The station to fetch songs for
    /// - Returns: `true` if the request was initiated successfully, `false` otherwise
    func fetchPlaylistForStation(_ station: Station) -> Bool
    
    // MARK: - Song Operations
    
    /// Rates a song as liked or disliked
    ///
    /// Fires the "hermes.song-rated" notification when complete with userInfo
    /// containing the key "song" with the rated Song object.
    ///
    /// - Parameters:
    ///   - song: The song to rate
    ///   - liked: `true` to like the song, `false` to dislike it
    /// - Returns: `true` if the request was initiated successfully, `false` otherwise
    func rateSong(_ song: Song, as liked: Bool) -> Bool
    
    /// Marks a song as "tired" so it won't be played for a while
    ///
    /// Fires the "hermes.song-tired" notification when complete with userInfo
    /// containing the key "song" with the Song object.
    ///
    /// - Parameter song: The song to mark as tired
    /// - Returns: `true` if the request was initiated successfully, `false` otherwise
    func tiredOfSong(_ song: Song) -> Bool
    
    /// Deletes a rating for a song
    ///
    /// Fires the "hermes.feedback-deleted" notification when complete.
    ///
    /// - Parameter song: The song to delete the rating for
    /// - Returns: `true` if the request was initiated successfully, `false` otherwise
    func deleteRating(_ song: Song) -> Bool
    
    // MARK: - Search
    
    /// Searches for songs and artists
    ///
    /// Fires the "hermes.search-results" notification when complete with userInfo
    /// containing:
    /// - "Songs": Array of PandoraSearchResult objects for matching songs
    /// - "Artists": Array of PandoraSearchResult objects for matching artists
    ///
    /// - Parameter search: The query string to search for
    /// - Returns: `true` if the request was initiated successfully, `false` otherwise
    func search(_ search: String) -> Bool
    
    // MARK: - Seed Management
    
    /// Adds a seed to a station
    ///
    /// The seed token must be obtained from a prior search. Fires the
    /// "hermes.seed-added" notification when complete with userInfo containing:
    /// - "seedId": Identifier for the seed
    /// - "artistName": Name of the artist (always present)
    /// - "songName": Name of the song (present if seed was a song)
    ///
    /// - Parameters:
    ///   - token: The token of the seed to add
    ///   - station: The station to add the seed to
    /// - Returns: `true` if the request was initiated successfully, `false` otherwise
    func addSeed(_ token: String, toStation station: Station) -> Bool
    
    /// Removes a seed from a station
    ///
    /// The seed ID is obtained from detailed station information. Fires the
    /// "hermes.seed-removed" notification when complete.
    ///
    /// - Parameter seedId: The identifier of the seed to remove
    /// - Returns: `true` if the request was initiated successfully, `false` otherwise
    func removeSeed(_ seedId: String) -> Bool
    
    /// Deletes feedback for a station
    ///
    /// Fires the "hermes.feedback-deleted" notification when complete.
    ///
    /// - Parameter feedbackId: The identifier of the feedback to delete
    /// - Returns: `true` if the request was initiated successfully, `false` otherwise
    func deleteFeedback(_ feedbackId: String) -> Bool
}

// MARK: - Pandora Conformance

/// Extension to make the Objective-C Pandora class conform to PandoraProtocol
///
/// This extension is purely declarative - it doesn't add new functionality,
/// it just declares that Pandora conforms to the protocol. The compiler verifies
/// that all required methods exist with matching signatures.
///
/// Most methods are inherited directly from the Objective-C class and match
/// the protocol signatures exactly. Only properties that are methods in Objective-C
/// need computed property wrappers.
///
/// ## Design Rationale
///
/// This is a zero-cost abstraction - no runtime overhead, just compile-time
/// type checking. The extension enables dependency injection by allowing
/// Pandora to be used through the PandoraProtocol interface.
///
/// ## Requirements
///
/// Validates Requirement 1.6 from the dependency-injection spec.
///
extension Pandora: PandoraProtocol {
    // All methods already exist with matching signatures in the Objective-C class
    // This extension just declares conformance
}
