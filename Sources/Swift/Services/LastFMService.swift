//
//  LastFMService.swift
//  Hermes
//
//  Modern Last.fm scrobbling service with async/await
//  Replaces Scrobbler.{h,m}
//

import Foundation
import AppKit
import Combine
import CryptoSwift

// MARK: - Scrobble State

/// Represents the playback state for scrobbling
enum ScrobbleState {
    case newSong
    case nowPlaying
    case finalStatus
}

enum LastFMCredentialAvailability: Equatable {
    case checking
    case available
    case absent
    case temporarilyUnavailable
    case failed(String)
}

// MARK: - Last.fm Service

/// Modern Last.fm API client with async/await
@MainActor
final class LastFMService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LastFMService(credentialStore: KeychainManager.shared)
    
    // MARK: - Constants
    
    private let apiKey = "31fc44bcd6e21954afb404d179a09e9a"
    private let secretKey = "a146429ed54f25b8bf9d5ca3cc423260"
    private let baseURL = "https://ws.audioscrobbler.com/2.0/"
    private let keychainItem = "hermes-lastfm-sk"
    
    // MARK: - Properties
    
    private var sessionToken: String?
    private var requestToken: String?
    private var inAuthorization = false
    private let credentialStore: any CredentialStore
    @Published private(set) var credentialAvailability: LastFMCredentialAvailability = .checking
    @Published private(set) var credentialPersistenceError: String?
    private var credentialRestorationGeneration: UInt64 = 0

    var canAutomaticallyAuthorizeMissingSession: Bool {
        credentialAvailability == .absent
    }
    
    // MARK: - Initialization
    
    init(credentialStore: any CredentialStore) {
        self.credentialStore = credentialStore
        setupNotificationObservers()
        credentialRestorationGeneration &+= 1
        let generation = credentialRestorationGeneration
        Task {
            await restoreSessionToken(generation: generation)
        }
    }

    private func restoreSessionToken(generation: UInt64) async {
        do {
            let result = try await credentialStore.retrievePassword(username: keychainItem)
            guard credentialRestorationGeneration == generation else {
                return
            }
            switch result {
            case .found(let token) where !token.isEmpty:
                sessionToken = token
                credentialAvailability = .available
            case .found:
                sessionToken = nil
                credentialAvailability = .failed(
                    CredentialStoreError.decodingError.localizedDescription
                )
            case .absent:
                sessionToken = nil
                credentialAvailability = .absent
            case .temporarilyUnavailable:
                sessionToken = nil
                credentialAvailability = .temporarilyUnavailable
            }
        } catch {
            guard credentialRestorationGeneration == generation else {
                return
            }
            credentialAvailability = .failed(error.localizedDescription)
            print("LastFMService: Failed to restore session token: \(error)")
        }
    }

    func retryCredentialRestoration() {
        credentialRestorationGeneration &+= 1
        let generation = credentialRestorationGeneration
        credentialAvailability = .checking
        credentialPersistenceError = nil
        Task {
            await restoreSessionToken(generation: generation)
        }
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(songPlayed(_:)),
            name: NSNotification.Name("StationDidPlaySongNotification"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(songRated(_:)),
            name: NSNotification.Name("PandoraDidRateSongNotification"),
            object: nil
        )
    }
    
    @objc private func songPlayed(_ notification: Notification) {
        guard let station = notification.object as? Station,
              let playing = station.playingSong else {
            return
        }
        
        Task {
            await scrobble(playing, state: .newSong)
        }
    }
    
    @objc private func songRated(_ notification: Notification) {
        guard let song = notification.object as? Song else {
            return
        }
        
        if let nrating = song.nrating {
            let loved = nrating.intValue == 1
            Task {
                await setPreference(song, loved: loved)
            }
        }
    }
    
    // MARK: - Public API
    
    /// Scrobble a song to Last.fm
    /// - Parameters:
    ///   - song: The song to scrobble
    ///   - state: The playback state
    func scrobble(_ song: Song, state: ScrobbleState) async {
        let settings = SettingsManager.shared
        
        // Check if scrobbling is enabled
        guard settings.enableScrobbling else { return }
        
        // Check if we should only scrobble liked songs
        if settings.onlyScrobbleLiked {
            guard let nrating = song.nrating,
                  nrating.intValue == 1 else {
                return
            }
        }
        
        // Ensure we have a session token
        guard let sessionToken = sessionToken else {
            guard canAutomaticallyAuthorizeMissingSession else {
                return
            }
            await fetchSessionToken()
            return
        }
        
        var parameters: [String: String] = [
            "sk": sessionToken,
            "api_key": apiKey,
            "track": song.title,
            "artist": song.artist,
            "album": song.album,
            "chosenByUser": "0"
        ]
        
        let timestamp = String(Int(Date().timeIntervalSince1970))
        parameters["timestamp"] = timestamp
        
        let method = state == .finalStatus ? "track.scrobble" : "track.updateNowPlaying"
        
        do {
            _ = try await performMethod(method, parameters: parameters, useSignature: true, httpMethod: "POST")
        } catch {
            // Silently fail - scrobbling is not mission critical
            print("LastFMService: Scrobble failed: \(error)")
        }
    }
    
    /// Set track preference (love/unlove)
    /// - Parameters:
    ///   - song: The song to love/unlove
    ///   - loved: Whether the song should be loved
    func setPreference(_ song: Song, loved: Bool) async {
        let settings = SettingsManager.shared
        
        guard settings.enableScrobbling && settings.scrobbleLikes else { return }
        
        guard let sessionToken = sessionToken else {
            guard canAutomaticallyAuthorizeMissingSession else {
                return
            }
            await fetchRequestToken()
            return
        }
        
        let parameters: [String: String] = [
            "sk": sessionToken,
            "api_key": apiKey,
            "track": song.title,
            "artist": song.artist
        ]
        
        let method = loved ? "track.love" : "track.unlove"
        
        do {
            _ = try await performMethod(method, parameters: parameters, useSignature: true, httpMethod: "POST")
        } catch {
            print("LastFMService: Set preference failed: \(error)")
        }
    }
    
    // MARK: - Authentication
    
    /// Fetch a session token for the logged-in user
    private func fetchSessionToken() async {
        guard !inAuthorization else { return }
        
        if requestToken == nil {
            await fetchRequestToken()
            return
        }
        
        print("LastFMService: Fetching session token...")
        
        let parameters: [String: String] = [
            "api_key": apiKey,
            "token": requestToken!
        ]
        
        requestToken = nil // Can only be used once
        
        do {
            let response = try await performMethod("auth.getSession", parameters: parameters, useSignature: true, httpMethod: "GET")
            
            if let session = response["session"] as? [String: Any],
               let key = session["key"] as? String {
                let generation = adoptSessionToken(key)
                await persistSessionToken(key, generation: generation)
            } else if let errorCode = response["error"] as? Int {
                invalidateCredentialRestoration()
                sessionToken = nil
                credentialAvailability = .absent
                if errorCode == 14 { // Unauthorized token
                    await fetchRequestToken()
                } else if let message = response["message"] as? String {
                    await showError(message)
                }
            }
        } catch {
            print("LastFMService: Failed to fetch session token: \(error)")
        }
    }

    func persistSessionToken(_ token: String) async {
        let generation = adoptSessionToken(token)
        await persistSessionToken(token, generation: generation)
    }

    private func persistSessionToken(_ token: String, generation: UInt64) async {
        do {
            try await credentialStore.saveCredentials(username: keychainItem, password: token)
            guard credentialRestorationGeneration == generation,
                  sessionToken == token else {
                return
            }
            credentialPersistenceError = nil
            credentialAvailability = .available
        } catch {
            guard credentialRestorationGeneration == generation,
                  sessionToken == token else {
                return
            }
            credentialPersistenceError = error.localizedDescription
            print("LastFMService: Failed to save session token: \(error)")
        }
    }
    
    /// Fetch an unauthorized request token
    private func fetchRequestToken() async {
        guard !inAuthorization else { return }
        
        inAuthorization = true
        
        let parameters: [String: String] = [
            "api_key": apiKey
        ]
        
        do {
            let response = try await performMethod("auth.getToken", parameters: parameters, useSignature: true, httpMethod: "GET")
            
            if let token = response["token"] as? String, !token.isEmpty {
                requestToken = token
                await requestAuthorization()
            } else {
                await showError("Couldn't get an authentication request token from Last.fm!")
                inAuthorization = false
            }
        } catch {
            await showError("Failed to fetch request token: \(error.localizedDescription)")
            inAuthorization = false
        }
    }
    
    /// Request user authorization
    private func requestAuthorization() async {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Allow Hermes to scrobble on Last.fm", comment: "Last.fm authorization alert title")
        alert.informativeText = "Click \"Authorize\" to give Hermes permission to access your Last.fm account.\n\nHermes will not try to use Last.fm for at least 30 seconds to give you time to grant permission.\n\nClick \"Don't Scrobble\" to stop Hermes from trying to use Last.fm."
        alert.addButton(withTitle: NSLocalizedString("Authorize", comment: "Authorize button"))
        alert.addButton(withTitle: NSLocalizedString("Don't Scrobble", comment: "Don't Scrobble button"))
        
        let response = await alert.beginSheetModal(for: NSApp.keyWindow!)
        
        if response != .alertFirstButtonReturn {
            SettingsManager.shared.enableScrobbling = false
            inAuthorization = false
            return
        }
        
        // Open authorization URL
        if let token = requestToken {
            let authURL = "http://www.last.fm/api/auth/?api_key=\(apiKey)&token=\(token)"
            if let url = URL(string: authURL) {
                NSWorkspace.shared.open(url)
            }
        }
        
        // Wait 30 seconds for user to authorize
        try? await Task.sleep(nanoseconds: 30_000_000_000)
        inAuthorization = false
        await fetchSessionToken()
    }
    
    // MARK: - API Methods
    
    /// Perform a Last.fm API method call
    private func performMethod(_ method: String, parameters: [String: String], useSignature: Bool, httpMethod: String) async throws -> [String: Any] {
        var params = parameters
        params["method"] = method
        
        if useSignature {
            let signature = generateSignature(from: params)
            params["api_sig"] = signature
        }
        
        if httpMethod != "POST" {
            params["format"] = "json"
        }
        
        let request: URLRequest
        
        if httpMethod == "POST" {
            var urlComponents = URLComponents(string: baseURL)!
            urlComponents.queryItems = [URLQueryItem(name: "format", value: "json")]
            
            var urlRequest = URLRequest(url: urlComponents.url!)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = generatePOSTBody(from: params).data(using: .utf8)
            request = urlRequest
        } else {
            let url = generateURL(from: params)
            request = URLRequest(url: url)
        }
        
        let client = HTTPClient()
        let data = try await client.performRequest(request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LastFMError.invalidResponse
        }
        
        // Check for Last.fm errors
        if let errorCode = json["error"] as? Int {
            if errorCode == 9 { // Invalid session key
                invalidateCredentialRestoration()
                sessionToken = nil
                credentialAvailability = .absent
                await fetchRequestToken()
            }
            throw LastFMError.apiError(code: errorCode, message: json["message"] as? String ?? "Unknown error")
        }
        
        return json
    }

    private func invalidateCredentialRestoration() {
        credentialRestorationGeneration &+= 1
    }

    private func adoptSessionToken(_ token: String) -> UInt64 {
        invalidateCredentialRestoration()
        sessionToken = token
        credentialAvailability = .available
        credentialPersistenceError = nil
        return credentialRestorationGeneration
    }
    
    // MARK: - Helper Methods
    
    private func generateSignature(from parameters: [String: String]) -> String {
        let sortedKeys = parameters.keys.sorted()
        var rawSignature = ""
        
        for key in sortedKeys {
            rawSignature += "\(key)\(parameters[key] ?? "")"
        }
        
        rawSignature += secretKey
        return rawSignature.md5sum()
    }
    
    private func generatePOSTBody(from parameters: [String: String]) -> String {
        let sortedKeys = parameters.keys.sorted()
        var body = ""
        
        for key in sortedKeys {
            if let value = parameters[key]?.urlEncoded() {
                body += "&\(key)=\(value)"
            }
        }
        
        return body
    }
    
    private func generateURL(from parameters: [String: String]) -> URL {
        var components = URLComponents(string: baseURL)!
        components.queryItems = parameters.keys.sorted().map { key in
            URLQueryItem(name: key, value: parameters[key])
        }
        return components.url!
    }
    
    private func showError(_ message: String) async {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Last.fm returned an error", comment: "Last.fm error alert title")
        alert.informativeText = message
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK button"))
        
        if let window = NSApp.keyWindow {
            await alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}

// MARK: - Last.fm Error

enum LastFMError: Error, LocalizedError {
    case invalidResponse
    case apiError(code: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Last.fm"
        case .apiError(let code, let message):
            return "Last.fm error \(code): \(message)"
        }
    }
}

// MARK: - String Extensions

extension String {
    /// Calculate MD5 hash using CryptoSwift
    func md5sum() -> String {
        return self.md5()
    }
    
    func urlEncoded() -> String {
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-._~")
        return self.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? self
    }
}
