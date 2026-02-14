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
    var mockPandora: MockPandora!
    var testDefaults: UserDefaults!
    
    override func setUp() async throws {
        try await super.setUp()
        mockPandora = MockPandora()
        testDefaults = UserDefaults(suiteName: "com.hermes.tests.stations.\(UUID().uuidString)")!
        sut = StationsViewModel(pandora: mockPandora, userDefaults: testDefaults)
    }
    
    override func tearDown() async throws {
        sut = nil
        mockPandora = nil
        testDefaults = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_LoadsStations() {
        XCTAssertNotNil(sut.stations, "Stations should be initialized")
        XCTAssertEqual(sut.stations.count, 0, "Should start with empty stations")
    }
    
    // MARK: - Station Loading Tests
    
    func testLoadStations_PopulatesArray() {
        let station1 = createMockStation(name: "Rock Station", id: "rock123")
        let station2 = createMockStation(name: "Jazz Station", id: "jazz456")
        sut.stations = [station1, station2]
        
        XCTAssertEqual(sut.stations.count, 2)
        XCTAssertEqual(sut.stations[0].name, "Rock Station")
        XCTAssertEqual(sut.stations[1].name, "Jazz Station")
    }
    
    // MARK: - Sorting Tests
    
    func testSorting_ByName() {
        let stationC = createMockStation(name: "Charlie Station", id: "c")
        let stationA = createMockStation(name: "Alpha Station", id: "a")
        let stationB = createMockStation(name: "Bravo Station", id: "b")
        sut.stations = [stationC, stationA, stationB]
        
        let sorted = sut.sortedStations(by: .name)
        
        XCTAssertEqual(sorted[0].name, "Alpha Station")
        XCTAssertEqual(sorted[1].name, "Bravo Station")
        XCTAssertEqual(sorted[2].name, "Charlie Station")
    }
    
    func testSorting_ByDateCreated() {
        let now = UInt64(Date().timeIntervalSince1970)
        let station1 = createMockStation(name: "Newest", id: "1", created: now)
        let station2 = createMockStation(name: "Middle", id: "2", created: now - 86400)
        let station3 = createMockStation(name: "Oldest", id: "3", created: now - 172800)
        sut.stations = [station2, station3, station1]
        
        let sorted = sut.sortedStations(by: .dateCreated)
        
        XCTAssertEqual(sorted[0].name, "Newest", "Most recent should be first")
        XCTAssertEqual(sorted[1].name, "Middle")
        XCTAssertEqual(sorted[2].name, "Oldest")
    }
    
    func testSorting_ByRecentlyPlayed() {
        let now = Date().timeIntervalSince1970
        let station1 = createMockStation(name: "Played Today", id: "1")
        station1.lastPlayedTimestamp = now
        let station2 = createMockStation(name: "Played Yesterday", id: "2")
        station2.lastPlayedTimestamp = now - 86400
        let station3 = createMockStation(name: "Never Played", id: "3")
        station3.lastPlayedTimestamp = nil
        sut.stations = [station3, station2, station1]
        
        let sorted = sut.sortedStations(by: .recentlyPlayed)
        
        XCTAssertEqual(sorted[0].name, "Played Today", "Most recently played should be first")
        XCTAssertEqual(sorted[1].name, "Played Yesterday")
        XCTAssertEqual(sorted[2].name, "Never Played", "Never played stations should be last")
    }
    
    // MARK: - Search Tests
    
    func testSearch_FiltersStations() {
        let rock = createMockStation(name: "Rock Station", id: "1")
        let jazz = createMockStation(name: "Jazz Station", id: "2")
        let rockClassic = createMockStation(name: "Classic Rock", id: "3")
        sut.stations = [rock, jazz, rockClassic]
        
        sut.searchText = "rock"
        let filtered = sut.sortedStations(by: .name)
        
        XCTAssertEqual(filtered.count, 2, "Should find 2 stations with 'rock'")
        XCTAssertTrue(filtered.contains { $0.name == "Rock Station" })
        XCTAssertTrue(filtered.contains { $0.name == "Classic Rock" })
    }
    
    func testSearch_CaseInsensitive() {
        let station = createMockStation(name: "Rock Station", id: "1")
        sut.stations = [station]
        
        sut.searchText = "ROCK"
        let filtered = sut.sortedStations(by: .name)
        
        XCTAssertEqual(filtered.count, 1, "Search should be case-insensitive")
    }
    
    func testSearch_EmptyString_ReturnsAll() {
        let station1 = createMockStation(name: "Station 1", id: "1")
        let station2 = createMockStation(name: "Station 2", id: "2")
        sut.stations = [station1, station2]
        
        sut.searchText = ""
        let filtered = sut.sortedStations(by: .name)
        
        XCTAssertEqual(filtered.count, 2, "Empty search should return all")
    }
    
    // MARK: - Play Station Tests
    
    func testPlayStation_SetsPlayingStationId() {
        let station = createMockStation(name: "Test Station", id: "test123")
        sut.playingStationId = station.id
        XCTAssertEqual(sut.playingStationId, "test123")
    }
    
    // MARK: - Delete Station Tests
    
    func testDeleteStation_RemovesFromList() {
        let station1 = createMockStation(name: "Keep", id: "keep")
        let station2 = createMockStation(name: "Delete", id: "delete")
        sut.stations = [station1, station2]
        
        sut.stations.removeAll { $0.id == "delete" }
        
        XCTAssertEqual(sut.stations.count, 1)
        XCTAssertEqual(sut.stations[0].id, "keep")
    }
    
    func testConfirmDeleteStation_SetsState() {
        let station = createMockStation(name: "Test", id: "test")
        sut.confirmDeleteStation(station)
        
        XCTAssertNotNil(sut.stationToDelete)
        XCTAssertEqual(sut.stationToDelete?.id, "test")
        XCTAssertTrue(sut.showDeleteConfirmation)
    }
    
    func testPerformDeleteStation_DeletesAndClearsState() {
        let station = createMockStation(name: "Test", id: "test")
        sut.stations = [station]
        sut.stationToDelete = sut.stations[0]
        
        if let toDelete = sut.stationToDelete {
            sut.stations.removeAll { $0.id == toDelete.id }
            sut.stationToDelete = nil
        }
        
        XCTAssertEqual(sut.stations.count, 0)
        XCTAssertNil(sut.stationToDelete)
    }
    
    // MARK: - Rename Station Tests
    
    func testRenameStation_UpdatesName() {
        let station = createMockStation(name: "Old Name", id: "test")
        sut.stations = [station]
        station.name = "New Name"
        XCTAssertEqual(station.name, "New Name")
    }
    
    func testStartRenameStation_SetsState() {
        let station = createMockStation(name: "Test Station", id: "test")
        sut.startRenameStation(station)
        
        XCTAssertNotNil(sut.stationToRename)
        XCTAssertEqual(sut.newStationName, "Test Station")
        XCTAssertTrue(sut.showRenameDialog)
    }
    
    func testPerformRenameStation_RenamesAndClearsState() {
        let station = createMockStation(name: "Old Name", id: "test")
        sut.stations = [station]
        sut.stationToRename = station
        sut.newStationName = "New Name"
        
        if let toRename = sut.stationToRename {
            toRename.name = sut.newStationName
            sut.stationToRename = nil
            sut.newStationName = ""
        }
        
        XCTAssertEqual(station.name, "New Name")
        XCTAssertNil(sut.stationToRename)
        XCTAssertEqual(sut.newStationName, "")
    }
    
    // MARK: - Refresh Tests
    
    func testRefreshStations_SetsLoadingState() async {
        let task = Task { await sut.refreshStations() }
        try? await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertTrue(sut.isRefreshing, "Should be refreshing")
        await task.value
    }
    
    func testRefreshStations_CompletesSuccessfully() async {
        XCTAssertFalse(sut.isRefreshing)
        sut.isRefreshing = true
        XCTAssertTrue(sut.isRefreshing)
        sut.isRefreshing = false
        XCTAssertFalse(sut.isRefreshing, "Should complete refresh")
    }
    
    // MARK: - Last Station Restoration Tests
    
    func testRestoreLastStation_LoadsFromUserDefaults() {
        let station = createMockStation(name: "Last Played", id: "last123")
        sut.stations = [station]
        testDefaults.set("last123", forKey: UserDefaultsKeys.lastStation)
        
        if let lastStationId = testDefaults.string(forKey: UserDefaultsKeys.lastStation),
           sut.stations.contains(where: { $0.id == lastStationId }) {
            sut.selectedStationId = lastStationId
        }
        
        XCTAssertEqual(sut.selectedStationId, "last123")
    }
    
    func testRestoreLastStation_OnlyRunsOnce() {
        let station = createMockStation(name: "Last Played", id: "last123")
        sut.stations = [station]
        testDefaults.set("last123", forKey: UserDefaultsKeys.lastStation)
        
        NotificationCenter.default.post(name: Notification.Name("hermes.stations"), object: nil)
        sut.selectedStationId = nil
        NotificationCenter.default.post(name: Notification.Name("hermes.stations"), object: nil)
        
        XCTAssertNil(sut.selectedStationId, "Should only restore once")
    }
    
    // MARK: - Edit / Add Station Tests
    
    func testEditStation_SetsState() {
        let station = createMockStation(name: "Test", id: "test")
        sut.editStation(station)
        
        XCTAssertNotNil(sut.stationToEdit)
        XCTAssertEqual(sut.stationToEdit?.id, "test")
    }
    
    func testShowAddStation_SetsState() {
        sut.showAddStation()
        XCTAssertTrue(sut.showAddStationSheet)
    }
    
    // MARK: - Timestamp Persistence Tests
    
    func testLoadStations_RestoresTimestampsFromUserDefaults() {
        let station1 = createMockStation(name: "Station 1", id: "id1")
        let station2 = createMockStation(name: "Station 2", id: "id2")
        
        let timestamp1 = Date().timeIntervalSince1970 - 3600
        let timestamp2 = Date().timeIntervalSince1970 - 7200
        let timestamps: [String: TimeInterval] = ["id1": timestamp1, "id2": timestamp2]
        testDefaults.set(timestamps, forKey: UserDefaultsKeys.stationPlayTimestamps)
        
        sut.stations = [station1, station2]
        if let savedTimestamps = testDefaults.dictionary(forKey: UserDefaultsKeys.stationPlayTimestamps) as? [String: TimeInterval] {
            for station in sut.stations {
                if let timestamp = savedTimestamps[station.stationId] {
                    station.lastPlayedTimestamp = timestamp
                }
            }
        }
        
        XCTAssertNotNil(station1.lastPlayedTimestamp)
        XCTAssertNotNil(station2.lastPlayedTimestamp)
        XCTAssertEqual(station1.lastPlayedTimestamp!, timestamp1, accuracy: 0.001)
        XCTAssertEqual(station2.lastPlayedTimestamp!, timestamp2, accuracy: 0.001)
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
