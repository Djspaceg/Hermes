//
//  StationArtworkLoader.swift
//  Hermes
//
//  Lazy loading service for station artwork
//

import Foundation
import Combine

/// Manages lazy loading of station artwork URLs via the Pandora API
@MainActor
final class StationArtworkLoader: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = StationArtworkLoader()
    
    // MARK: - Published Properties
    
    /// Stations that have had their artwork loaded (by station ID)
    @Published private(set) var loadedStations: Set<String> = []
    
    /// Trigger for views to refresh when artwork becomes available
    @Published private(set) var artworkUpdateTrigger: UUID = UUID()
    
    // MARK: - Private Properties
    
    private var pendingRequests: Set<String> = []
    private var stationNameToId: [String: String] = [:]
    private var cancellables = Set<AnyCancellable>()
    private weak var pandora: Pandora?
    
    // MARK: - Initialization
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - Configuration
    
    /// Set the Pandora instance to use for API calls
    func configure(with pandora: Pandora) {
        self.pandora = pandora
    }
    
    // MARK: - Public API
    
    /// Request artwork for a station if not already loaded or pending
    /// - Parameter station: The station to load artwork for
    func loadArtworkIfNeeded(for station: Station) {
        let stationId = station.stationId ?? ""
        let stationName = station.name ?? ""
        
        // Skip if already loaded, pending, or already has artwork
        guard !stationId.isEmpty,
              !loadedStations.contains(stationId),
              !pendingRequests.contains(stationId),
              station.artUrl == nil else {
            return
        }
        
        // Mark as pending and track name->id mapping
        pendingRequests.insert(stationId)
        stationNameToId[stationName] = stationId
        
        // Fetch station info (which includes artwork URL)
        pandora?.fetchStationInfo(station)
    }
    
    /// Check if artwork has been loaded for a station
    func isLoaded(_ stationId: String) -> Bool {
        loadedStations.contains(stationId)
    }
    
    /// Get artwork URL for a station (returns nil if not yet loaded)
    func artworkURL(for station: Station) -> URL? {
        guard let artUrl = station.artUrl else { return nil }
        return URL(string: artUrl)
    }
    
    // MARK: - Notification Handling
    
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidLoadStationInfoNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleStationInfoLoaded(notification)
            }
            .store(in: &cancellables)
    }
    
    private func handleStationInfoLoaded(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any],
              let stationName = userInfo["name"] as? String else {
            return
        }
        
        // Find the station by name
        guard let stations = pandora?.stations as? [Station],
              let station = stations.first(where: { $0.name == stationName }) else {
            return
        }
        
        let stationId = station.stationId ?? ""
        
        // Update the station's artUrl from the notification
        if let artUrl = userInfo["art"] as? String {
            station.artUrl = artUrl
        }
        
        // Update genres if available
        if let genres = userInfo["genres"] as? [String] {
            station.genres = genres
        }
        
        // Mark as loaded and clean up
        pendingRequests.remove(stationId)
        stationNameToId.removeValue(forKey: stationName)
        loadedStations.insert(stationId)
        
        // Trigger UI refresh
        artworkUpdateTrigger = UUID()
    }
}
