//
//  PandoraClient.swift
//  Hermes
//
//  Modern Swift implementation of Pandora API client
//  Replaces Pandora.{h,m}
//

import Foundation

// MARK: - Constants

private let pandoraAPIPath = "/services/json/"
private let pandoraAPIVersion = "5"

// MARK: - Error Codes

private let invalidSyncTime = 13
private let invalidAuthToken = 1001
private let invalidPartnerLogin = 1002
private let invalidUsername = 1011
private let invalidPassword = 1012
private let noSeedsLeft = 1032

// MARK: - PandoraProtocol

/// Protocol defining the Pandora API interface
/// Used for dependency injection and testing
@objc protocol PandoraProtocol: AnyObject {
    /// Array of stations for the authenticated user
    var stations: [Any]? { get }
    
    /// Device configuration for API requests
    var device: [AnyHashable: Any]? { get set }
    
    /// Cached subscriber status
    var cachedSubscriberStatus: NSNumber? { get set }
    
    /// Authenticate with Pandora
    func authenticate(_ user: String!, password: String!, request req: PandoraRequest?) -> Bool
    
    /// Log out and clear all state
    func logout()
    
    /// Log out without posting notification
    func logoutNoNotify()
    
    /// Check if user is authenticated
    func isAuthenticated() -> Bool
    
    /// Fetch all stations for the authenticated user
    func fetchStations() -> Bool
    
    /// Create a new station from a music token
    func createStation(_ musicId: String!) -> Bool
    
    /// Remove a station
    func removeStation(_ stationToken: String!) -> Bool
    
    /// Rename a station
    func renameStation(_ stationToken: String!, to name: String!) -> Bool
    
    /// Fetch detailed info for a station
    func fetchStationInfo(_ station: Station!) -> Bool
    
    /// Fetch genre stations
    func fetchGenreStations() -> Bool
    
    /// Sort stations
    func sortStations(_ sort: Int)
    
    /// Fetch playlist for a station
    @objc(fetchPlaylistForStation:)
    func fetchPlaylist(for station: Station!) -> Bool
    
    /// Rate a song
    func rateSong(_ song: Song!, as liked: Bool) -> Bool
    
    /// Mark a song as "tired of"
    @objc(tiredOfSong:)
    func tired(of song: Song!) -> Bool
    
    /// Delete a song rating
    func deleteRating(_ song: Song!) -> Bool
    
    /// Search for artists/songs
    func search(_ searchQuery: String!) -> Bool
    
    /// Add a seed to a station
    @objc(addSeed:toStation:)
    func addSeed(_ token: String!, to station: Station!) -> Bool
    
    /// Remove a seed from a station
    func removeSeed(_ seedId: String!) -> Bool
    
    /// Delete feedback
    func deleteFeedback(_ feedbackId: String!) -> Bool
}

// MARK: - PandoraError

/// Errors that can occur during Pandora API operations
enum PandoraError: Error, LocalizedError {
    case invalidSyncTime
    case invalidAuthToken
    case invalidPartnerLogin
    case invalidUsername
    case invalidPassword
    case noSeedsLeft
    case networkError(Error)
    case apiError(code: Int, message: String)
    case encodingError
    case decodingError
    case notAuthenticated
    
    /// Create a PandoraError from an API error code
    static func from(code: Int) -> PandoraError? {
        switch code {
        case 13: return .invalidSyncTime
        case 1001: return .invalidAuthToken
        case 1002: return .invalidPartnerLogin
        case 1011: return .invalidUsername
        case 1012: return .invalidPassword
        case 1032: return .noSeedsLeft
        default: return nil
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidSyncTime:
            return "Bad sync time"
        case .invalidAuthToken:
            return "Invalid authentication token"
        case .invalidPartnerLogin:
            return "Invalid partner login"
        case .invalidUsername:
            return "Invalid username"
        case .invalidPassword:
            return "Invalid password"
        case .noSeedsLeft:
            return "Cannot remove all seeds"
        case .networkError(let error):
            return error.localizedDescription
        case .apiError(_, let message):
            return message
        case .encodingError:
            return "Failed to encode request"
        case .decodingError:
            return "Failed to decode response"
        case .notAuthenticated:
            return "Not authenticated"
        }
    }
    
    /// Get error message for a Pandora error code
    static func message(for code: Int) -> String? {
        let lowErrors: [Int: String] = [
            0: "Internal Pandora error",
            1: "Pandora is in Maintenance Mode",
            2: "URL is missing method parameter",
            3: "URL is missing auth token",
            4: "URL is missing partner ID",
            5: "URL is missing user ID",
            6: "A secure protocol is required for this request",
            7: "A certificate is required for the request",
            8: "Parameter type mismatch",
            9: "Parameter is missing",
            10: "Parameter value is invalid",
            11: "API version is not supported",
            12: "Pandora is not available in this country",
            13: "Bad sync time",
            14: "Unknown method name",
            15: "Wrong protocol used"
        ]
        
        let highErrors: [Int: String] = [
            1000: "Read only mode",
            1001: "Invalid authentication token",
            1002: "Wrong user credentials",
            1003: "Listener not authorized",
            1004: "User not authorized",
            1005: "Station limit reached",
            1006: "Station does not exist",
            1007: "Complimentary period already in use",
            1008: "Call not allowed",
            1009: "Device not found",
            1010: "Partner not authorized",
            1011: "Invalid username",
            1012: "Invalid password",
            1013: "Username already exists",
            1014: "Device already associated to account",
            1015: "Upgrade, device model is invalid",
            1018: "Explicit PIN incorrect",
            1020: "Explicit PIN malformed",
            1023: "Device model invalid",
            1024: "ZIP code invalid",
            1025: "Birth year invalid",
            1026: "Birth year too young",
            1027: "Invalid country code",
            1028: "Invalid gender",
            1032: "Cannot remove all seeds",
            1034: "Device disabled",
            1035: "Daily trial limit reached",
            1036: "Invalid sponsor",
            1037: "User already used trial"
        ]
        
        if code < 16 {
            return lowErrors[code]
        } else if code >= 1000 && code <= 1037 {
            return highErrors[code]
        }
        return nil
    }
}

// MARK: - PandoraSearchResult

/// Search result from Pandora API
@objc(SwiftPandoraSearchResult)
@objcMembers
final class PandoraSearchResult: NSObject {
    var name: String = ""
    var value: String = ""
    
    override init() {
        super.init()
    }
    
    init(name: String, value: String) {
        self.name = name
        self.value = value
        super.init()
    }
}

// MARK: - PandoraRequest

/// Pandora API request object
@objc(SwiftPandoraRequest)
@objcMembers
final class PandoraRequest: NSObject, NSCopying {
    
    // MARK: URL Parameters
    
    /// Pandora API method to use
    var method: String = ""
    
    /// Auth token obtained from auth.userLogin (or auth.partnerLogin)
    var authToken: String = ""
    
    /// Partner id as obtained by auth.partnerLogin
    var partnerId: String = ""
    
    /// User id obtained from auth.userLogin
    var userId: String = ""
    
    // MARK: JSON Data
    
    var request: [String: Any] = [:]
    var response: NSMutableData = NSMutableData()
    
    // MARK: Internal Metadata
    
    var callback: (([String: Any]) -> Void)?
    var tls: Bool = true
    var encrypted: Bool = true
    
    // MARK: Initialization
    
    override init() {
        super.init()
    }
    
    // MARK: NSCopying
    
    func copy(with zone: NSZone? = nil) -> Any {
        let copy = PandoraRequest()
        copy.method = method
        copy.authToken = authToken
        copy.partnerId = partnerId
        copy.userId = userId
        copy.request = request
        copy.response = response.mutableCopy() as! NSMutableData
        copy.callback = callback
        copy.tls = tls
        copy.encrypted = encrypted
        return copy
    }
    
    // MARK: Description
    
    override var description: String {
        return "<\(type(of: self)) \(Unmanaged.passUnretained(self).toOpaque()) \(method)>"
    }
}

// MARK: - PandoraClient

/// Modern Swift implementation of Pandora API client
/// Implements PandoraProtocol for compatibility with existing code
@objc(SwiftPandoraClient)
@objcMembers
final class PandoraClient: NSObject, PandoraProtocol {
    
    // MARK: - Properties
    
    /// Array of stations for the authenticated user
    private var _stations: [Station] = []
    var stations: [Any]? { _stations }
    
    /// Device configuration for API requests
    var device: [AnyHashable: Any]?
    
    /// Cached subscriber status
    var cachedSubscriberStatus: NSNumber?
    
    // MARK: - Private State
    
    internal var partnerId: String?
    internal var partnerAuthToken: String?
    internal var userAuthToken: String?
    internal var userId: String?
    internal var syncTime: UInt64 = 0
    internal var startTime: UInt64 = 0
    private var retries: Int = 0
    
    private let httpClient: HTTPClient
    
    // MARK: - Initialization
    
    override init() {
        self.httpClient = HTTPClient()
        super.init()
        self.device = PandoraDevice.android.toDictionary()
    }
    
    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
        super.init()
        self.device = PandoraDevice.android.toDictionary()
    }
    
    // MARK: - Notification Helpers
    
    private func postNotification(_ name: String, object: Any? = nil, userInfo: [String: Any]? = nil) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name(name),
                object: object,
                userInfo: userInfo
            )
        }
    }
    
    // MARK: - Time Helpers
    
    private var currentTime: Int64 {
        Int64(Date().timeIntervalSince1970)
    }
    
    private var syncTimeNumber: NSNumber {
        NSNumber(value: syncTime + UInt64(currentTime - Int64(startTime)))
    }
    
    // MARK: - Crypto
    
    private func encryptData(_ data: Data) -> Data? {
        guard let deviceDict = device,
              let encryptKey = deviceDict["encrypt"] as? String else {
            return nil
        }
        
        do {
            let encrypted = try PandoraCrypto.encrypt(data, key: encryptKey)
            return encrypted.data(using: .utf8)
        } catch {
            NSLog("encryptData: Encryption failed: \(error)")
            return nil
        }
    }
    
    private func decryptString(_ string: String) -> Data? {
        guard let deviceDict = device,
              let decryptKey = deviceDict["decrypt"] as? String else {
            return nil
        }
        
        do {
            return try PandoraCrypto.decrypt(string, key: decryptKey)
        } catch {
            NSLog("Decryption failed: \(error)")
            return nil
        }
    }
}


// MARK: - Authentication

extension PandoraClient {
    
    /// Authenticate with Pandora
    /// - Parameters:
    ///   - user: Username
    ///   - password: Password
    ///   - req: Optional request to retry after authentication
    /// - Returns: true if request was sent
    func authenticate(_ user: String!, password: String!, request req: PandoraRequest?) -> Bool {
        guard let user = user, let password = password else { return false }
        
        return doUserLogin(username: user, password: password) { [weak self] dict in
            guard let self = self else { return }
            
            // Only send the pandoraDidAuthenticate notification if there is no request to retry
            if req == nil {
                self.postNotification("PandoraDidAuthenticateNotification")
            } else if let req = req {
                NSLog("Retrying request...")
                guard let newRequest = req.copy() as? PandoraRequest else { return }
                
                // Update the request dictionary with new User Auth Token & Sync Time
                var updatedRequest = newRequest.request
                updatedRequest["userAuthToken"] = self.userAuthToken
                updatedRequest["syncTime"] = self.syncTimeNumber
                newRequest.request = updatedRequest
                
                // Also update the properties on the request used to build the request URL
                newRequest.userId = self.userId ?? ""
                newRequest.authToken = self.userAuthToken ?? ""
                newRequest.partnerId = self.partnerId ?? ""
                
                _ = self.sendRequest(newRequest)
            }
        }
    }
    
    /// Perform user login
    private func doUserLogin(username: String, password: String, callback: @escaping ([String: Any]) -> Void) -> Bool {
        if partnerId == nil {
            // Get partner ID then reinvoke this method
            return doPartnerLogin { [weak self] in
                _ = self?.doUserLogin(username: username, password: password, callback: callback)
            }
        }
        
        let loginRequest = PandoraRequest()
        loginRequest.request = [
            "loginType": "user",
            "username": username,
            "password": password,
            "partnerAuthToken": partnerAuthToken ?? "",
            "syncTime": syncTimeNumber,
            "returnIsSubscriber": true
        ]
        loginRequest.method = "auth.userLogin"
        loginRequest.partnerId = partnerId ?? ""
        loginRequest.authToken = partnerAuthToken ?? ""
        
        loginRequest.callback = { [weak self] respDict in
            guard let self = self,
                  let result = respDict["result"] as? [String: Any] else { return }
            
            self.userAuthToken = result["userAuthToken"] as? String
            self.userId = result["userId"] as? String
            
            if let subscriberStatus = result["isSubscriber"] as? NSNumber {
                self.cachedSubscriberStatus = subscriberStatus
            } else {
                NSLog("Warning: no key isSubscriber, assuming non-subscriber.")
                self.cachedSubscriberStatus = NSNumber(value: false)
            }
            NSLog("Subscriber status: \(self.cachedSubscriberStatus ?? 0)")
            
            // Check if subscriber and need to re-login with desktop device
            if let deviceDict = self.device,
               let deviceUsername = deviceDict["username"] as? String,
               self.cachedSubscriberStatus?.boolValue == true && deviceUsername != "pandora one" {
                NSLog("Subscriber detected, re-logging-in...")
                self.device = PandoraDevice.desktop.toDictionary()
                self.logoutNoNotify()
                _ = self.doUserLogin(username: username, password: password, callback: callback)
                return
            }
            
            NSLog("Logged in as \(username).")
            callback(respDict)
        }
        
        return sendRequest(loginRequest)
    }
    
    /// Perform partner login to get sync time and partner auth token
    private func doPartnerLogin(callback: @escaping () -> Void) -> Bool {
        NSLog("Getting partner ID...")
        startTime = UInt64(currentTime)
        
        guard let deviceDict = device else { return false }
        
        let request = PandoraRequest()
        request.request = [
            "username": deviceDict["username"] ?? "",
            "password": deviceDict["password"] ?? "",
            "deviceModel": deviceDict["deviceid"] ?? "",
            "version": pandoraAPIVersion,
            "includeUrls": true
        ]
        request.method = "auth.partnerLogin"
        request.encrypted = false
        
        request.callback = { [weak self] dict in
            guard let self = self,
                  let result = dict["result"] as? [String: Any] else {
                NSLog("Partner login callback: No result in response")
                return
            }
            
            self.partnerAuthToken = result["partnerAuthToken"] as? String
            self.partnerId = result["partnerId"] as? String
            
            NSLog("Partner login: partnerId=\(self.partnerId ?? "nil"), partnerAuthToken=\(self.partnerAuthToken ?? "nil")")
            
            if let syncTimeString = result["syncTime"] as? String,
               let syncData = self.decryptString(syncTimeString) {
                // The sync time is at offset 4 in the decrypted data
                let bytes = [UInt8](syncData)
                if bytes.count > 4 {
                    // Extract only digit characters (ASCII 48-57 = '0'-'9')
                    // This filters out padding and non-numeric bytes
                    let digitBytes = bytes[4...].filter { $0 >= 48 && $0 <= 57 }
                    
                    if let syncString = String(bytes: digitBytes, encoding: .utf8), !syncString.isEmpty {
                        self.syncTime = UInt64(syncString) ?? 0
                    }
                }
            }
            
            NSLog("Partner login: startTime set to \(self.currentTime)")
            callback()
        }
        
        return sendRequest(request)
    }
    
    /// Log out and clear all state
    func logout() {
        logoutNoNotify()
        
        for station in _stations {
            Station.removeStation(station)
        }
        _stations.removeAll()
        
        postNotification("PandoraDidLogOutNotification")
        
        // Always assume non-subscriber until API says otherwise
        cachedSubscriberStatus = nil
        device = PandoraDevice.android.toDictionary()
    }
    
    /// Log out without posting notification
    func logoutNoNotify() {
        userAuthToken = nil
        partnerAuthToken = nil
        partnerId = nil
        userId = nil
        syncTime = 0
        startTime = 0
    }
    
    /// Check if user is authenticated
    func isAuthenticated() -> Bool {
        return userAuthToken != nil && cachedSubscriberStatus != nil
    }
}


// MARK: - Station Management

extension PandoraClient {
    
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
    private func parseStation(from dict: [String: Any]) -> Station {
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
}


// MARK: - Playback

extension PandoraClient {
    
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
}

// MARK: - Song Operations

extension PandoraClient {
    
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
}


// MARK: - Search

extension PandoraClient {
    
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
}

// MARK: - Seed Management

extension PandoraClient {
    
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
}


// MARK: - Request Infrastructure

extension PandoraClient {
    
    /// Create default request dictionary with auth token and sync time
    private func defaultRequestDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let token = userAuthToken {
            dict["userAuthToken"] = token
        }
        dict["syncTime"] = syncTimeNumber
        return dict
    }
    
    /// Create a default request with the specified method
    private func defaultRequest(method: String) -> PandoraRequest {
        let request = PandoraRequest()
        request.userId = userId ?? ""
        request.authToken = userAuthToken ?? ""
        request.method = method
        request.partnerId = partnerId ?? ""
        return request
    }
    
    /// Send a request that requires authentication
    private func sendAuthenticatedRequest(_ request: PandoraRequest) -> Bool {
        if isAuthenticated() {
            return sendRequest(request)
        }
        
        // Get saved credentials and re-authenticate
        let user = UserDefaults.standard.string(forKey: "pandora.username")
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
                    let user = UserDefaults.standard.string(forKey: "pandora.username")
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
}

// MARK: - Error Code Helper

extension PandoraClient {
    
    /// Get error message for a Pandora error code
    @objc static func string(forErrorCode code: Int) -> String? {
        return PandoraError.message(for: code)
    }
}


// MARK: - Async/Await API

extension PandoraClient {
    
    /// Authenticate with Pandora using async/await
    /// - Parameters:
    ///   - username: Pandora username
    ///   - password: Pandora password
    /// - Throws: PandoraError on failure
    func authenticate(username: String, password: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var observer: NSObjectProtocol?
            var errorObserver: NSObjectProtocol?
            
            // Observe success
            observer = NotificationCenter.default.addObserver(
                forName: .pandoraDidAuthenticate,
                object: nil,
                queue: .main
            ) { _ in
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                continuation.resume()
            }
            
            // Observe error
            errorObserver = NotificationCenter.default.addObserver(
                forName: .pandoraDidError,
                object: nil,
                queue: .main
            ) { notification in
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                
                let errorMessage = notification.userInfo?["err"] as? String ?? "Authentication failed"
                let code = notification.userInfo?["code"] as? Int
                
                if let code = code, let pandoraError = PandoraError.from(code: code) {
                    continuation.resume(throwing: pandoraError)
                } else {
                    continuation.resume(throwing: PandoraError.apiError(code: code ?? 0, message: errorMessage))
                }
            }
            
            // Start authentication
            if !self.authenticate(username, password: password, request: nil) {
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                continuation.resume(throwing: PandoraError.networkError(HTTPClientError.invalidResponse))
            }
        }
    }
    
    /// Fetch stations using async/await
    /// - Returns: Array of stations
    /// - Throws: PandoraError on failure
    func fetchStationsAsync() async throws -> [Station] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Station], Error>) in
            var observer: NSObjectProtocol?
            var errorObserver: NSObjectProtocol?
            
            observer = NotificationCenter.default.addObserver(
                forName: .pandoraDidLoadStations,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                continuation.resume(returning: self?._stations ?? [])
            }
            
            errorObserver = NotificationCenter.default.addObserver(
                forName: .pandoraDidError,
                object: nil,
                queue: .main
            ) { notification in
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                
                let errorMessage = notification.userInfo?["err"] as? String ?? "Failed to fetch stations"
                continuation.resume(throwing: PandoraError.apiError(code: 0, message: errorMessage))
            }
            
            if !self.fetchStations() {
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                continuation.resume(throwing: PandoraError.notAuthenticated)
            }
        }
    }
    
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
    
    /// Search for music using async/await
    /// - Parameter query: Search query
    /// - Returns: Dictionary with "Songs" and "Artists" arrays of PandoraSearchResult
    /// - Throws: PandoraError on failure
    func searchAsync(_ query: String) async throws -> [String: [PandoraSearchResult]] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: [PandoraSearchResult]], Error>) in
            var observer: NSObjectProtocol?
            var errorObserver: NSObjectProtocol?
            
            observer = NotificationCenter.default.addObserver(
                forName: .pandoraDidLoadSearchResults,
                object: nil,
                queue: .main
            ) { notification in
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                
                var results: [String: [PandoraSearchResult]] = [:]
                if let songs = notification.userInfo?["Songs"] as? [PandoraSearchResult] {
                    results["Songs"] = songs
                }
                if let artists = notification.userInfo?["Artists"] as? [PandoraSearchResult] {
                    results["Artists"] = artists
                }
                continuation.resume(returning: results)
            }
            
            errorObserver = NotificationCenter.default.addObserver(
                forName: .pandoraDidError,
                object: nil,
                queue: .main
            ) { notification in
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                
                let errorMessage = notification.userInfo?["err"] as? String ?? "Search failed"
                continuation.resume(throwing: PandoraError.apiError(code: 0, message: errorMessage))
            }
            
            if !self.search(query) {
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
    
    /// Create a station using async/await
    /// - Parameter musicId: Music token from search results
    /// - Returns: The created station
    /// - Throws: PandoraError on failure
    func createStationAsync(_ musicId: String) async throws -> Station {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Station, Error>) in
            var observer: NSObjectProtocol?
            var errorObserver: NSObjectProtocol?
            
            observer = NotificationCenter.default.addObserver(
                forName: .pandoraDidCreateStation,
                object: nil,
                queue: .main
            ) { notification in
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                
                if let station = notification.userInfo?["station"] as? Station {
                    continuation.resume(returning: station)
                } else {
                    continuation.resume(throwing: PandoraError.decodingError)
                }
            }
            
            errorObserver = NotificationCenter.default.addObserver(
                forName: .pandoraDidError,
                object: nil,
                queue: .main
            ) { notification in
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                
                let errorMessage = notification.userInfo?["err"] as? String ?? "Failed to create station"
                continuation.resume(throwing: PandoraError.apiError(code: 0, message: errorMessage))
            }
            
            if !self.createStation(musicId) {
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                if let obs = errorObserver { NotificationCenter.default.removeObserver(obs) }
                continuation.resume(throwing: PandoraError.notAuthenticated)
            }
        }
    }
}
