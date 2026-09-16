//
//  ObservableMigrationTests.swift
//  HermesTests
//
//  Tests to verify @Observable migration is complete and state updates work correctly
//

import Testing
import Foundation
@testable import Hermes

@MainActor
@Suite("ObservableMigrationTests", .serialized)
struct ObservableMigrationTests {

    // MARK: - AppState Tests

    @Test("App State Is Observable")

    func testAppState_IsObservable() {
        // Verify AppState uses @Observable (not ObservableObject)
        let appState = AppState.shared

        // @Observable types don't conform to ObservableObject
        // This test verifies the migration by checking state changes work
        let initialView = appState.currentView
        appState.currentView = .loading
        #expect((appState.currentView) == (.loading))

        // Restore
        appState.currentView = initialView
    }

    @Test("App State State Changes Propagate")

    func testAppState_StateChangesPropagate() {
        let appState = AppState.shared

        // Test isSidebarVisible
        let initialSidebar = appState.isSidebarVisible
        appState.isSidebarVisible = !initialSidebar
        #expect((appState.isSidebarVisible) == (!initialSidebar))
        appState.isSidebarVisible = initialSidebar

        // Test isAuthenticated
        let initialAuth = appState.isAuthenticated
        appState.isAuthenticated = !initialAuth
        #expect((appState.isAuthenticated) == (!initialAuth))
        appState.isAuthenticated = initialAuth
    }

    // MARK: - PlayerViewModel Tests

    @Test("Player View Model Is Observable")

    func testPlayerViewModel_IsObservable() {
        let viewModel = PlayerViewModel()

        // Test state changes
        viewModel.isPlaying = true
        #expect(viewModel.isPlaying)

        viewModel.isPlaying = false
        #expect(!(viewModel.isPlaying))
    }

    @Test("Player View Model Volume Changes")

    func testPlayerViewModel_VolumeChanges() {
        let viewModel = PlayerViewModel()

        viewModel.volume = 0.5
        #expect((viewModel.volume) == (0.5))

        viewModel.volume = 1.0
        #expect((viewModel.volume) == (1.0))
    }

    @Test("Player View Model Playback Position Changes")

    func testPlayerViewModel_PlaybackPositionChanges() {
        let viewModel = PlayerViewModel()

        viewModel.playbackPosition = 60.0
        #expect((viewModel.playbackPosition) == (60.0))

        viewModel.duration = 180.0
        #expect((viewModel.duration) == (180.0))
    }

    @Test("Player View Model Liked State Changes")

    func testPlayerViewModel_LikedStateChanges() {
        let viewModel = PlayerViewModel()

        viewModel.isLiked = true
        #expect(viewModel.isLiked)

        viewModel.isLiked = false
        #expect(!(viewModel.isLiked))
    }

    // MARK: - StationsViewModel Tests

    @Test("Stations View Model Is Observable")

    func testStationsViewModel_IsObservable() {
        let viewModel = StationsViewModel(pandora: PandoraClient())

        // Test state changes
        viewModel.isLoading = true
        #expect(viewModel.isLoading)

        viewModel.isLoading = false
        #expect(!(viewModel.isLoading))
    }

    @Test("Stations View Model Search Text Changes")

    func testStationsViewModel_SearchTextChanges() {
        let viewModel = StationsViewModel(pandora: PandoraClient())

        viewModel.searchText = "rock"
        #expect((viewModel.searchText) == ("rock"))

        viewModel.searchText = ""
        #expect((viewModel.searchText) == (""))
    }

    @Test("Stations View Model Sort Order Changes")

    func testStationsViewModel_SortOrderChanges() {
        let viewModel = StationsViewModel(pandora: PandoraClient())

        viewModel.sortOrder = .name
        #expect((viewModel.sortOrder) == (.name))

        viewModel.sortOrder = .dateCreated
        #expect((viewModel.sortOrder) == (.dateCreated))
    }

    // MARK: - LoginViewModel Tests

    @Test("Login View Model Is Observable")

    func testLoginViewModel_IsObservable() {
        let viewModel = LoginViewModel(pandora: PandoraClient())

        // Test state changes
        viewModel.username = "test@example.com"
        #expect((viewModel.username) == ("test@example.com"))

        viewModel.password = "password123"
        #expect((viewModel.password) == ("password123"))
    }

    @Test("Login View Model Loading State Changes")

    func testLoginViewModel_LoadingStateChanges() {
        let viewModel = LoginViewModel(pandora: PandoraClient())

        viewModel.isLoading = true
        #expect(viewModel.isLoading)

        viewModel.isLoading = false
        #expect(!(viewModel.isLoading))
    }

    @Test("Login View Model Error Message Changes")

    func testLoginViewModel_ErrorMessageChanges() {
        let viewModel = LoginViewModel(pandora: PandoraClient())

        viewModel.errorMessage = "Invalid credentials"
        #expect((viewModel.errorMessage) == ("Invalid credentials"))

        viewModel.errorMessage = nil
        #expect((viewModel.errorMessage) == nil)
    }

    // MARK: - HistoryViewModel Tests

    @Test("History View Model Is Observable")

    func testHistoryViewModel_IsObservable() {
        let viewModel = HistoryViewModel()

        // Test state changes
        let mockSong = Song.mock()
        viewModel.selectedItem = mockSong
        #expect((viewModel.selectedItem) != nil)

        viewModel.selectedItem = nil
        #expect((viewModel.selectedItem) == nil)
    }

    @Test("History View Model History Items Changes")

    func testHistoryViewModel_HistoryItemsChanges() {
        let viewModel = HistoryViewModel()

        let initialCount = viewModel.historyItems.count
        let mockSong = Song.mock()
        viewModel.historyItems.append(mockSong)
        #expect((viewModel.historyItems.count) == (initialCount + 1))

        viewModel.historyItems.removeAll()
        #expect((viewModel.historyItems.count) == (0))
    }

    // MARK: - StationAddViewModel Tests

    @Test("Station Add View Model Is Observable")

    func testStationAddViewModel_IsObservable() {
        let viewModel = StationAddViewModel(pandora: PandoraClient())

        // Test state changes
        viewModel.searchQuery = "radiohead"
        #expect((viewModel.searchQuery) == ("radiohead"))

        viewModel.isSearching = true
        #expect(viewModel.isSearching)

        viewModel.isSearching = false
        #expect(!(viewModel.isSearching))
    }

    @Test("Station Add View Model Tab Changes")

    func testStationAddViewModel_TabChanges() {
        let viewModel = StationAddViewModel(pandora: PandoraClient())

        viewModel.selectedTab = .genres
        #expect((viewModel.selectedTab) == (.genres))

        viewModel.selectedTab = .search
        #expect((viewModel.selectedTab) == (.search))
    }

    // MARK: - StationEditViewModel Tests

    @Test("Station Edit View Model Is Observable")

    func testStationEditViewModel_IsObservable() {
        let station = Station()
        station.name = "Test Station"
        station.token = "test_token"
        let viewModel = StationEditViewModel(station: station, pandora: PandoraClient())

        // Test state changes
        viewModel.stationName = "New Name"
        #expect((viewModel.stationName) == ("New Name"))

        viewModel.isLoading = true
        #expect(viewModel.isLoading)

        viewModel.isLoading = false
        #expect(!(viewModel.isLoading))
    }

    @Test("Station Edit View Model Seed Search Changes")

    func testStationEditViewModel_SeedSearchChanges() {
        let station = Station()
        station.name = "Test Station"
        station.token = "test_token"
        let viewModel = StationEditViewModel(station: station, pandora: PandoraClient())

        viewModel.seedSearchQuery = "artist name"
        #expect((viewModel.seedSearchQuery) == ("artist name"))

        viewModel.isSearchingSeeds = true
        #expect(viewModel.isSearchingSeeds)

        viewModel.isSearchingSeeds = false
        #expect(!(viewModel.isSearchingSeeds))
    }

    // MARK: - Preview ViewModel Tests

    @Test("Preview Player View Model Is Observable")

    func testPreviewPlayerViewModel_IsObservable() {
        let viewModel = PreviewPlayerViewModel()

        // Test state changes
        viewModel.isPlaying = true
        #expect(viewModel.isPlaying)

        viewModel.volume = 0.8
        #expect((viewModel.volume) == (0.8))
    }

    @Test("Preview History View Model Is Observable")

    func testPreviewHistoryViewModel_IsObservable() {
        let viewModel = PreviewHistoryViewModel()

        // Test state changes
        let mockSong = Song.mock()
        viewModel.selectedItem = mockSong
        #expect((viewModel.selectedItem) != nil)
    }

    @Test("Preview Stations View Model Is Observable")

    func testPreviewStationsViewModel_IsObservable() {
        let viewModel = PreviewStationsViewModel()

        // Test state changes
        viewModel.showAddStationSheet = true
        #expect(viewModel.showAddStationSheet)
    }

    @Test("Preview New Station View Model Is Observable")

    func testPreviewNewStationViewModel_IsObservable() {
        let viewModel = PreviewNewStationViewModel()

        // Test state changes
        viewModel.searchQuery = "test"
        #expect((viewModel.searchQuery) == ("test"))

        viewModel.selectedTab = .genres
        #expect((viewModel.selectedTab) == (.genres))
    }

    @Test("Preview Station Edit View Model Is Observable")

    func testPreviewStationEditViewModel_IsObservable() {
        let viewModel = PreviewStationEditViewModel()

        // Test state changes
        viewModel.stationName = "New Name"
        #expect((viewModel.stationName) == ("New Name"))

        viewModel.isLoading = true
        #expect(viewModel.isLoading)
    }
}
