//
//  PandoraNetwork.swift
//  Hermes
//
//  Network layer and request infrastructure extracted from PandoraClient
//

import Foundation

// MARK: - PandoraNetwork

/// Handles Pandora API network requests and infrastructure
extension PandoraClient {
    
    // MARK: - Request Infrastructure
    
    /// Create default request dictionary with auth token and sync time
    internal func defaultRequestDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let token = userAuthToken {
            dict["userAuthToken"] = token
        }
        dict["syncTime"] = syncTimeNumber
        return dict
    }
    
    /// Create a default request with the specified method
    internal func defaultRequest(method: String) -> PandoraRequest {
        let request = PandoraRequest()
        request.userId = userId ?? ""
        request.authToken = userAuthToken ?? ""
        request.method = method
        request.partnerId = partnerId ?? ""
        return request
    }
    
    /// Send a request that requires authentication
    internal func sendAuthenticatedRequest(_ request: PandoraRequest) -> Bool {
        if isAuthenticated() {
            return sendRequest(request)
        }
        
        // Get saved credentials and re-authenticate
        let user = UserDefaults.standard.string(forKey: UserDefaultsKeys.username)
        let pass = user.flatMap { try? KeychainManager.shared.retrievePassword(username: $0) }
        
        return authenticate(user, password: pass, request: request)
    }
    
    /// Send a request to the Pandora API
    @discardableResult
    func sendRequest(_ request: PandoraRequest) -> Bool {
        guard let deviceDict = device,
              let apiHost = deviceDict["apihost"] as? String else {
            return false
        }
        
        // Build URL
        let scheme = request.tls ? "https" : "http"
        let authToken = request.authToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(scheme)://\(apiHost)\(pandoraAPIPath)?method=\(request.method)&partner_id=\(request.partnerId)&auth_token=\(authToken)&user_id=\(request.userId)"
        
        NSLog("\(urlString)")
        
        guard let url = URL(string: urlString) else { return false }
        
        // Prepare the request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the body
        guard let jsonData = try? JSONSerialization.data(withJSONObject: request.request, options: []) else {
            return false
        }
        
        if request.encrypted {
            guard let encryptedData = encryptData(jsonData) else { return false }
            urlRequest.httpBody = encryptedData
        } else {
            urlRequest.httpBody = jsonData
        }
        
        // Perform the request
        httpClient.performRequest(urlRequest) { [weak self] data, error in
            guard let self = self else { return }
            
            var dict: [String: Any]?
            var errorMessage: String?
            var pandoraCode: Int?
            
            // Parse the JSON if we don't have an error
            if let data = data, error == nil {
                dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } else if let error = error {
                errorMessage = error.localizedDescription
            }
            
            // Check for API error in response
            if errorMessage == nil, let dict = dict {
                if let stat = dict["stat"] as? String, stat == "fail" {
                    errorMessage = dict["message"] as? String
                    pandoraCode = dict["code"] as? Int
                }
            }
            
            // If no error, invoke the callback
            if errorMessage == nil, let dict = dict {
                self.retries = 0 // Reset retry counter on success
                request.callback?(dict)
                return
            }
            
            // Check for auth token expiration - automatically re-authenticate and retry
            if let code = pandoraCode {
                if (code == invalidAuthToken || code == invalidSyncTime) && self.retries < 3 {
                    self.retries += 1
                    NSLog("Auth token expired (code \(code)), re-authenticating (attempt \(self.retries))...")
                    
                    // Clear auth state to force re-authentication
                    self.logoutNoNotify()
                    
                    // Get saved credentials and re-authenticate with the original request
                    let user = UserDefaults.standard.string(forKey: UserDefaultsKeys.username)
                    let pass = user.flatMap { try? KeychainManager.shared.retrievePassword(username: $0) }
                    
                    if let user = user, let pass = pass {
                        _ = self.authenticate(user, password: pass, request: request)
                        return
                    }
                }
            }
            
            // Build the error dictionary and post notification
            var info: [String: Any] = ["request": request]
            info["err"] = errorMessage ?? "Unknown error"
            
            if let error = error {
                let nsError = error as NSError
                if nsError.code != 0 {
                    info["nsErrorCode"] = nsError.code
                }
            } else if let code = pandoraCode {
                info["code"] = code
            }
            
            self.postNotification("PandoraDidErrorNotification", object: self, userInfo: info)
        }
        
        return true
    }
    
    // MARK: - Search
    
    /// Search for songs and artists
    func search(_ searchQuery: String!) -> Bool {
        guard let searchQuery = searchQuery else { return false }
        
        NSLog("Searching for \(searchQuery)...")
        
        let trimmedSearch = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearch.isEmpty {
            postNotification("PandoraDidLoadSearchResultsNotification", object: searchQuery, userInfo: [:])
            return true
        }
        
        var dict = defaultRequestDictionary()
        dict["searchText"] = trimmedSearch
        
        let request = defaultRequest(method: "music.search")
        request.request = dict
        request.tls = false
        
        request.callback = { [weak self] d in
            guard let self = self,
                  let result = d["result"] as? [String: Any] else { return }
            
            NSLog("\(result)")
            
            var searchSongs: [PandoraSearchResult] = []
            var searchArtists: [PandoraSearchResult] = []
            
            // Parse songs
            if let songs = result["songs"] as? [[String: Any]] {
                for s in songs {
                    let r = PandoraSearchResult()
                    let songName = s["songName"] as? String ?? ""
                    let artistName = s["artistName"] as? String ?? ""
                    r.name = "\(songName) - \(artistName)"
                    r.value = s["musicToken"] as? String ?? ""
                    searchSongs.append(r)
                }
            }
            
            // Parse artists
            if let artists = result["artists"] as? [[String: Any]] {
                for a in artists {
                    let r = PandoraSearchResult()
                    r.name = a["artistName"] as? String ?? ""
                    r.value = a["musicToken"] as? String ?? ""
                    searchArtists.append(r)
                }
            }
            
            let searchResults: [String: Any] = [
                "Songs": searchSongs,
                "Artists": searchArtists
            ]
            
            self.postNotification("PandoraDidLoadSearchResultsNotification", object: searchQuery, userInfo: searchResults)
        }
        
        return sendAuthenticatedRequest(request)
    }
    
    // MARK: - Async/Await Search
    
    /// Search for music using async/await
    /// - Parameter query: Search query
    /// - Returns: Dictionary with "Songs" and "Artists" arrays of PandoraSearchResult
    /// - Throws: PandoraError on failure
    func searchAsync(_ query: String) async throws -> [String: [PandoraSearchResult]] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: [PandoraSearchResult]], Error>) in
            // Use a class box so mutable observer references are Sendable-safe
            final class ObserverBox: @unchecked Sendable {
                var observer: NSObjectProtocol?
                var errorObserver: NSObjectProtocol?
            }
            let box = ObserverBox()
            
            box.observer = NotificationCenter.default.addObserver(
                forName: .pandoraDidLoadSearchResults,
                object: nil,
                queue: .main
            ) { notification in
                if let obs = box.observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = box.errorObserver { NotificationCenter.default.removeObserver(obs) }
                
                var results: [String: [PandoraSearchResult]] = [:]
                if let songs = notification.userInfo?["Songs"] as? [PandoraSearchResult] {
                    results["Songs"] = songs
                }
                if let artists = notification.userInfo?["Artists"] as? [PandoraSearchResult] {
                    results["Artists"] = artists
                }
                continuation.resume(returning: results)
            }
            
            box.errorObserver = NotificationCenter.default.addObserver(
                forName: .pandoraDidError,
                object: nil,
                queue: .main
            ) { notification in
                if let obs = box.observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = box.errorObserver { NotificationCenter.default.removeObserver(obs) }
                
                let errorMessage = notification.userInfo?["err"] as? String ?? "Search failed"
                continuation.resume(throwing: PandoraError.apiError(code: 0, message: errorMessage))
            }
            
            if !self.search(query) {
                if let obs = box.observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = box.errorObserver { NotificationCenter.default.removeObserver(obs) }
                continuation.resume(throwing: PandoraError.notAuthenticated)
            }
        }
    }
}
