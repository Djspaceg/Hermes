//
//  PandoraClient.swift
//  Hermes
//
//  Modern Swift implementation of Pandora API client
//  Core client functionality - specific operations are in separate files:
//  - PandoraAuth.swift: Authentication
//  - PandoraStations.swift: Station management
//  - PandoraPlayback.swift: Playback and song operations
//  - PandoraNetwork.swift: Network layer and search
//  - PandoraModels.swift: Request/response models and errors
//

import Foundation

// MARK: - PandoraClient

/// Modern Swift implementation of Pandora API client
/// Implements PandoraProtocol for compatibility with existing code
@objc(SwiftPandoraClient)
@objcMembers
final class PandoraClient: NSObject, PandoraProtocol {
    
    // MARK: - Properties
    
    /// Array of stations for the authenticated user
    internal var _stations: [Station] = []
    var stations: [Any]? { _stations }
    
    /// Device configuration for API requests
    var device: [AnyHashable: Any]?
    
    /// Cached subscriber status
    var cachedSubscriberStatus: NSNumber?
    
    // MARK: - Internal State
    
    internal var partnerId: String?
    internal var partnerAuthToken: String?
    internal var userAuthToken: String?
    internal var userId: String?
    internal var syncTime: UInt64 = 0
    internal var startTime: UInt64 = 0
    internal var retries: Int = 0
    
    internal let httpClient: HTTPClient
    
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
    
    internal func postNotification(_ name: String, object: Any? = nil, userInfo: [String: Any]? = nil) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name(name),
                object: object,
                userInfo: userInfo
            )
        }
    }
    
    // MARK: - Time Helpers
    
    internal var currentTime: Int64 {
        Int64(Date().timeIntervalSince1970)
    }
    
    internal var syncTimeNumber: NSNumber {
        NSNumber(value: syncTime + UInt64(currentTime - Int64(startTime)))
    }
    
    // MARK: - Crypto
    
    internal func encryptData(_ data: Data) -> Data? {
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
    
    internal func decryptString(_ string: String) -> Data? {
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

// MARK: - Note
// All specific functionality has been extracted to separate files:
// - Authentication: See PandoraAuth.swift
// - Station Management: See PandoraStations.swift
// - Playback Operations: See PandoraPlayback.swift
// - Network Layer: See PandoraNetwork.swift
// - Models & Errors: See PandoraModels.swift
