//
//  LastFMService.swift
//  Hermes
//
//  Modern Last.fm scrobbling service with async/await
//  Replaces Scrobbler.{h,m}
//

import Foundation
import AppKit

// MARK: - Scrobble State

/// Represents the playback state for scrobbling
enum ScrobbleState {
    case newSong
    case nowPlaying
    case finalStatus
}

// MARK: - Last.fm Service

/// Modern Last.fm API client with async/await
@MainActor
final class LastFMService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LastFMService()
    
    // MARK: - Constants
    
    private let apiKey = "31fc44bcd6e21954afb404d179a09e9a"
    private let secretKey = "a146429ed54f25b8bf9d5ca3cc423260"
    private let baseURL = "https://ws.audioscrobbler.com/2.0/"
    private let keychainItem = "hermes-lastfm-sk"
    
    // MARK: - Properties
    
    private var sessionToken: String?
    private var requestToken: String?
    private var inAuthorization = false
    
    // MARK: - Initialization
    
    private init() {
        // Load session token from keychain
        sessionToken = KeychainManager.objcShared.getPassword(keychainItem)
        if sessionToken?.isEmpty == true {
            sessionToken = nil
        }
        
        // Setup notification observers
        setupNotificationObservers()
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
        guard let station = notification.object as? NSObject,
              let playing = station.value(forKey: "playingSong") as? NSObject else {
            return
        }
        
        Task {
            await scrobble(playing, state: .newSong)
        }
    }
    
    @objc private func songRated(_ notification: Notification) {
        guard let song = notification.object as? NSObject else {
            return
        }
        
        if let nrating = song.value(forKey: "nrating") as? NSNumber {
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
    func scrobble(_ song: NSObject, state: ScrobbleState) async {
        let settings = SettingsManager.shared
        
        // Check if scrobbling is enabled
        guard settings.enableScrobbling else { return }
        
        // Check if we should only scrobble liked songs
        if settings.onlyScrobbleLiked {
            guard let nrating = song.value(forKey: "nrating") as? NSNumber,
                  nrating.intValue == 1 else {
                return
            }
        }
        
        // Ensure we have a session token
        guard let sessionToken = sessionToken else {
            await fetchSessionToken()
            return
        }
        
        // Extract song properties
        guard let title = song.value(forKey: "title") as? String,
              let artist = song.value(forKey: "artist") as? String,
              let album = song.value(forKey: "album") as? String else {
            return
        }
        
        var parameters: [String: String] = [
            "sk": sessionToken,
            "api_key": apiKey,
            "track": title,
            "artist": artist,
            "album": album,
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
    func setPreference(_ song: NSObject, loved: Bool) async {
        let settings = SettingsManager.shared
        
        guard settings.enableScrobbling && settings.scrobbleLikes else { return }
        
        guard let sessionToken = sessionToken else {
            await fetchSessionToken()
            return
        }
        
        guard let title = song.value(forKey: "title") as? String,
              let artist = song.value(forKey: "artist") as? String else {
            return
        }
        
        let parameters: [String: String] = [
            "sk": sessionToken,
            "api_key": apiKey,
            "track": title,
            "artist": artist
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
                sessionToken = key
                _ = KeychainManager.objcShared.setItem(keychainItem, password: key)
            } else if let errorCode = response["error"] as? Int {
                if errorCode == 14 { // Unauthorized token
                    await fetchRequestToken()
                } else if let message = response["message"] as? String {
                    await showError(message)
                }
                sessionToken = nil
            }
        } catch {
            print("LastFMService: Failed to fetch session token: \(error)")
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
                sessionToken = nil
                await fetchRequestToken()
            }
            throw LastFMError.apiError(code: errorCode, message: json["message"] as? String ?? "Unknown error")
        }
        
        return json
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

import CommonCrypto

extension String {
    func md5sum() -> String {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        
        data.withUnsafeBytes { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    func urlEncoded() -> String {
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-._~")
        return self.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? self
    }
}
