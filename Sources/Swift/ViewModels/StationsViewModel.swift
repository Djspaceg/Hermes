//
//  StationsViewModel.swift
//  Hermes
//
//  Manages station list and operations
//

import Foundation
import Combine
import Observation

/// View model for station management, handling station list display, sorting, and operations.
///
/// This view model uses dependency injection to accept a `PandoraProtocol` implementation,
/// enabling test isolation by allowing mock implementations to be injected during testing.
///
/// ## Dependency Injection Pattern
///
/// The view model accepts a `PandoraProtocol` parameter with a default value for production use:
///
/// ```swift
/// // Production usage (uses default AppState.shared.pandora)
/// let viewModel = StationsViewModel()
///
/// // Test usage (inject mock with pre-configured stations)
/// let mock = MockPandora()
/// mock.mockStations = [station1, station2]
/// let viewModel = StationsViewModel(pandora: mock)
/// ```
///
/// ## Testing
///
/// Use the `testInstance()` helper for convenient test setup:
///
/// ```swift
/// let (viewModel, mock) = StationsViewModel.testInstance()
/// mock.fetchStationsResult = true
/// await viewModel.refreshStations()
/// XCTAssertTrue(mock.didCall(.fetchStations))
/// ```
///
@MainActor
@Observable
final class StationsViewModel {
    var stations: [Station] = []
    var playingStationId: String?
    var selectedStationId: String?
    var sortOrder: SortOrder = .dateCreated
    var isLoading: Bool = false
    var searchText: String = ""
    var stationToEdit: Station?
    var stationToDelete: Station?
    var showDeleteConfirmation = false
    var stationToRename: Station?
    var showRenameDialog = false
    var newStationName = ""
    var isRefreshing = false
    var showAddStationSheet = false
    
    /// Artwork loader for lazy loading station artwork
    let artworkLoader = StationArtworkLoader.shared
    
    @ObservationIgnored
    let pandora: PandoraProtocol
    @ObservationIgnored
    private let userDefaults: UserDefaults
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored
    private var hasRestoredLastStation = false
    
    @MainActor
    init(pandora: PandoraProtocol? = nil, userDefaults: UserDefaults = .standard) {
        self.pandora = pandora ?? AppState.shared.pandora
        self.userDefaults = userDefaults
        
        // Configure artwork loader with Pandora instance (cast to PandoraClient for now)
        if let pandoraClient = self.pandora as? PandoraClient {
            artworkLoader.configure(with: pandoraClient)
        }
        
        setupNotificationSubscriptions()
        
        if self.pandora.isAuthenticated() {
            loadStations()
            // Restore last played station if stations are already available
            if !stations.isEmpty {
                restoreLastPlayedStation()
            }
        }
    }
    
    private func setupNotificationSubscriptions() {
        NotificationCenter.default.pandoraStationsLoadedPublisher
            .sink { [weak self] in
                self?.loadStations()
                self?.isLoading = false
                self?.isRefreshing = false
                self?.restoreLastPlayedStation()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.songPlayingPublisher
            .sink { _ in
                // Song playing notification received - stations don't need to update
            }
            .store(in: &cancellables)
        
        // Station created - reload stations list
        NotificationCenter.default.publisher(for: .pandoraDidCreateStation)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadStations()
                }
            }
            .store(in: &cancellables)
        
        // Station renamed - trigger UI update
        // The Station object is already updated, but we need to trigger a view refresh
        NotificationCenter.default.publisher(for: .pandoraDidRenameStation)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Force array update to trigger SwiftUI refresh
                // This is needed because Station.name change may not propagate to List
                guard let self = self else { return }
                let current = self.stations
                self.stations = current
            }
            .store(in: &cancellables)
        
        // Station deleted - reload stations list
        NotificationCenter.default.publisher(for: .pandoraDidDeleteStation)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                // Remove the deleted station from our list
                if let deletedStation = notification.object as? Station {
                    self.stations.removeAll { $0.id == deletedStation.id }
                } else {
                    // Fallback: reload all stations
                    self.loadStations()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadStations() {
        guard let objcStations = pandora.stations as? [Station] else { return }
        stations = objcStations
        
        // Restore last played timestamps from UserDefaults
        if let timestamps = userDefaults.dictionary(forKey: UserDefaultsKeys.stationPlayTimestamps) as? [String: TimeInterval] {
            for station in stations {
                if let timestamp = timestamps[station.stationId] {
                    station.lastPlayedTimestamp = timestamp
                }
            }
        }
    }
    
    /// Restore and optionally play the last played station
    private func restoreLastPlayedStation() {
        guard !hasRestoredLastStation else { return }
        hasRestoredLastStation = true
        
        guard let lastStationId = userDefaults.string(forKey: UserDefaultsKeys.lastStation) else {
            print("StationsViewModel: No last station saved")
            return
        }
        
        guard let station = stations.first(where: { $0.id == lastStationId }) else {
            print("StationsViewModel: Last station '\(lastStationId)' not found in stations list")
            return
        }
        
        print("StationsViewModel: Restoring last station '\(station.name)'")
        
        // Select the station in the list
        selectedStationId = station.id
        
        // Auto-play if user preference is enabled (default: true)
        let shouldAutoPlay = SettingsManager.shared.playAutomaticallyOnLaunch
        if shouldAutoPlay {
            print("StationsViewModel: Auto-playing last station (user preference enabled)")
            playStation(station)
        } else {
            print("StationsViewModel: Not auto-playing (user preference disabled)")
            // Just highlight it
            playingStationId = station.id
        }
    }
    
    func sortedStations(by order: SortOrder) -> [Station] {
        var result = stations
        
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        switch order {
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .dateCreated:
            result.sort { $0.created > $1.created }
        case .recentlyPlayed:
            result.sort { station1, station2 in
                // Stations with no play history go to the bottom
                switch (station1.lastPlayedTimestamp, station2.lastPlayedTimestamp) {
                case (nil, nil):
                    // Both never played - sort by creation date as fallback
                    return station1.created > station2.created
                case (nil, _):
                    // station1 never played - goes after station2
                    return false
                case (_, nil):
                    // station2 never played - station1 goes first
                    return true
                case let (time1?, time2?):
                    // Both have been played - most recent first
                    return time1 > time2
                }
            }
        }
        
        return result
    }
    
    func refreshStations() async {
        isRefreshing = true
        _ = pandora.fetchStations()
        // isRefreshing will be set to false by the notification handler
    }
    
    func startRenameStation(_ station: Station) {
        stationToRename = station
        newStationName = station.name
        showRenameDialog = true
    }
    
    func performRenameStation() {
        guard let station = stationToRename, !newStationName.isEmpty else { return }
        renameStation(station, to: newStationName)
        stationToRename = nil
        newStationName = ""
    }
    
    func playStation(_ station: Station) {
        print("StationsViewModel: playStation called for '\(station.name)'")
        print("StationsViewModel: PlaybackController = \(String(describing: MinimalAppDelegate.shared?.playbackController))")
        
        guard let controller = MinimalAppDelegate.shared?.playbackController else {
            print("StationsViewModel: ERROR - PlaybackController is nil!")
            return
        }
        
        print("StationsViewModel: Calling controller.playStation() with station")
        controller.playStation(station)
        playingStationId = station.id
        print("StationsViewModel: Set playingStationId to \(station.id)")
    }
    
    func confirmDeleteStation(_ station: Station) {
        stationToDelete = station
        showDeleteConfirmation = true
    }
    
    func performDeleteStation() {
        guard let station = stationToDelete else { return }
        _ = pandora.removeStation(station.token)
        stations.removeAll { $0.id == station.id }
        stationToDelete = nil
    }
    
    func deleteStation(_ station: Station) {
        _ = pandora.removeStation(station.token)
        stations.removeAll { $0.id == station.id }
    }
    
    func renameStation(_ station: Station, to name: String) {
        _ = pandora.renameStation(station.token, to: name)
        station.name = name
    }
    
    func editStation(_ station: Station) {
        stationToEdit = station
    }
    
    func showAddStation() {
        showAddStationSheet = true
    }
    
    enum SortOrder {
        case name
        case dateCreated
        case recentlyPlayed
    }
}


// MARK: - Preview Helpers

extension StationsViewModel {
    /// Creates a mock StationsViewModel for SwiftUI previews
    static func mock(
        stations: [Station] = [],
        playingStationId: String? = nil
    ) -> StationsViewModel {
        let viewModel = StationsViewModel(pandora: PandoraClient())
        viewModel.stations = stations
        viewModel.playingStationId = playingStationId
        return viewModel
    }
}
