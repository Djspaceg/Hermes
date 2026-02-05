//
//  PandoraPlayback.swift
//  Hermes
//
//  Playback and song operations extracted from PandoraClient
//

import Foundation

// MARK: - PandoraPlayback

/// Handles Pandora playback and song operations
extension PandoraClient {
    
    // MARK: - Playback
    
    /// Fetch playlist for a station
    @objc(fetchPlaylistForStation:)
    func fetchPlaylist(for station: Station!) -> Bool {
        guard let station = station else { return false }
        
        var dict = defaultRequestDictionary()
        dict["stationToken"] = station.token
        dict["additionalAudioUrl"] = "HTTP_32_AACPLUS_ADTS,HTTP_64_AACPLUS_ADTS,HTTP_128_MP3"
        
        let request = defaultRequest(method: "station.getPlaylist")
        request.request = dict
        
        request.callback = { [weak self] d in
            guard let self = self else { return }
            
            guard let result = d["result"] as? [String: Any] else {
                NSLog("fetchPlaylist ERROR: No result in response for '\(station.name)'")
                return
            }
            
            // Try both "items" and "tracks" keys (API may use either)
            let items: [[String: Any]]
            if let itemsArray = result["items"] as? [[String: Any]] {
                items = itemsArray
            } else if let tracksArray = result["tracks"] as? [[String: Any]] {
                items = tracksArray
            } else {
                NSLog("fetchPlaylist ERROR: No items or tracks array for '\(station.name)'")
                return
            }
            
            var songs: [Song] = []
            
            for item in items {
                // Skip ad tokens
                if item["adToken"] != nil { continue }
                
                let song = Song()
                song.artist = item["artistName"] as? String ?? ""
                song.title = item["songName"] as? String ?? ""
                song.album = item["albumName"] as? String ?? ""
                song.art = item["albumArtUrl"] as? String
                song.stationId = item["stationId"] as? String
                song.token = item["trackToken"] as? String
                song.nrating = item["songRating"] as? NSNumber
                song.albumUrl = item["albumDetailUrl"] as? String
                song.artistUrl = item["artistDetailUrl"] as? String
                song.titleUrl = item["songDetailUrl"] as? String
                
                // Extract track gain for audio normalization
                if let trackGain = item["trackGain"] as? String {
                    song.trackGain = trackGain
                }
                
                // Extract allowFeedback flag (defaults to YES if not present)
                song.allowFeedback = (item["allowFeedback"] as? Bool) ?? true
                
                // Parse audio URLs from additionalAudioUrl array
                if let urls = item["additionalAudioUrl"] as? [String] {
                    switch urls.count {
                    case 3...:
                        song.highUrl = urls[2]
                        fallthrough
                    case 2:
                        song.medUrl = urls[1]
                        fallthrough
                    case 1:
                        song.lowUrl = urls[0]
                    default:
                        NSLog("Unexpected number of items for additionalAudioUrl: \(urls)")
                    }
                }
                
                // Parse audio URLs from audioUrlMap (higher quality for subscribers)
                if let audioUrlMap = item["audioUrlMap"] as? [String: Any] {
                    if let highQuality = audioUrlMap["highQuality"] as? [String: Any],
                       let audioUrl = highQuality["audioUrl"] as? String {
                        // Bitrate might be String or Int
                        let bitrate: Int
                        if let bitrateInt = highQuality["bitrate"] as? Int {
                            bitrate = bitrateInt
                        } else if let bitrateString = highQuality["bitrate"] as? String,
                                  let bitrateInt = Int(bitrateString) {
                            bitrate = bitrateInt
                        } else {
                            bitrate = 0
                        }
                        
                        // Always set highUrl if we have it
                        song.highUrl = audioUrl
                    }
                    if let mediumQuality = audioUrlMap["mediumQuality"] as? [String: Any],
                       let audioUrl = mediumQuality["audioUrl"] as? String {
                        song.medUrl = audioUrl
                    }
                    if let lowQuality = audioUrlMap["lowQuality"] as? [String: Any],
                       let audioUrl = lowQuality["audioUrl"] as? String {
                        song.lowUrl = audioUrl
                    }
                }
                
                // Fallback URL assignments
                if song.medUrl == nil { song.medUrl = song.lowUrl }
                if song.highUrl == nil { song.highUrl = song.medUrl }
                
                songs.append(song)
            }
            
            NSLog("fetchPlaylist: Parsed \(songs.count) songs for '\(station.name)'")
            
            if songs.isEmpty {
                NSLog("fetchPlaylist WARNING for '\(station.name)': No songs parsed from \(items.count) items")
            }
            
            let notificationName = "hermes.fragment-fetched.\(station.token ?? "")"
            self.postNotification(notificationName, userInfo: ["songs": songs])
        }
        
        return sendAuthenticatedRequest(request)
    }
    
    // MARK: - Song Operations
    
    /// Rate a song (like or dislike)
    func rateSong(_ song: Song!, as liked: Bool) -> Bool {
        guard let song = song else { return false }
        
        NSLog("Rating song '\(song.title)' as \(liked)...")
        
        // Update local rating immediately
        song.nrating = NSNumber(value: liked ? 1 : -1)
        
        var dict = defaultRequestDictionary()
        dict["trackToken"] = song.token
        dict["isPositive"] = liked
        dict["stationToken"] = song.station()?.token
        
        let request = defaultRequest(method: "station.addFeedback")
        request.request = dict
        request.tls = false
        
        request.callback = { [weak self] _ in
            self?.postNotification("PandoraDidRateSongNotification", object: song)
        }
        
        return sendAuthenticatedRequest(request)
    }
    
    /// Mark a song as "tired" (don't play for a while)
    @objc(tiredOfSong:)
    func tired(of song: Song!) -> Bool {
        guard let song = song else { return false }
        
        NSLog("Getting tired of \(song.title)...")
        
        var dict = defaultRequestDictionary()
        dict["trackToken"] = song.token
        
        let request = defaultRequest(method: "user.sleepSong")
        request.request = dict
        request.tls = false
        
        request.callback = { [weak self] _ in
            self?.postNotification("PandoraDidTireSongNotification", object: song)
        }
        
        return sendAuthenticatedRequest(request)
    }
    
    /// Delete a song's rating
    func deleteRating(_ song: Song!) -> Bool {
        guard let song = song else { return false }
        
        NSLog("Removing rating on '\(song.title)'")
        song.nrating = NSNumber(value: 0)
        
        var dict = defaultRequestDictionary()
        dict["stationToken"] = song.station()?.token
        dict["includeExtendedAttributes"] = true
        
        let request = defaultRequest(method: "station.getStation")
        request.request = dict
        request.tls = false
        
        request.callback = { [weak self] d in
            guard let self = self,
                  let result = d["result"] as? [String: Any],
                  let feedback = result["feedback"] as? [String: Any] else { return }
            
            for thumb in ["thumbsUp", "thumbsDown"] {
                if let feedbackList = feedback[thumb] as? [[String: Any]] {
                    for feed in feedbackList {
                        if let songName = feed["songName"] as? String,
                           songName == song.title,
                           let feedbackId = feed["feedbackId"] as? String {
                            _ = self.deleteFeedback(feedbackId)
                            break
                        }
                    }
                }
            }
        }
        
        return sendAuthenticatedRequest(request)
    }
    
    // MARK: - Seed Management
    
    /// Add a seed to a station
    @objc(addSeed:toStation:)
    func addSeed(_ token: String!, to station: Station!) -> Bool {
        guard let token = token, let station = station else { return false }
        
        var dict = defaultRequestDictionary()
        dict["musicToken"] = token
        dict["stationToken"] = station.token
        
        let request = defaultRequest(method: "station.addMusic")
        request.request = dict
        request.tls = false
        
        request.callback = { [weak self] d in
            guard let result = d["result"] as? [String: Any] else { return }
            self?.postNotification("PandoraDidAddSeedNotification", userInfo: result)
        }
        
        return sendAuthenticatedRequest(request)
    }
    
    /// Remove a seed from a station
    func removeSeed(_ seedId: String!) -> Bool {
        guard let seedId = seedId else { return false }
        
        var dict = defaultRequestDictionary()
        dict["seedId"] = seedId
        
        let request = defaultRequest(method: "station.deleteMusic")
        request.request = dict
        request.tls = false
        
        request.callback = { [weak self] _ in
            self?.postNotification("PandoraDidDeleteSeedNotification")
        }
        
        return sendAuthenticatedRequest(request)
    }
    
    /// Delete feedback (rating) from a station
    func deleteFeedback(_ feedbackId: String!) -> Bool {
        guard let feedbackId = feedbackId else { return false }
        
        NSLog("deleting feedback: '\(feedbackId)'")
        
        var dict = defaultRequestDictionary()
        dict["feedbackId"] = feedbackId
        
        let request = defaultRequest(method: "station.deleteFeedback")
        request.request = dict
        request.tls = false
        
        request.callback = { [weak self] _ in
            self?.postNotification("PandoraDidDeleteFeedbackNotification", object: feedbackId)
        }
        
        return sendAuthenticatedRequest(request)
    }
    
    // MARK: - Async/Await Playback Operations
    
    /// Fetch playlist for a station using async/await
    /// - Parameter station: The station to fetch playlist for
    /// - Returns: Array of songs
    /// - Throws: PandoraError on failure
    func fetchPlaylistAsync(for station: Station) async throws -> [Song] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Song], Error>) in
            var observer: NSObjectProtocol?
            var errorObserver: NSObjectProtocol?
            
            let notificationName = Notification.Name("hermes.fragment-fetched.\(station.token ?? "")")
            
            observer = NotificationCenter.default.addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { notification in
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                
                let songs = notification.userInfo?["songs"] as? [Song] ?? []
                continuation.resume(returning: songs)
            }
            
            errorObserver = NotificationCenter.default.addObserver(
                forName: .pandoraDidError,
                object: nil,
                queue: .main
            ) { notification in
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                
                let errorMessage = notification.userInfo?["err"] as? String ?? "Failed to fetch playlist"
                continuation.resume(throwing: PandoraError.apiError(code: 0, message: errorMessage))
            }
            
            if !self.fetchPlaylist(for: station) {
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                continuation.resume(throwing: PandoraError.notAuthenticated)
            }
        }
    }
    
    /// Rate a song using async/await
    /// - Parameters:
    ///   - song: The song to rate
    ///   - liked: true for thumbs up, false for thumbs down
    /// - Throws: PandoraError on failure
    func rateSongAsync(_ song: Song, liked: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var observer: NSObjectProtocol?
            var errorObserver: NSObjectProtocol?
            
            observer = NotificationCenter.default.addObserver(
                forName: .pandoraDidRateSong,
                object: nil,
                queue: .main
            ) { _ in
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                continuation.resume()
            }
            
            errorObserver = NotificationCenter.default.addObserver(
                forName: .pandoraDidError,
                object: nil,
                queue: .main
            ) { notification in
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                
                let errorMessage = notification.userInfo?["err"] as? String ?? "Failed to rate song"
                continuation.resume(throwing: PandoraError.apiError(code: 0, message: errorMessage))
            }
            
            if !self.rateSong(song, as: liked) {
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                continuation.resume(throwing: PandoraError.notAuthenticated)
            }
        }
    }
}
