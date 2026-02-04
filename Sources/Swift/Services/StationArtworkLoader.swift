//
//  StationArtworkLoader.swift
//  Hermes
//
//  Lazy loading service for station artwork with disk caching
//

import Foundation
import Combine

/// Cached station info stored to disk
private struct CachedStationInfo: Codable {
    let artUrl: String?
    let genres: [String]
}

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
    private weak var pandora: PandoraClient?
    
    /// In-memory cache of station info (stationId -> CachedStationInfo)
    private var cache: [String: CachedStationInfo] = [:]
    
    private var cacheFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let hermesDir = appSupport.appendingPathComponent("Hermes", isDirectory: true)
        return hermesDir.appendingPathComponent("station_artwork_cache.json")
    }
    
    // MARK: - Initialization
    
    private init() {
        loadCacheFromDisk()
        setupNotificationObservers()
    }
    
    // MARK: - Configuration
    
    /// Set the Pandora instance to use for API calls
    func configure(with pandora: PandoraClient) {
        self.pandora = pandora
    }
    
    // MARK: - Public API
    
    /// Request artwork for a station if not already loaded or pending
    /// - Parameter station: The station to load artwork for
    func loadArtworkIfNeeded(for station: Station) {
        let stationId = station.stationId ?? ""
        let stationName = station.name ?? ""
        
        guard !stationId.isEmpty else { return }
        
        // Check if already has artwork set
        if station.artUrl != nil {
            loadedStations.insert(stationId)
            return
        }
        
        // Try to restore from cache
        if let cached = cache[stationId] {
            print("StationArtworkLoader: Cache hit for station \(stationId), artUrl: \(cached.artUrl ?? "nil")")
            station.artUrl = cached.artUrl
            station.genres = cached.genres
            loadedStations.insert(stationId)
            
            // Post notification so StationModel updates its artworkURL
            // Build userInfo carefully to avoid nil values
            var userInfo: [String: Any] = [
                "name": stationName,
                "genres": cached.genres
            ]
            if let artUrl = cached.artUrl {
                userInfo["art"] = artUrl
            }
            
            NotificationCenter.default.post(
                name: Notification.Name("PandoraDidLoadStationInfoNotification"),
                object: "cache",
                userInfo: userInfo
            )
            
            artworkUpdateTrigger = UUID()
            return
        }
        
        print("StationArtworkLoader: Cache miss for station \(stationId), fetching from API")
        
        // Skip if already loaded or pending
        guard !loadedStations.contains(stationId),
              !pendingRequests.contains(stationId) else {
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
    
    // MARK: - Cache Persistence
    
    private func loadCacheFromDisk() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            print("StationArtworkLoader: No cache file found at \(cacheFileURL.path)")
            return
        }
        
        do {
            let data = try Data(contentsOf: cacheFileURL)
            cache = try JSONDecoder().decode([String: CachedStationInfo].self, from: data)
            print("StationArtworkLoader: Loaded \(cache.count) cached stations from disk")
        } catch {
            print("StationArtworkLoader: Failed to load cache: \(error)")
        }
    }
    
    private func saveCacheToDisk() {
        do {
            // Ensure directory exists
            let directory = cacheFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            let data = try JSONEncoder().encode(cache)
            try data.write(to: cacheFileURL, options: .atomic)
            print("StationArtworkLoader: Saved \(cache.count) stations to cache")
        } catch {
            print("StationArtworkLoader: Failed to save cache: \(error)")
        }
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
        
        // Ignore notifications we posted ourselves (from cache restoration)
        // These are marked with "cache" as the object
        if let obj = notification.object as? String, obj == "cache" {
            return
        }
        
        // Find the station by name
        guard let stations = pandora?.stations as? [Station],
              let station = stations.first(where: { $0.name == stationName }) else {
            return
        }
        
        let stationId = station.stationId ?? ""
        var artUrl: String?
        var genres: [String] = []
        
        // Update the station's artUrl from the notification
        if let art = userInfo["art"] as? String {
            station.artUrl = art
            artUrl = art
        }
        
        // Update genres if available
        if let g = userInfo["genres"] as? [String] {
            station.genres = g
            genres = g
        }
        
        // Cache the result
        cache[stationId] = CachedStationInfo(
            artUrl: artUrl,
            genres: genres
        )
        saveCacheToDisk()
        
        // Mark as loaded and clean up
        pendingRequests.remove(stationId)
        stationNameToId.removeValue(forKey: stationName)
        loadedStations.insert(stationId)
        
        // Trigger UI refresh
        artworkUpdateTrigger = UUID()
    }
}
