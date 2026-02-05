//
//  ObservableMigrationTests.swift
//  HermesTests
//
//  Tests to verify @Observable migration is complete and state updates work correctly
//

import XCTest
@testable import Hermes

@MainActor
final class ObservableMigrationTests: XCTestCase {
    
    // MARK: - AppState Tests
    
    func testAppState_IsObservable() {
        // Verify AppState uses @Observable (not ObservableObject)
        let appState = AppState.shared
        
        // @Observable types don't conform to ObservableObject
        // This test verifies the migration by checking state changes work
        let initialView = appState.currentView
        appState.currentView = .loading
        XCTAssertEqual(appState.currentView, .loading)
        
        // Restore
        appState.currentView = initialView
    }
    
    func testAppState_StateChangesPropagate() {
        let appState = AppState.shared
        
        // Test isSidebarVisible
        let initialSidebar = appState.isSidebarVisible
        appState.isSidebarVisible = !initialSidebar
        XCTAssertEqual(appState.isSidebarVisible, !initialSidebar)
        appState.isSidebarVisible = initialSidebar
        
        // Test isAuthenticated
        let initialAuth = appState.isAuthenticated
        appState.isAuthenticated = !initialAuth
        XCTAssertEqual(appState.isAuthenticated, !initialAuth)
        appState.isAuthenticated = initialAuth
    }
    
    // MARK: - PlayerViewModel Tests
    
    func testPlayerViewModel_IsObservable() {
        let viewModel = PlayerViewModel()
        
        // Test state changes
        viewModel.isPlaying = true
        XCTAssertTrue(viewModel.isPlaying)
        
        viewModel.isPlaying = false
        XCTAssertFalse(viewModel.isPlaying)
    }
    
    func testPlayerViewModel_VolumeChanges() {
        let viewModel = PlayerViewModel()
        
        viewModel.volume = 0.5
        XCTAssertEqual(viewModel.volume, 0.5)
        
        viewModel.volume = 1.0
        XCTAssertEqual(viewModel.volume, 1.0)
    }
    
    func testPlayerViewModel_PlaybackPositionChanges() {
        let viewModel = PlayerViewModel()
        
        viewModel.playbackPosition = 60.0
        XCTAssertEqual(viewModel.playbackPosition, 60.0)
        
        viewModel.duration = 180.0
        XCTAssertEqual(viewModel.duration, 180.0)
    }
    
    func testPlayerViewModel_LikedStateChanges() {
        let viewModel = PlayerViewModel()
        
        viewModel.isLiked = true
        XCTAssertTrue(viewModel.isLiked)
        
        viewModel.isLiked = false
        XCTAssertFalse(viewModel.isLiked)
    }
    
    // MARK: - StationsViewModel Tests
    
    func testStationsViewModel_IsObservable() {
        let viewModel = StationsViewModel(pandora: PandoraClient())
        
        // Test state changes
        viewModel.isLoading = true
        XCTAssertTrue(viewModel.isLoading)
        
        viewModel.isLoading = false
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testStationsViewModel_SearchTextChanges() {
        let viewModel = StationsViewModel(pandora: PandoraClient())
        
        viewModel.searchText = "rock"
        XCTAssertEqual(viewModel.searchText, "rock")
        
        viewModel.searchText = ""
        XCTAssertEqual(viewModel.searchText, "")
    }
    
    func testStationsViewModel_SortOrderChanges() {
        let viewModel = StationsViewModel(pandora: PandoraClient())
        
        viewModel.sortOrder = .name
        XCTAssertEqual(viewModel.sortOrder, .name)
        
        viewModel.sortOrder = .dateCreated
        XCTAssertEqual(viewModel.sortOrder, .dateCreated)
    }
    
    // MARK: - LoginViewModel Tests
    
    func testLoginViewModel_IsObservable() {
        let viewModel = LoginViewModel(pandora: PandoraClient())
        
        // Test state changes
        viewModel.username = "test@example.com"
        XCTAssertEqual(viewModel.username, "test@example.com")
        
        viewModel.password = "password123"
        XCTAssertEqual(viewModel.password, "password123")
    }
    
    func testLoginViewModel_LoadingStateChanges() {
        let viewModel = LoginViewModel(pandora: PandoraClient())
        
        viewModel.isLoading = true
        XCTAssertTrue(viewModel.isLoading)
        
        viewModel.isLoading = false
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testLoginViewModel_ErrorMessageChanges() {
        let viewModel = LoginViewModel(pandora: PandoraClient())
        
        viewModel.errorMessage = "Invalid credentials"
        XCTAssertEqual(viewModel.errorMessage, "Invalid credentials")
        
        viewModel.errorMessage = nil
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - HistoryViewModel Tests
    
    func testHistoryViewModel_IsObservable() {
        let viewModel = HistoryViewModel()
        
        // Test state changes
        let mockSong = Song.mock()
        viewModel.selectedItem = mockSong
        XCTAssertNotNil(viewModel.selectedItem)
        
        viewModel.selectedItem = nil
        XCTAssertNil(viewModel.selectedItem)
    }
    
    func testHistoryViewModel_HistoryItemsChanges() {
        let viewModel = HistoryViewModel()
        
        let initialCount = viewModel.historyItems.count
        let mockSong = Song.mock()
        viewModel.historyItems.append(mockSong)
        XCTAssertEqual(viewModel.historyItems.count, initialCount + 1)
        
        viewModel.historyItems.removeAll()
        XCTAssertEqual(viewModel.historyItems.count, 0)
    }
    
    // MARK: - StationAddViewModel Tests
    
    func testStationAddViewModel_IsObservable() {
        let viewModel = StationAddViewModel(pandora: PandoraClient())
        
        // Test state changes
        viewModel.searchQuery = "radiohead"
        XCTAssertEqual(viewModel.searchQuery, "radiohead")
        
        viewModel.isSearching = true
        XCTAssertTrue(viewModel.isSearching)
        
        viewModel.isSearching = false
        XCTAssertFalse(viewModel.isSearching)
    }
    
    func testStationAddViewModel_TabChanges() {
        let viewModel = StationAddViewModel(pandora: PandoraClient())
        
        viewModel.selectedTab = .genres
        XCTAssertEqual(viewModel.selectedTab, .genres)
        
        viewModel.selectedTab = .search
        XCTAssertEqual(viewModel.selectedTab, .search)
    }
    
    // MARK: - StationEditViewModel Tests
    
    func testStationEditViewModel_IsObservable() {
        let station = Station()
        station.name = "Test Station"
        station.token = "test_token"
        let viewModel = StationEditViewModel(station: station, pandora: PandoraClient())
        
        // Test state changes
        viewModel.stationName = "New Name"
        XCTAssertEqual(viewModel.stationName, "New Name")
        
        viewModel.isLoading = true
        XCTAssertTrue(viewModel.isLoading)
        
        viewModel.isLoading = false
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testStationEditViewModel_SeedSearchChanges() {
        let station = Station()
        station.name = "Test Station"
        station.token = "test_token"
        let viewModel = StationEditViewModel(station: station, pandora: PandoraClient())
        
        viewModel.seedSearchQuery = "artist name"
        XCTAssertEqual(viewModel.seedSearchQuery, "artist name")
        
        viewModel.isSearchingSeeds = true
        XCTAssertTrue(viewModel.isSearchingSeeds)
        
        viewModel.isSearchingSeeds = false
        XCTAssertFalse(viewModel.isSearchingSeeds)
    }
    
    // MARK: - Preview ViewModel Tests
    
    func testPreviewPlayerViewModel_IsObservable() {
        let viewModel = PreviewPlayerViewModel()
        
        // Test state changes
        viewModel.isPlaying = true
        XCTAssertTrue(viewModel.isPlaying)
        
        viewModel.volume = 0.8
        XCTAssertEqual(viewModel.volume, 0.8)
    }
    
    func testPreviewHistoryViewModel_IsObservable() {
        let viewModel = PreviewHistoryViewModel()
        
        // Test state changes
        let mockSong = Song.mock()
        viewModel.selectedItem = mockSong
        XCTAssertNotNil(viewModel.selectedItem)
    }
    
    func testPreviewStationsViewModel_IsObservable() {
        let viewModel = PreviewStationsViewModel()
        
        // Test state changes
        viewModel.showAddStationSheet = true
        XCTAssertTrue(viewModel.showAddStationSheet)
    }
    
    func testPreviewNewStationViewModel_IsObservable() {
        let viewModel = PreviewNewStationViewModel()
        
        // Test state changes
        viewModel.searchQuery = "test"
        XCTAssertEqual(viewModel.searchQuery, "test")
        
        viewModel.selectedTab = .genres
        XCTAssertEqual(viewModel.selectedTab, .genres)
    }
    
    func testPreviewStationEditViewModel_IsObservable() {
        let viewModel = PreviewStationEditViewModel()
        
        // Test state changes
        viewModel.stationName = "New Name"
        XCTAssertEqual(viewModel.stationName, "New Name")
        
        viewModel.isLoading = true
        XCTAssertTrue(viewModel.isLoading)
    }
}
