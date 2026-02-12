//
//  TestHelpers.swift
//  HermesTests
//
//  Convenience utilities for creating test instances with dependency injection
//

import Foundation
@testable import Hermes

// MARK: - AppState Test Helpers

@MainActor
extension AppState {
    /// Creates a test AppState with a fresh MockPandora instance
    ///
    /// Use this helper to create isolated test instances that don't trigger
    /// production API calls or keychain access.
    ///
    /// ## Example
    /// ```swift
    /// let (appState, mock) = AppState.testInstance()
    /// mock.authenticateResult = true
    /// // Test with appState...
    /// ```
    ///
    /// - Returns: A tuple containing the test AppState and its MockPandora instance
    static func testInstance() -> (appState: AppState, mockPandora: MockPandora) {
        let mock = MockPandora()
        let appState = AppState.test(pandora: mock)
        return (appState, mock)
    }
}

// MARK: - LoginViewModel Test Helpers

@MainActor
extension LoginViewModel {
    /// Creates a test LoginViewModel with a fresh MockPandora instance
    ///
    /// ## Example
    /// ```swift
    /// let (viewModel, mock) = LoginViewModel.testInstance()
    /// viewModel.username = "test@example.com"
    /// viewModel.password = "password"
    /// try await viewModel.authenticate()
    /// XCTAssertTrue(mock.didCall(.authenticate(username: "test@example.com", password: "password")))
    /// ```
    ///
    /// - Returns: A tuple containing the test LoginViewModel and its MockPandora instance
    static func testInstance() -> (viewModel: LoginViewModel, mockPandora: MockPandora) {
        let mock = MockPandora()
        let viewModel = LoginViewModel(pandora: mock)
        return (viewModel, mock)
    }
}

// MARK: - StationsViewModel Test Helpers

@MainActor
extension StationsViewModel {
    /// Creates a test StationsViewModel with a fresh MockPandora instance
    ///
    /// ## Example
    /// ```swift
    /// let (viewModel, mock) = StationsViewModel.testInstance()
    /// mock.mockStations = [station1, station2]
    /// await viewModel.refreshStations()
    /// XCTAssertTrue(mock.didCall(.fetchStations))
    /// ```
    ///
    /// - Returns: A tuple containing the test StationsViewModel and its MockPandora instance
    static func testInstance() -> (viewModel: StationsViewModel, mockPandora: MockPandora) {
        let mock = MockPandora()
        let viewModel = StationsViewModel(pandora: mock)
        return (viewModel, mock)
    }
    
    /// Creates a test StationsViewModel pre-configured with mock stations
    ///
    /// - Parameter stations: Array of stations to pre-populate
    /// - Returns: A tuple containing the test StationsViewModel and its MockPandora instance
    static func testInstance(withStations stations: [Station]) -> (viewModel: StationsViewModel, mockPandora: MockPandora) {
        let mock = MockPandora()
        mock.mockStations = stations
        let viewModel = StationsViewModel(pandora: mock)
        viewModel.stations = stations
        return (viewModel, mock)
    }
}

// MARK: - HistoryViewModel Test Helpers

@MainActor
extension HistoryViewModel {
    /// Creates a test HistoryViewModel
    ///
    /// HistoryViewModel doesn't directly use Pandora, but this helper
    /// provides a consistent API for test instance creation.
    ///
    /// - Returns: A fresh HistoryViewModel instance for testing
    static func testInstance() -> HistoryViewModel {
        return HistoryViewModel()
    }
    
    /// Creates a test HistoryViewModel pre-populated with history items
    ///
    /// - Parameter items: Array of songs to pre-populate in history
    /// - Returns: A HistoryViewModel with the specified history items
    static func testInstance(withItems items: [Song]) -> HistoryViewModel {
        let viewModel = HistoryViewModel()
        viewModel.historyItems = items
        return viewModel
    }
}

// MARK: - Mock Data Factories

/// Factory methods for creating mock test data
enum TestDataFactory {
    
    /// Creates a mock Station for testing
    ///
    /// - Parameters:
    ///   - name: Station name (default: "Test Station")
    ///   - token: Station token (default: "test-token-123")
    ///   - stationId: Station ID (default: "station-id-123")
    /// - Returns: A configured Station instance
    @MainActor
    static func createStation(
        name: String = "Test Station",
        token: String = "test-token-123",
        stationId: String = "station-id-123"
    ) -> Station {
        let station = Station()
        station.name = name
        station.token = token
        station.stationId = stationId
        station.created = UInt64(Date().timeIntervalSince1970 * 1000)
        return station
    }
    
    /// Creates multiple mock stations for testing
    ///
    /// - Parameter count: Number of stations to create
    /// - Returns: Array of configured Station instances
    @MainActor
    static func createStations(count: Int) -> [Station] {
        return (0..<count).map { index in
            createStation(
                name: "Station \(index + 1)",
                token: "token-\(index)",
                stationId: "id-\(index)"
            )
        }
    }
    
    /// Creates a mock Song for testing
    ///
    /// - Parameters:
    ///   - title: Song title (default: "Test Song")
    ///   - artist: Artist name (default: "Test Artist")
    ///   - album: Album name (default: "Test Album")
    ///   - token: Song token (default: "song-token-123")
    /// - Returns: A configured Song instance
    @MainActor
    static func createSong(
        title: String = "Test Song",
        artist: String = "Test Artist",
        album: String = "Test Album",
        token: String = "song-token-123"
    ) -> Song {
        let song = Song()
        song.title = title
        song.artist = artist
        song.album = album
        song.token = token
        return song
    }
    
    /// Creates multiple mock songs for testing
    ///
    /// - Parameter count: Number of songs to create
    /// - Returns: Array of configured Song instances
    @MainActor
    static func createSongs(count: Int) -> [Song] {
        return (0..<count).map { index in
            createSong(
                title: "Song \(index + 1)",
                artist: "Artist \(index + 1)",
                album: "Album \(index + 1)",
                token: "song-token-\(index)"
            )
        }
    }
}
