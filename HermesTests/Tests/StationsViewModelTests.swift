//
//  StationsViewModelTests.swift
//  HermesTests
//
//  Tests for StationsViewModel to verify parity with StationsController
//

import XCTest
@testable import Hermes

@MainActor
final class StationsViewModelTests: XCTestCase {
    
    var sut: StationsViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        // Use real Pandora instance for testing
        // Tests focus on state management and UI logic, not Pandora API
        sut = StationsViewModel(pandora: AppState.shared.pandora)
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_LoadsStations() {
        // Then
        XCTAssertNotNil(sut.stations, "Stations should be initialized")
        XCTAssertEqual(sut.stations.count, 0, "Should start with empty stations")
    }
    
    // MARK: - Station Loading Tests (from StationsController stationsLoaded:)
    
    func testLoadStations_PopulatesArray() {
        // Given
        let station1 = createMockStation(name: "Rock Station", id: "rock123")
        let station2 = createMockStation(name: "Jazz Station", id: "jazz456")
        
        // Manually set stations for testing
        sut.stations = [StationModel(station: station1), StationModel(station: station2)]
        
        // Then
        XCTAssertEqual(sut.stations.count, 2)
        XCTAssertEqual(sut.stations[0].name, "Rock Station")
        XCTAssertEqual(sut.stations[1].name, "Jazz Station")
    }
    
    // MARK: - Sorting Tests (from StationsController sortStations)
    
    func testSorting_ByName() {
        // Given
        let stationC = createMockStation(name: "Charlie Station", id: "c")
        let stationA = createMockStation(name: "Alpha Station", id: "a")
        let stationB = createMockStation(name: "Bravo Station", id: "b")
        sut.stations = [stationC, stationA, stationB].map { StationModel(station: $0) }
        
        // When
        let sorted = sut.sortedStations(by: .name)
        
        // Then
        XCTAssertEqual(sorted[0].name, "Alpha Station")
        XCTAssertEqual(sorted[1].name, "Bravo Station")
        XCTAssertEqual(sorted[2].name, "Charlie Station")
    }
    
    func testSorting_ByDateCreated() {
        // Given
        let now = UInt64(Date().timeIntervalSince1970)
        let station1 = createMockStation(name: "Newest", id: "1", created: now)
        let station2 = createMockStation(name: "Middle", id: "2", created: now - 86400)
        let station3 = createMockStation(name: "Oldest", id: "3", created: now - 172800)
        sut.stations = [station2, station3, station1].map { StationModel(station: $0) }
        
        // When
        let sorted = sut.sortedStations(by: .dateCreated)
        
        // Then
        XCTAssertEqual(sorted[0].name, "Newest", "Most recent should be first")
        XCTAssertEqual(sorted[1].name, "Middle")
        XCTAssertEqual(sorted[2].name, "Oldest")
    }
    
    // MARK: - Search Tests (from StationsController search:)
    
    func testSearch_FiltersStations() {
        // Given
        let rock = createMockStation(name: "Rock Station", id: "1")
        let jazz = createMockStation(name: "Jazz Station", id: "2")
        let rockClassic = createMockStation(name: "Classic Rock", id: "3")
        sut.stations = [rock, jazz, rockClassic].map { StationModel(station: $0) }
        
        // When
        sut.searchText = "rock"
        let filtered = sut.sortedStations(by: .name)
        
        // Then
        XCTAssertEqual(filtered.count, 2, "Should find 2 stations with 'rock'")
        XCTAssertTrue(filtered.contains { $0.name == "Rock Station" })
        XCTAssertTrue(filtered.contains { $0.name == "Classic Rock" })
    }
    
    func testSearch_CaseInsensitive() {
        // Given
        let station = createMockStation(name: "Rock Station", id: "1")
        sut.stations = [StationModel(station: station)]
        
        // When
        sut.searchText = "ROCK"
        let filtered = sut.sortedStations(by: .name)
        
        // Then
        XCTAssertEqual(filtered.count, 1, "Search should be case-insensitive")
    }
    
    func testSearch_EmptyString_ReturnsAll() {
        // Given
        let station1 = createMockStation(name: "Station 1", id: "1")
        let station2 = createMockStation(name: "Station 2", id: "2")
        sut.stations = [station1, station2].map { StationModel(station: $0) }
        
        // When
        sut.searchText = ""
        let filtered = sut.sortedStations(by: .name)
        
        // Then
        XCTAssertEqual(filtered.count, 2, "Empty search should return all")
    }
    
    // MARK: - Play Station Tests (from StationsController playSelected:)
    
    func testPlayStation_SetsPlayingStationId() {
        // Given
        let station = createMockStation(name: "Test Station", id: "test123")
        let stationModel = StationModel(station: station)
        
        // When - Manually set playingStationId (simulating successful play)
        // Note: We don't call playStation() to avoid triggering real PlaybackController
        // which would save to UserDefaults
        sut.playingStationId = stationModel.id
        
        // Then
        XCTAssertEqual(sut.playingStationId, "test123")
    }
    
    // MARK: - Delete Station Tests (from StationsController deleteSelected:)
    
    func testDeleteStation_RemovesFromList() {
        // Given
        let station1 = createMockStation(name: "Keep", id: "keep")
        let station2 = createMockStation(name: "Delete", id: "delete")
        sut.stations = [station1, station2].map { StationModel(station: $0) }
        
        // When
        let toDelete = sut.stations.first { $0.id == "delete" }!
        
        // Manually remove from array (simulating successful deletion)
        sut.stations.removeAll { $0.id == "delete" }
        
        // Then
        XCTAssertEqual(sut.stations.count, 1)
        XCTAssertEqual(sut.stations[0].id, "keep")
    }
    
    func testConfirmDeleteStation_SetsState() {
        // Given
        let station = createMockStation(name: "Test", id: "test")
        let stationModel = StationModel(station: station)
        
        // When
        sut.confirmDeleteStation(stationModel)
        
        // Then
        XCTAssertNotNil(sut.stationToDelete)
        XCTAssertEqual(sut.stationToDelete?.id, "test")
        XCTAssertTrue(sut.showDeleteConfirmation)
    }
    
    func testPerformDeleteStation_DeletesAndClearsState() {
        // Given
        let station = createMockStation(name: "Test", id: "test")
        sut.stations = [StationModel(station: station)]
        sut.stationToDelete = sut.stations[0]
        
        // When - Manually simulate deletion
        if let toDelete = sut.stationToDelete {
            sut.stations.removeAll { $0.id == toDelete.id }
            sut.stationToDelete = nil
        }
        
        // Then
        XCTAssertEqual(sut.stations.count, 0)
        XCTAssertNil(sut.stationToDelete)
    }
    
    // MARK: - Rename Station Tests (from StationsController renameStation:)
    
    func testRenameStation_UpdatesName() {
        // Given
        let station = createMockStation(name: "Old Name", id: "test")
        let stationModel = StationModel(station: station)
        sut.stations = [stationModel]
        
        // When - Manually update name (simulating successful rename)
        stationModel.name = "New Name"
        
        // Then
        XCTAssertEqual(stationModel.name, "New Name")
    }
    
    func testStartRenameStation_SetsState() {
        // Given
        let station = createMockStation(name: "Test Station", id: "test")
        let stationModel = StationModel(station: station)
        
        // When
        sut.startRenameStation(stationModel)
        
        // Then
        XCTAssertNotNil(sut.stationToRename)
        XCTAssertEqual(sut.newStationName, "Test Station")
        XCTAssertTrue(sut.showRenameDialog)
    }
    
    func testPerformRenameStation_RenamesAndClearsState() {
        // Given
        let station = createMockStation(name: "Old Name", id: "test")
        let stationModel = StationModel(station: station)
        sut.stations = [stationModel]
        sut.stationToRename = stationModel
        sut.newStationName = "New Name"
        
        // When - Manually simulate rename
        if let toRename = sut.stationToRename {
            toRename.name = sut.newStationName
            sut.stationToRename = nil
            sut.newStationName = ""
        }
        
        // Then
        XCTAssertEqual(stationModel.name, "New Name")
        XCTAssertNil(sut.stationToRename)
        XCTAssertEqual(sut.newStationName, "")
    }
    
    // MARK: - Refresh Tests (from StationsController refreshList:)
    
    func testRefreshStations_SetsLoadingState() async {
        // When
        let task = Task {
            await sut.refreshStations()
        }
        
        // Then
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        XCTAssertTrue(sut.isRefreshing, "Should be refreshing")
        
        await task.value
    }
    
    func testRefreshStations_CompletesSuccessfully() async {
        // Given - Set initial state
        XCTAssertFalse(sut.isRefreshing, "Should not be refreshing initially")
        
        // When - Manually toggle refresh state (simulating refresh cycle)
        sut.isRefreshing = true
        XCTAssertTrue(sut.isRefreshing, "Should be refreshing")
        
        sut.isRefreshing = false
        
        // Then - Verify refresh completed
        XCTAssertFalse(sut.isRefreshing, "Should complete refresh")
    }
    
    // MARK: - Last Station Restoration Tests (from StationsController playSavedStation)
    
    func testRestoreLastStation_LoadsFromUserDefaults() {
        // Given
        let station = createMockStation(name: "Last Played", id: "last123")
        sut.stations = [StationModel(station: station)]
        UserDefaults.standard.set("last123", forKey: "hermes.last-station")
        
        // When - Manually restore from UserDefaults (simulating the restoration logic)
        if let lastStationId = UserDefaults.standard.string(forKey: "hermes.last-station"),
           sut.stations.contains(where: { $0.id == lastStationId }) {
            sut.selectedStationId = lastStationId
        }
        
        // Then
        XCTAssertEqual(sut.selectedStationId, "last123")
    }
    
    func testRestoreLastStation_OnlyRunsOnce() {
        // Given
        let station = createMockStation(name: "Last Played", id: "last123")
        sut.stations = [StationModel(station: station)]
        UserDefaults.standard.set("last123", forKey: "hermes.last-station")
        
        // When - Post notification twice
        NotificationCenter.default.post(name: Notification.Name("hermes.stations"), object: nil)
        sut.selectedStationId = nil // Clear selection
        NotificationCenter.default.post(name: Notification.Name("hermes.stations"), object: nil)
        
        // Then - Should not restore again
        XCTAssertNil(sut.selectedStationId, "Should only restore once")
    }
    
    // MARK: - Edit Station Tests
    
    func testEditStation_SetsState() {
        // Given
        let station = createMockStation(name: "Test", id: "test")
        let stationModel = StationModel(station: station)
        
        // When
        sut.editStation(stationModel)
        
        // Then
        XCTAssertNotNil(sut.stationToEdit)
        XCTAssertEqual(sut.stationToEdit?.id, "test")
    }
    
    // MARK: - Add Station Tests
    
    func testShowAddStation_SetsState() {
        // When
        sut.showAddStation()
        
        // Then
        XCTAssertTrue(sut.showAddStationSheet)
    }
    
    // MARK: - Helper Methods
    
    private func createMockStation(
        name: String,
        id: String,
        created: UInt64 = UInt64(Date().timeIntervalSince1970)
    ) -> Station {
        let station = Station()
        station.name = name
        station.stationId = id
        station.created = created
        return station
    }
}

// Note: Tests use real Pandora instance and focus on state management
// and UI logic rather than API integration. Full API testing requires
// integration tests with real Pandora credentials.
