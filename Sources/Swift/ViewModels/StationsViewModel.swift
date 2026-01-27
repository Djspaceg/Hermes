//
//  StationsViewModel.swift
//  Hermes
//
//  Manages station list and operations
//

import Foundation
import Combine

@MainActor
final class StationsViewModel: ObservableObject {
    @Published var stations: [StationModel] = []
    @Published var playingStationId: String?
    @Published var selectedStationId: String?
    @Published var sortOrder: SortOrder = .dateCreated
    @Published var isLoading: Bool = false
    @Published var searchText: String = ""
    @Published var stationToEdit: StationModel?
    @Published var stationToDelete: StationModel?
    @Published var showDeleteConfirmation = false
    @Published var stationToRename: StationModel?
    @Published var showRenameDialog = false
    @Published var newStationName = ""
    @Published var isRefreshing = false
    @Published var showAddStationSheet = false
    
    /// Artwork loader for lazy loading station artwork
    let artworkLoader = StationArtworkLoader.shared
    
    let pandora: Pandora
    private var cancellables = Set<AnyCancellable>()
    private var hasRestoredLastStation = false
    
    init(pandora: Pandora) {
        self.pandora = pandora
        
        // Configure artwork loader with Pandora instance
        artworkLoader.configure(with: pandora)
        
        setupNotificationSubscriptions()
        
        if pandora.isAuthenticated() {
            loadStations()
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
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidCreateStationNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadStations()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadStations() {
        guard let objcStations = pandora.stations as? [Station] else { return }
        stations = objcStations.map { StationModel(station: $0) }
    }
    
    /// Restore and optionally play the last played station
    private func restoreLastPlayedStation() {
        guard !hasRestoredLastStation else { return }
        hasRestoredLastStation = true
        
        guard let lastStationId = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastStation) else {
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
    
    func sortedStations(by order: SortOrder) -> [StationModel] {
        var result = stations
        
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        switch order {
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .dateCreated:
            result.sort { $0.created > $1.created }
        }
        
        return result
    }
    
    func refreshStations() async {
        isRefreshing = true
        _ = pandora.fetchStations()
        // isRefreshing will be set to false by the notification handler
    }
    
    func startRenameStation(_ station: StationModel) {
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
    
    func playStation(_ station: StationModel) {
        print("StationsViewModel: playStation called for '\(station.name)'")
        print("StationsViewModel: PlaybackController = \(String(describing: MinimalAppDelegate.shared?.playbackController))")
        
        guard let controller = MinimalAppDelegate.shared?.playbackController else {
            print("StationsViewModel: ERROR - PlaybackController is nil!")
            return
        }
        
        print("StationsViewModel: Calling controller.play() with station")
        controller.play(station.station)
        playingStationId = station.id
        print("StationsViewModel: Set playingStationId to \(station.id)")
    }
    
    func confirmDeleteStation(_ station: StationModel) {
        stationToDelete = station
        showDeleteConfirmation = true
    }
    
    func performDeleteStation() {
        guard let station = stationToDelete else { return }
        _ = pandora.removeStation(station.station.token)
        stations.removeAll { $0.id == station.id }
        stationToDelete = nil
    }
    
    func deleteStation(_ station: StationModel) {
        _ = pandora.removeStation(station.station.token)
        stations.removeAll { $0.id == station.id }
    }
    
    func renameStation(_ station: StationModel, to name: String) {
        _ = pandora.renameStation(station.station.token, to: name)
        station.name = name
    }
    
    func editStation(_ station: StationModel) {
        stationToEdit = station
    }
    
    func showAddStation() {
        showAddStationSheet = true
    }
    
    enum SortOrder {
        case name
        case dateCreated
    }
}


// MARK: - Preview Helpers

extension StationsViewModel {
    /// Creates a mock StationsViewModel for SwiftUI previews
    static func mock(
        stations: [StationModel] = [],
        playingStationId: String? = nil
    ) -> StationsViewModel {
        let viewModel = StationsViewModel(pandora: Pandora())
        viewModel.stations = stations
        viewModel.playingStationId = playingStationId
        return viewModel
    }
}
