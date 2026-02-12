//
//  TestHelpersTests.swift
//  HermesTests
//
//  Unit tests for test helper utilities
//

import XCTest
@testable import Hermes

@MainActor
final class TestHelpersTests: XCTestCase {
    
    // MARK: - AppState.testInstance Tests
    
    func testAppStateTestInstance_CreatesBothInstances() {
        let (appState, mockPandora) = AppState.testInstance()
        
        XCTAssertNotNil(appState)
        XCTAssertNotNil(mockPandora)
    }
    
    func testAppStateTestInstance_UsesMockPandora() {
        let (appState, mockPandora) = AppState.testInstance()
        
        // The appState should use the mock pandora
        XCTAssertTrue(appState.pandora === mockPandora)
    }
    
    // MARK: - LoginViewModel.testInstance Tests
    
    func testLoginViewModelTestInstance_CreatesBothInstances() {
        let (viewModel, mockPandora) = LoginViewModel.testInstance()
        
        XCTAssertNotNil(viewModel)
        XCTAssertNotNil(mockPandora)
    }
    
    // MARK: - StationsViewModel.testInstance Tests
    
    func testStationsViewModelTestInstance_CreatesBothInstances() {
        let (viewModel, mockPandora) = StationsViewModel.testInstance()
        
        XCTAssertNotNil(viewModel)
        XCTAssertNotNil(mockPandora)
    }
    
    func testStationsViewModelTestInstance_WithStations() {
        let stations = TestDataFactory.createStations(count: 3)
        let (viewModel, mockPandora) = StationsViewModel.testInstance(withStations: stations)
        
        XCTAssertNotNil(viewModel)
        XCTAssertNotNil(mockPandora)
        XCTAssertEqual(viewModel.stations.count, 3)
    }
    
    // MARK: - HistoryViewModel.testInstance Tests
    
    func testHistoryViewModelTestInstance_CreatesInstance() {
        let viewModel = HistoryViewModel.testInstance()
        
        XCTAssertNotNil(viewModel)
    }
    
    func testHistoryViewModelTestInstance_WithItems() {
        let songs = TestDataFactory.createSongs(count: 5)
        let viewModel = HistoryViewModel.testInstance(withItems: songs)
        
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel.historyItems.count, 5)
    }
    
    // MARK: - TestDataFactory.createStation Tests
    
    func testCreateStation_DefaultValues() {
        let station = TestDataFactory.createStation()
        
        XCTAssertEqual(station.name, "Test Station")
        XCTAssertEqual(station.token, "test-token-123")
        XCTAssertEqual(station.stationId, "station-id-123")
        XCTAssertGreaterThan(station.created, 0)
    }
    
    func testCreateStation_CustomValues() {
        let station = TestDataFactory.createStation(
            name: "Custom Station",
            token: "custom-token",
            stationId: "custom-id"
        )
        
        XCTAssertEqual(station.name, "Custom Station")
        XCTAssertEqual(station.token, "custom-token")
        XCTAssertEqual(station.stationId, "custom-id")
    }
    
    // MARK: - TestDataFactory.createStations Tests
    
    func testCreateStations_CreatesCorrectCount() {
        let stations = TestDataFactory.createStations(count: 5)
        
        XCTAssertEqual(stations.count, 5)
    }
    
    func testCreateStations_HasUniqueValues() {
        let stations = TestDataFactory.createStations(count: 3)
        
        let names = Set(stations.map { $0.name })
        let tokens = Set(stations.map { $0.token })
        let ids = Set(stations.map { $0.stationId })
        
        XCTAssertEqual(names.count, 3)
        XCTAssertEqual(tokens.count, 3)
        XCTAssertEqual(ids.count, 3)
    }
    
    // MARK: - TestDataFactory.createSong Tests
    
    func testCreateSong_DefaultValues() {
        let song = TestDataFactory.createSong()
        
        XCTAssertEqual(song.title, "Test Song")
        XCTAssertEqual(song.artist, "Test Artist")
        XCTAssertEqual(song.album, "Test Album")
        XCTAssertEqual(song.token, "song-token-123")
    }
    
    func testCreateSong_CustomValues() {
        let song = TestDataFactory.createSong(
            title: "Custom Title",
            artist: "Custom Artist",
            album: "Custom Album",
            token: "custom-token"
        )
        
        XCTAssertEqual(song.title, "Custom Title")
        XCTAssertEqual(song.artist, "Custom Artist")
        XCTAssertEqual(song.album, "Custom Album")
        XCTAssertEqual(song.token, "custom-token")
    }
    
    // MARK: - TestDataFactory.createSongs Tests
    
    func testCreateSongs_CreatesCorrectCount() {
        let songs = TestDataFactory.createSongs(count: 5)
        
        XCTAssertEqual(songs.count, 5)
    }
    
    func testCreateSongs_HasUniqueValues() {
        let songs = TestDataFactory.createSongs(count: 3)
        
        let titles = Set(songs.map { $0.title })
        let tokens = Set(songs.map { $0.token ?? "" })
        
        XCTAssertEqual(titles.count, 3)
        XCTAssertEqual(tokens.count, 3)
    }
}
