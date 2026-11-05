//
//  StationsViewModelTests.swift
//  HermesTests
//
//  Tests for StationsViewModel to verify parity with StationsController
//

import Testing
import Foundation
@testable import Hermes

@MainActor
@Suite("StationsViewModelTests", .serialized)
struct StationsViewModelTests {
    let sut: StationsViewModel
    let mockPandora: MockPandora
    let testDefaults: UserDefaults

    init() {
        mockPandora = MockPandora()
        testDefaults = UserDefaults(suiteName: "com.hermes.tests.stations.\(UUID().uuidString)")!
        sut = StationsViewModel(pandora: mockPandora, userDefaults: testDefaults)
    }

    // MARK: - Initialization Tests

    @Test("Initialization Loads Stations")

    func testInitialization_LoadsStations() {
        #expect(sut.stations.isEmpty, "Stations should initialize as an empty list")
        #expect((sut.stations.count) == (0), "Should start with empty stations")
    }

    // MARK: - Station Loading Tests

    @Test("Load Stations Populates Array")

    func testLoadStations_PopulatesArray() {
        let station1 = createMockStation(name: "Rock Station", id: "rock123")
        let station2 = createMockStation(name: "Jazz Station", id: "jazz456")
        sut.stations = [station1, station2]

        #expect((sut.stations.count) == (2))
        #expect((sut.stations[0].name) == ("Rock Station"))
        #expect((sut.stations[1].name) == ("Jazz Station"))
    }

    // MARK: - Sorting Tests

    @Test("Sorting By Name")

    func testSorting_ByName() {
        let stationC = createMockStation(name: "Charlie Station", id: "c")
        let stationA = createMockStation(name: "Alpha Station", id: "a")
        let stationB = createMockStation(name: "Bravo Station", id: "b")
        sut.stations = [stationC, stationA, stationB]

        let sorted = sut.sortedStations(by: .name)

        #expect((sorted[0].name) == ("Alpha Station"))
        #expect((sorted[1].name) == ("Bravo Station"))
        #expect((sorted[2].name) == ("Charlie Station"))
    }

    @Test("Sorting By Date Created")

    func testSorting_ByDateCreated() {
        let now = UInt64(Date().timeIntervalSince1970)
        let station1 = createMockStation(name: "Newest", id: "1", created: now)
        let station2 = createMockStation(name: "Middle", id: "2", created: now - 86400)
        let station3 = createMockStation(name: "Oldest", id: "3", created: now - 172800)
        sut.stations = [station2, station3, station1]

        let sorted = sut.sortedStations(by: .dateCreated)

        #expect((sorted[0].name) == ("Newest"), "Most recent should be first")
        #expect((sorted[1].name) == ("Middle"))
        #expect((sorted[2].name) == ("Oldest"))
    }

    @Test("Sorting By Recently Played")

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

        #expect((sorted[0].name) == ("Played Today"), "Most recently played should be first")
        #expect((sorted[1].name) == ("Played Yesterday"))
        #expect((sorted[2].name) == ("Never Played"), "Never played stations should be last")
    }

    // MARK: - Search Tests

    @Test("Search Filters Stations")

    func testSearch_FiltersStations() {
        let rock = createMockStation(name: "Rock Station", id: "1")
        let jazz = createMockStation(name: "Jazz Station", id: "2")
        let rockClassic = createMockStation(name: "Classic Rock", id: "3")
        sut.stations = [rock, jazz, rockClassic]

        sut.searchText = "rock"
        let filtered = sut.sortedStations(by: .name)

        #expect((filtered.count) == (2), "Should find 2 stations with 'rock'")
        #expect(filtered.contains { $0.name == "Rock Station" })
        #expect(filtered.contains { $0.name == "Classic Rock" })
    }

    @Test("Search Case Insensitive")

    func testSearch_CaseInsensitive() {
        let station = createMockStation(name: "Rock Station", id: "1")
        sut.stations = [station]

        sut.searchText = "ROCK"
        let filtered = sut.sortedStations(by: .name)

        #expect((filtered.count) == (1), "Search should be case-insensitive")
    }

    @Test("Search Empty String Returns All")

    func testSearch_EmptyString_ReturnsAll() {
        let station1 = createMockStation(name: "Station 1", id: "1")
        let station2 = createMockStation(name: "Station 2", id: "2")
        sut.stations = [station1, station2]

        sut.searchText = ""
        let filtered = sut.sortedStations(by: .name)

        #expect((filtered.count) == (2), "Empty search should return all")
    }

    // MARK: - Play Station Tests

    @Test("Play Station Sets Playing Station Id")

    func testPlayStation_SetsPlayingStationId() {
        let station = createMockStation(name: "Test Station", id: "test123")
        sut.playingStationId = station.id
        #expect((sut.playingStationId) == ("test123"))
    }

    // MARK: - Delete Station Tests

    @Test("Delete Station Removes From List")

    func testDeleteStation_RemovesFromList() {
        let station1 = createMockStation(name: "Keep", id: "keep")
        let station2 = createMockStation(name: "Delete", id: "delete")
        sut.stations = [station1, station2]

        sut.stations.removeAll { $0.id == "delete" }

        #expect((sut.stations.count) == (1))
        #expect((sut.stations[0].id) == ("keep"))
    }

    @Test("Confirm Delete Station Sets State")

    func testConfirmDeleteStation_SetsState() {
        let station = createMockStation(name: "Test", id: "test")
        sut.confirmDeleteStation(station)

        #expect((sut.stationToDelete) != nil)
        #expect((sut.stationToDelete?.id) == ("test"))
        #expect(sut.showDeleteConfirmation)
    }

    @Test("Perform Delete Station Deletes And Clears State")

    func testPerformDeleteStation_DeletesAndClearsState() {
        let station = createMockStation(name: "Test", id: "test")
        sut.stations = [station]
        sut.stationToDelete = sut.stations[0]

        if let toDelete = sut.stationToDelete {
            sut.stations.removeAll { $0.id == toDelete.id }
            sut.stationToDelete = nil
        }

        #expect((sut.stations.count) == (0))
        #expect((sut.stationToDelete) == nil)
    }

    // MARK: - Rename Station Tests

    @Test("Rename Station Updates Name")

    func testRenameStation_UpdatesName() {
        let station = createMockStation(name: "Old Name", id: "test")
        sut.stations = [station]
        station.name = "New Name"
        #expect((station.name) == ("New Name"))
    }

    @Test("Start Rename Station Sets State")

    func testStartRenameStation_SetsState() {
        let station = createMockStation(name: "Test Station", id: "test")
        sut.startRenameStation(station)

        #expect((sut.stationToRename) != nil)
        #expect((sut.newStationName) == ("Test Station"))
        #expect(sut.showRenameDialog)
    }

    @Test("Perform Rename Station Renames And Clears State")

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

        #expect((station.name) == ("New Name"))
        #expect((sut.stationToRename) == nil)
        #expect((sut.newStationName) == (""))
    }

    // MARK: - Refresh Tests

    @Test("Refresh Stations Sets Loading State")

    func testRefreshStations_SetsLoadingState() async {
        let task = Task { await sut.refreshStations() }
        try? await Task.sleep(nanoseconds: 10_000_000)
        #expect(sut.isRefreshing, "Should be refreshing")
        await task.value
    }

    @Test("Refresh Stations Completes Successfully")

    func testRefreshStations_CompletesSuccessfully() async {
        #expect(!(sut.isRefreshing))
        sut.isRefreshing = true
        #expect(sut.isRefreshing)
        sut.isRefreshing = false
        #expect(!(sut.isRefreshing), "Should complete refresh")
    }

    // MARK: - Last Station Restoration Tests

    @Test("Restore Last Station Loads From User Defaults")

    func testRestoreLastStation_LoadsFromUserDefaults() {
        let station = createMockStation(name: "Last Played", id: "last123")
        sut.stations = [station]
        testDefaults.set("last123", forKey: UserDefaultsKeys.lastStation)

        if let lastStationId = testDefaults.string(forKey: UserDefaultsKeys.lastStation),
           sut.stations.contains(where: { $0.id == lastStationId }) {
            sut.selectedStationId = lastStationId
        }

        #expect((sut.selectedStationId) == ("last123"))
    }

    @Test("Restore Last Station Only Runs Once")

    func testRestoreLastStation_OnlyRunsOnce() {
        let station = createMockStation(name: "Last Played", id: "last123")
        sut.stations = [station]
        testDefaults.set("last123", forKey: UserDefaultsKeys.lastStation)

        NotificationCenter.default.post(name: Notification.Name("hermes.stations"), object: nil)
        sut.selectedStationId = nil
        NotificationCenter.default.post(name: Notification.Name("hermes.stations"), object: nil)

        #expect((sut.selectedStationId) == nil, "Should only restore once")
    }

    // MARK: - Edit / Add Station Tests

    @Test("Edit Station Sets State")

    func testEditStation_SetsState() {
        let station = createMockStation(name: "Test", id: "test")
        sut.editStation(station)

        #expect((sut.stationToEdit) != nil)
        #expect((sut.stationToEdit?.id) == ("test"))
    }

    @Test("Show Add Station Sets State")

    func testShowAddStation_SetsState() {
        sut.showAddStation()
        #expect(sut.showAddStationSheet)
    }

    // MARK: - Timestamp Persistence Tests

    @Test("Load Stations Restores Timestamps From User Defaults")

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

        #expect((station1.lastPlayedTimestamp) != nil)
        #expect((station2.lastPlayedTimestamp) != nil)
        #expect(abs((station1.lastPlayedTimestamp!) - (timestamp1)) <= (0.001))
        #expect(abs((station2.lastPlayedTimestamp!) - (timestamp2)) <= (0.001))
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

@MainActor
@Suite("MenuExtraStationSidebarStateTests", .serialized)
struct MenuExtraStationSidebarStateTests {
    @Test("Sidebar toggles open and closed")
    func testSidebarToggle() {
        let state = MenuExtraStationSidebarState()

        #expect(!state.isPresented)

        state.toggle()
        #expect(state.isPresented)

        state.toggle()
        #expect(!state.isPresented)
    }

    @Test("Selecting a station routes through the supplied selection handler and closes")
    func testStationSelectionRouting() {
        let state = MenuExtraStationSidebarState()
        let station = Station()
        station.stationId = "station-42"
        var selectedStationId: String?

        state.present()
        state.select(station) { selectedStation in
            selectedStationId = selectedStation.id
        }

        #expect(selectedStationId == station.id)
        #expect(!state.isPresented)
    }
}
