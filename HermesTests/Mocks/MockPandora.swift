//
//  MockPandora.swift
//  HermesTests
//
//  Mock implementation of PandoraProtocol for testing
//

import Foundation
@testable import Hermes

/// Mock implementation of PandoraProtocol for testing
///
/// This mock records all method calls for verification and allows configuring
/// return values and behaviors for testing different scenarios.
///
/// ## Usage
///
/// ```swift
/// let mock = MockPandora()
/// mock.authenticateResult = true
/// mock.mockStations = [station1, station2]
///
/// let viewModel = LoginViewModel(pandora: mock)
/// viewModel.authenticate()
///
/// XCTAssertTrue(mock.didCall(.authenticate(username: "test", password: "pass")))
/// XCTAssertEqual(mock.callCount(for: .authenticate(username: "test", password: "pass")), 1)
/// ```
///
@MainActor
final class MockPandora: NSObject, PandoraProtocol {
    
    // MARK: - Call Recording
    
    /// Represents a recorded method call
    struct Call: Equatable {
        /// The method that was called
        enum Method: Equatable {
            case authenticate(username: String, password: String)
            case isAuthenticated
            case logout
            case logoutNoNotify
            case fetchStations
            case createStation(musicId: String)
            case removeStation(token: String)
            case renameStation(token: String, name: String)
            case fetchStationInfo(stationToken: String)
            case fetchGenreStations
            case sortStations(sort: Int)
            case fetchPlaylist(stationToken: String)
            case rateSong(songToken: String, liked: Bool)
            case tiredOfSong(songToken: String)
            case deleteRating(songToken: String)
            case search(query: String)
            case addSeed(token: String, stationToken: String)
            case removeSeed(seedId: String)
            case deleteFeedback(feedbackId: String)
        }
        
        let method: Method
        let timestamp: Date
    }
    
    /// Array of all recorded calls in chronological order
    private(set) var calls: [Call] = []
    
    // MARK: - Configurable Behavior
    
    // Authentication configuration
    var authenticateResult: Bool = true
    var authenticateError: Error?
    var isAuthenticatedValue: Bool = false
    
    // Station management configuration
    var fetchStationsResult: Bool = true
    var fetchStationsError: Error?
    var createStationResult: Bool = true
    var createStationError: Error?
    var removeStationResult: Bool = true
    var removeStationError: Error?
    var renameStationResult: Bool = true
    var renameStationError: Error?
    var fetchStationInfoResult: Bool = true
    var fetchStationInfoError: Error?
    var fetchGenreStationsResult: Bool = true
    var fetchGenreStationsError: Error?
    
    // Playback configuration
    var fetchPlaylistResult: Bool = true
    var fetchPlaylistError: Error?
    
    // Song operations configuration
    var rateSongResult: Bool = true
    var rateSongError: Error?
    var tiredOfSongResult: Bool = true
    var tiredOfSongError: Error?
    var deleteRatingResult: Bool = true
    var deleteRatingError: Error?
    
    // Search configuration
    var searchResult: Bool = true
    var searchError: Error?
    
    // Seed management configuration
    var addSeedResult: Bool = true
    var addSeedError: Error?
    var removeSeedResult: Bool = true
    var removeSeedError: Error?
    var deleteFeedbackResult: Bool = true
    var deleteFeedbackError: Error?
    
    // Mock data
    var mockStations: [Any]? = []
    var device: [AnyHashable: Any]?
    var cachedSubscriberStatus: NSNumber?
    
    // MARK: - Protocol Implementation - Properties
    
    var stations: [Any]? {
        return mockStations
    }
    
    // MARK: - Protocol Implementation - Authentication
    
    func authenticate(_ user: String!, password: String!, request req: PandoraRequest?) -> Bool {
        calls.append(Call(method: .authenticate(username: user ?? "", password: password ?? ""), timestamp: Date()))
        
        if let error = authenticateError {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if authenticateResult {
            isAuthenticatedValue = true
            NotificationCenter.default.post(name: Notification.Name("hermes.authenticated"), object: nil)
        }
        
        return authenticateResult
    }
    
    func isAuthenticated() -> Bool {
        calls.append(Call(method: .isAuthenticated, timestamp: Date()))
        return isAuthenticatedValue
    }
    
    func logout() {
        calls.append(Call(method: .logout, timestamp: Date()))
        isAuthenticatedValue = false
        NotificationCenter.default.post(name: Notification.Name("hermes.logout"), object: nil)
    }
    
    func logoutNoNotify() {
        calls.append(Call(method: .logoutNoNotify, timestamp: Date()))
        isAuthenticatedValue = false
    }
    
    // MARK: - Protocol Implementation - Station Management
    
    func fetchStations() -> Bool {
        calls.append(Call(method: .fetchStations, timestamp: Date()))
        
        if let error = fetchStationsError {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if fetchStationsResult {
            NotificationCenter.default.post(name: Notification.Name("hermes.stations"), object: nil)
        }
        
        return fetchStationsResult
    }
    
    func createStation(_ musicId: String!) -> Bool {
        calls.append(Call(method: .createStation(musicId: musicId ?? ""), timestamp: Date()))
        
        if let error = createStationError {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if createStationResult {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.station-created"),
                object: nil,
                userInfo: ["musicId": musicId ?? ""]
            )
        }
        
        return createStationResult
    }
    
    func removeStation(_ stationToken: String!) -> Bool {
        calls.append(Call(method: .removeStation(token: stationToken ?? ""), timestamp: Date()))
        
        if let error = removeStationError {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if removeStationResult {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.station-removed"),
                object: nil,
                userInfo: ["token": stationToken ?? ""]
            )
        }
        
        return removeStationResult
    }
    
    func renameStation(_ stationToken: String!, to name: String!) -> Bool {
        calls.append(Call(method: .renameStation(token: stationToken ?? "", name: name ?? ""), timestamp: Date()))
        
        if let error = renameStationError {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if renameStationResult {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.station-renamed"),
                object: nil,
                userInfo: ["token": stationToken ?? "", "name": name ?? ""]
            )
        }
        
        return renameStationResult
    }
    
    func fetchStationInfo(_ station: Station!) -> Bool {
        let token = station?.token ?? ""
        calls.append(Call(method: .fetchStationInfo(stationToken: token), timestamp: Date()))
        
        if let error = fetchStationInfoError {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if fetchStationInfoResult {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.station-info"),
                object: nil,
                userInfo: ["token": token]
            )
        }
        
        return fetchStationInfoResult
    }
    
    func fetchGenreStations() -> Bool {
        calls.append(Call(method: .fetchGenreStations, timestamp: Date()))
        
        if let error = fetchGenreStationsError {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if fetchGenreStationsResult {
            NotificationCenter.default.post(name: Notification.Name("hermes.genre-stations"), object: nil)
        }
        
        return fetchGenreStationsResult
    }
    
    func sortStations(_ sort: Int) {
        calls.append(Call(method: .sortStations(sort: sort), timestamp: Date()))
    }
    
    // MARK: - Protocol Implementation - Playback
    
    func fetchPlaylist(for station: Station!) -> Bool {
        let token = station?.token ?? ""
        calls.append(Call(method: .fetchPlaylist(stationToken: token), timestamp: Date()))
        
        if let error = fetchPlaylistError {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if fetchPlaylistResult {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.playlist"),
                object: nil,
                userInfo: ["token": token]
            )
        }
        
        return fetchPlaylistResult
    }
    
    // MARK: - Protocol Implementation - Song Operations
    
    func rateSong(_ song: Song!, as liked: Bool) -> Bool {
        let token = song?.token ?? ""
        calls.append(Call(method: .rateSong(songToken: token, liked: liked), timestamp: Date()))
        
        if let error = rateSongError {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if rateSongResult {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.song-rated"),
                object: nil,
                userInfo: ["token": token, "liked": liked]
            )
        }
        
        return rateSongResult
    }
    
    func tired(of song: Song!) -> Bool {
        let token = song?.token ?? ""
        calls.append(Call(method: .tiredOfSong(songToken: token), timestamp: Date()))
        
        if let error = tiredOfSongError {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if tiredOfSongResult {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.song-tired"),
                object: nil,
                userInfo: ["token": token]
            )
        }
        
        return tiredOfSongResult
    }
    
    func deleteRating(_ song: Song!) -> Bool {
        let token = song?.token ?? ""
        calls.append(Call(method: .deleteRating(songToken: token), timestamp: Date()))
        
        if let error = deleteRatingError {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if deleteRatingResult {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.rating-deleted"),
                object: nil,
                userInfo: ["token": token]
            )
        }
        
        return deleteRatingResult
    }
    
    // MARK: - Protocol Implementation - Search
    
    func search(_ searchQuery: String!) -> Bool {
        calls.append(Call(method: .search(query: searchQuery ?? ""), timestamp: Date()))
        
        if let error = searchError {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if searchResult {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.search-results"),
                object: nil,
                userInfo: ["query": searchQuery ?? ""]
            )
        }
        
        return searchResult
    }
    
    // MARK: - Protocol Implementation - Seed Management
    
    func addSeed(_ token: String!, to station: Station!) -> Bool {
        let stationToken = station?.token ?? ""
        calls.append(Call(method: .addSeed(token: token ?? "", stationToken: stationToken), timestamp: Date()))
        
        if let error = addSeedError {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if addSeedResult {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.seed-added"),
                object: nil,
                userInfo: ["token": token ?? "", "stationToken": stationToken]
            )
        }
        
        return addSeedResult
    }
    
    func removeSeed(_ seedId: String!) -> Bool {
        calls.append(Call(method: .removeSeed(seedId: seedId ?? ""), timestamp: Date()))
        
        if let error = removeSeedError {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if removeSeedResult {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.seed-removed"),
                object: nil,
                userInfo: ["seedId": seedId ?? ""]
            )
        }
        
        return removeSeedResult
    }
    
    func deleteFeedback(_ feedbackId: String!) -> Bool {
        calls.append(Call(method: .deleteFeedback(feedbackId: feedbackId ?? ""), timestamp: Date()))
        
        if let error = deleteFeedbackError {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if deleteFeedbackResult {
            NotificationCenter.default.post(
                name: Notification.Name("hermes.feedback-deleted"),
                object: nil,
                userInfo: ["feedbackId": feedbackId ?? ""]
            )
        }
        
        return deleteFeedbackResult
    }
    
    // MARK: - Test Helpers
    
    /// Resets all recorded calls and configuration to default state
    func reset() {
        calls.removeAll()
        
        // Reset authentication configuration
        authenticateResult = true
        authenticateError = nil
        isAuthenticatedValue = false
        
        // Reset station management configuration
        fetchStationsResult = true
        fetchStationsError = nil
        createStationResult = true
        createStationError = nil
        removeStationResult = true
        removeStationError = nil
        renameStationResult = true
        renameStationError = nil
        fetchStationInfoResult = true
        fetchStationInfoError = nil
        fetchGenreStationsResult = true
        fetchGenreStationsError = nil
        
        // Reset playback configuration
        fetchPlaylistResult = true
        fetchPlaylistError = nil
        
        // Reset song operations configuration
        rateSongResult = true
        rateSongError = nil
        tiredOfSongResult = true
        tiredOfSongError = nil
        deleteRatingResult = true
        deleteRatingError = nil
        
        // Reset search configuration
        searchResult = true
        searchError = nil
        
        // Reset seed management configuration
        addSeedResult = true
        addSeedError = nil
        removeSeedResult = true
        removeSeedError = nil
        deleteFeedbackResult = true
        deleteFeedbackError = nil
        
        // Reset mock data
        mockStations = []
        device = nil
        cachedSubscriberStatus = nil
    }
    
    /// Checks if a specific method was called
    ///
    /// - Parameter method: The method to check for
    /// - Returns: `true` if the method was called at least once, `false` otherwise
    func didCall(_ method: Call.Method) -> Bool {
        return calls.contains { $0.method == method }
    }
    
    /// Counts how many times a specific method was called
    ///
    /// - Parameter method: The method to count calls for
    /// - Returns: The number of times the method was called
    func callCount(for method: Call.Method) -> Int {
        return calls.filter { $0.method == method }.count
    }
    
    /// Returns all calls for a specific method
    ///
    /// - Parameter method: The method to get calls for
    /// - Returns: Array of calls for the specified method
    func getCalls(for method: Call.Method) -> [Call] {
        return calls.filter { $0.method == method }
    }
}
