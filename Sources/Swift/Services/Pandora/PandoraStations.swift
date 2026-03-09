//
//  PandoraStations.swift
//  Hermes
//
//  Station management functionality extracted from PandoraClient
//

import Foundation

// MARK: - PandoraStations

/// Handles Pandora station management operations
extension PandoraClient {
    
    // MARK: - Station Management
    
    /// Fetch all stations for the authenticated user
    func fetchStations() -> Bool {
        NSLog("Fetching stations...")
        
        let request = defaultRequest(method: "user.getStationList")
        request.request = defaultRequestDictionary()
        request.tls = false
        
        request.callback = { [weak self] dict in
            guard let self = self,
                  let result = dict["result"] as? [String: Any],
                  let stationsArray = result["stations"] as? [[String: Any]] else { return }
            
            for stationDict in stationsArray {
                let station = self.parseStation(from: stationDict)
                if !self._stations.contains(where: { $0.token == station.token }) {
                    self._stations.append(station)
                    Station.addStation(station)
                }
            }
            
            self.postNotification("PandoraDidLoadStationsNotification")
        }
        
        return sendAuthenticatedRequest(request)
    }
    
    /// Create a new station from a music token
    func createStation(_ musicId: String!) -> Bool {
        guard let musicId = musicId else { return false }
        
        var dict = defaultRequestDictionary()
        dict["musicToken"] = musicId
        
        let request = defaultRequest(method: "station.createStation")
        request.request = dict
        request.tls = false
        
        request.callback = { [weak self] d in
            guard let self = self,
                  let result = d["result"] as? [String: Any] else { return }
            
            let station = self.parseStation(from: result)
            self._stations.append(station)
            Station.addStation(station)
            
            self.postNotification("PandoraDidCreateStationNotification", userInfo: ["station": station])
        }
        
        return sendAuthenticatedRequest(request)
    }
    
    /// Remove a station
    func removeStation(_ stationToken: String!) -> Bool {
        guard let stationToken = stationToken else { return false }
        
        var dict = defaultRequestDictionary()
        dict["stationToken"] = stationToken
        
        let request = defaultRequest(method: "station.deleteStation")
        request.request = dict
        request.tls = false
        
        request.callback = { [weak self] _ in
            guard let self = self else { return }
            
            if let index = self._stations.firstIndex(where: { $0.token == stationToken }) {
                let stationToRemove = self._stations[index]
                Station.removeStation(stationToRemove)
                self._stations.remove(at: index)
                self.postNotification("PandoraDidDeleteStationNotification", object: stationToRemove)
            } else {
                NSLog("Deleted unknown station?!")
            }
        }
        
        return sendAuthenticatedRequest(request)
    }
    
    /// Rename a station
    func renameStation(_ stationToken: String!, to name: String!) -> Bool {
        guard let stationToken = stationToken, let name = name else { return false }
        
        var dict = defaultRequestDictionary()
        dict["stationToken"] = stationToken
        dict["stationName"] = name
        
        let request = defaultRequest(method: "station.renameStation")
        request.request = dict
        request.tls = false
        
        request.callback = { [weak self] _ in
            self?.postNotification("PandoraDidRenameStationNotification")
        }
        
        return sendAuthenticatedRequest(request)
    }
    
    /// Fetch detailed station info
    func fetchStationInfo(_ station: Station!) -> Bool {
        guard let station = station else { return false }
        
        var dict = defaultRequestDictionary()
        dict["stationToken"] = station.token
        dict["includeExtendedAttributes"] = true
        
        let request = defaultRequest(method: "station.getStation")
        request.request = dict
        request.tls = false
        
        request.callback = { [weak self] d in
            guard let self = self,
                  let result = d["result"] as? [String: Any] else { return }
            
            var info: [String: Any] = [:]
            
            // General metadata
            info["name"] = result["stationName"]
            
            // Parse creation date
            if let dateCreated = result["dateCreated"] as? [String: Any] {
                var components = DateComponents()
                components.year = 2000 + ((dateCreated["year"] as? Int) ?? 0)
                components.month = 1 + ((dateCreated["month"] as? Int) ?? 0)
                components.day = (dateCreated["date"] as? Int) ?? 1
                
                let calendar = Calendar(identifier: .gregorian)
                info["created"] = calendar.date(from: components)
            }
            
            if let art = result["artUrl"] as? String {
                info["art"] = art
            }
            
            // Parse genres
            if let genreData = result["genre"] {
                if let genreArray = genreData as? [String] {
                    info["genres"] = genreArray
                } else if let genreString = genreData as? String {
                    info["genres"] = [genreString]
                }
            }
            
            info["url"] = result["stationDetailUrl"]
            
            // Seeds
            var seeds: [String: Any] = [:]
            if let music = result["music"] as? [String: Any] {
                for kind in ["songs", "artists"] {
                    if let seedsOfKind = music[kind] as? [[String: Any]], !seedsOfKind.isEmpty {
                        seeds[kind] = seedsOfKind
                    }
                }
            }
            info["seeds"] = seeds
            
            // Feedback
            if let feedback = result["feedback"] as? [String: Any] {
                info["likes"] = feedback["thumbsUp"]
                info["dislikes"] = feedback["thumbsDown"]
            }
            
            self.postNotification("PandoraDidLoadStationInfoNotification", userInfo: info)
        }
        
        return sendAuthenticatedRequest(request)
    }
    
    /// Fetch genre stations
    func fetchGenreStations() -> Bool {
        let request = defaultRequest(method: "station.getGenreStations")
        request.request = defaultRequestDictionary()
        request.tls = false
        
        request.callback = { [weak self] d in
            guard let result = d["result"] as? [String: Any] else { return }
            self?.postNotification("PandoraDidLoadGenreStationsNotification", userInfo: result)
        }
        
        return sendAuthenticatedRequest(request)
    }
    
    /// Sort stations by the specified order
    func sortStations(_ sort: Int) {
        _stations.sort { s1, s2 in
            // Keep Shuffle/QuickMix at the top of the list
            if s1.isQuickMix { return true }
            if s2.isQuickMix { return false }
            
            let sortOrder = StationSortOrder(rawValue: sort) ?? .nameAscending
            let ascending = (sortOrder == .nameAscending || sortOrder == .dateAscending)
            
            switch sortOrder {
            case .nameAscending, .nameDescending:
                let comparison = s1.name.localizedCaseInsensitiveCompare(s2.name)
                return ascending ? (comparison == .orderedAscending) : (comparison == .orderedDescending)
                
            case .dateAscending, .dateDescending:
                if s1.created < s2.created {
                    return ascending
                } else if s1.created > s2.created {
                    return !ascending
                }
                return false
            }
        }
    }
    
    /// Parse a station from API response dictionary
    internal func parseStation(from dict: [String: Any]) -> Station {
        let station = Station()
        
        station.name = dict["stationName"] as? String ?? ""
        station.stationId = dict["stationId"] as? String ?? ""
        station.token = dict["stationToken"] as? String ?? ""
        station.shared = (dict["isShared"] as? Bool) ?? false
        station.allowAddMusic = (dict["allowAddMusic"] as? Bool) ?? false
        station.allowRename = (dict["allowRename"] as? Bool) ?? false
        
        if let dateCreatedDict = dict["dateCreated"] as? [String: Any],
           let time = dateCreatedDict["time"] as? UInt64 {
            station.created = time
        }
        
        station.setRadio(self)
        
        // Extract artwork URL if available
        if let artUrl = dict["artUrl"] as? String {
            station.artUrl = artUrl
        }
        
        // Extract genres
        if let genreData = dict["genre"] {
            if let genreArray = genreData as? [String] {
                station.genres = genreArray
            } else if let genreString = genreData as? String {
                station.genres = [genreString]
            }
        }
        
        // Handle QuickMix/Shuffle station
        if (dict["isQuickMix"] as? Bool) == true {
            station.name = "🔀 Shuffle"
            station.isQuickMix = true
        }
        
        return station
    }
    
    // MARK: - Async/Await Station Operations
    
    /// Fetch stations using async/await
    /// - Returns: Array of stations
    /// - Throws: PandoraError on failure
    func fetchStationsAsync() async throws -> [Station] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Station], Error>) in
            let bridge = NotificationContinuation<[Station]>()
            
            bridge.observe(
                success: .pandoraDidLoadStations,
                error: .pandoraDidError,
                continuation: continuation,
                onSuccess: { [weak self] _ in
                    self?._stations ?? []
                },
                onError: { notification in
                    let errorMessage = notification.userInfo?["err"] as? String ?? "Failed to fetch stations"
                    return PandoraError.apiError(code: 0, message: errorMessage) as Error
                }
            )
            
            if !self.fetchStations() {
                bridge.cancel(continuation: continuation, error: PandoraError.notAuthenticated)
            }
        }
    }
    
    /// Create a station using async/await
    /// - Parameter musicId: Music token from search results
    /// - Returns: The created station
    /// - Throws: PandoraError on failure
    func createStationAsync(_ musicId: String) async throws -> Station {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Station, Error>) in
            let bridge = NotificationContinuation<Station>()
            
            bridge.observe(
                success: .pandoraDidCreateStation,
                error: .pandoraDidError,
                continuation: continuation,
                onSuccess: { notification in
                    if let station = notification.userInfo?["station"] as? Station {
                        return station
                    }
                    // This shouldn't happen, but handle gracefully
                    fatalError("pandoraDidCreateStation fired without a station in userInfo")
                },
                onError: { notification in
                    let errorMessage = notification.userInfo?["err"] as? String ?? "Failed to create station"
                    return PandoraError.apiError(code: 0, message: errorMessage)
                }
            )
            
            if !self.createStation(musicId) {
                bridge.cancel(continuation: continuation, error: PandoraError.notAuthenticated)
            }
        }
    }
}
