//
//  TestHelpersTests.swift
//  HermesTests
//
//  Unit tests for test helper utilities
//

import Testing
import Foundation
@testable import Hermes

@MainActor
@Suite("TestHelpersTests", .serialized)
struct TestHelpersTests {
    
    // MARK: - AppState.testInstance Tests
    
    @Test("App State Test Instance Creates Both Instances")
    func testAppStateTestInstance_CreatesBothInstances() {
        let (appState, mockPandora) = AppState.testInstance()
        
        #expect(Optional(appState) != nil)
        #expect(Optional(mockPandora) != nil)
    }
    
    @Test("App State Test Instance Uses Mock Pandora")
    func testAppStateTestInstance_UsesMockPandora() {
        let (appState, mockPandora) = AppState.testInstance()
        
        // The appState should use the mock pandora
        #expect(appState.pandora === mockPandora)
    }
    
    // MARK: - LoginViewModel.testInstance Tests
    
    @Test("Login View Model Test Instance Creates Both Instances")
    func testLoginViewModelTestInstance_CreatesBothInstances() {
        let (viewModel, mockPandora) = LoginViewModel.testInstance()
        
        #expect(Optional(viewModel) != nil)
        #expect(Optional(mockPandora) != nil)
    }
    
    // MARK: - StationsViewModel.testInstance Tests
    
    @Test("Stations View Model Test Instance Creates Both Instances")
    func testStationsViewModelTestInstance_CreatesBothInstances() {
        let (viewModel, mockPandora) = StationsViewModel.testInstance()
        
        #expect(Optional(viewModel) != nil)
        #expect(Optional(mockPandora) != nil)
    }
    
    @Test("Stations View Model Test Instance With Stations")
    func testStationsViewModelTestInstance_WithStations() {
        let stations = TestDataFactory.createStations(count: 3)
        let (viewModel, mockPandora) = StationsViewModel.testInstance(withStations: stations)
        
        #expect(Optional(viewModel) != nil)
        #expect(Optional(mockPandora) != nil)
        #expect((viewModel.stations.count) == (3))
    }
    
    // MARK: - HistoryViewModel.testInstance Tests
    
    @Test("History View Model Test Instance Creates Instance")
    func testHistoryViewModelTestInstance_CreatesInstance() {
        let viewModel = HistoryViewModel.testInstance()
        
        #expect(Optional(viewModel) != nil)
    }
    
    @Test("History View Model Test Instance With Items")
    func testHistoryViewModelTestInstance_WithItems() {
        let songs = TestDataFactory.createSongs(count: 5)
        let viewModel = HistoryViewModel.testInstance(withItems: songs)
        
        #expect(Optional(viewModel) != nil)
        #expect((viewModel.historyItems.count) == (5))
    }
    
    // MARK: - TestDataFactory.createStation Tests
    
    @Test("Create Station Default Values")
    func testCreateStation_DefaultValues() {
        let station = TestDataFactory.createStation()
        
        #expect((station.name) == ("Test Station"))
        #expect((station.token) == ("test-token-123"))
        #expect((station.stationId) == ("station-id-123"))
        #expect((station.created) > (0))
    }
    
    @Test("Create Station Custom Values")
    func testCreateStation_CustomValues() {
        let station = TestDataFactory.createStation(
            name: "Custom Station",
            token: "custom-token",
            stationId: "custom-id"
        )
        
        #expect((station.name) == ("Custom Station"))
        #expect((station.token) == ("custom-token"))
        #expect((station.stationId) == ("custom-id"))
    }
    
    // MARK: - TestDataFactory.createStations Tests
    
    @Test("Create Stations Creates Correct Count")
    func testCreateStations_CreatesCorrectCount() {
        let stations = TestDataFactory.createStations(count: 5)
        
        #expect((stations.count) == (5))
    }
    
    @Test("Create Stations Has Unique Values")
    func testCreateStations_HasUniqueValues() {
        let stations = TestDataFactory.createStations(count: 3)
        
        let names = Set(stations.map { $0.name })
        let tokens = Set(stations.map { $0.token })
        let ids = Set(stations.map { $0.stationId })
        
        #expect((names.count) == (3))
        #expect((tokens.count) == (3))
        #expect((ids.count) == (3))
    }
    
    // MARK: - TestDataFactory.createSong Tests
    
    @Test("Create Song Default Values")
    func testCreateSong_DefaultValues() {
        let song = TestDataFactory.createSong()
        
        #expect((song.title) == ("Test Song"))
        #expect((song.artist) == ("Test Artist"))
        #expect((song.album) == ("Test Album"))
        #expect((song.token) == ("song-token-123"))
    }
    
    @Test("Create Song Custom Values")
    func testCreateSong_CustomValues() {
        let song = TestDataFactory.createSong(
            title: "Custom Title",
            artist: "Custom Artist",
            album: "Custom Album",
            token: "custom-token"
        )
        
        #expect((song.title) == ("Custom Title"))
        #expect((song.artist) == ("Custom Artist"))
        #expect((song.album) == ("Custom Album"))
        #expect((song.token) == ("custom-token"))
    }
    
    // MARK: - TestDataFactory.createSongs Tests
    
    @Test("Create Songs Creates Correct Count")
    func testCreateSongs_CreatesCorrectCount() {
        let songs = TestDataFactory.createSongs(count: 5)
        
        #expect((songs.count) == (5))
    }
    
    @Test("Create Songs Has Unique Values")
    func testCreateSongs_HasUniqueValues() {
        let songs = TestDataFactory.createSongs(count: 3)
        
        let titles = Set(songs.map { $0.title })
        let tokens = Set(songs.map { $0.token ?? "" })
        
        #expect((titles.count) == (3))
        #expect((tokens.count) == (3))
    }
}
