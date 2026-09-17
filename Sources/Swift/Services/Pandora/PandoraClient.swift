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

struct PandoraCredentialRecoveryToken: Sendable {
    let recoveryGeneration: UInt64
    let authenticationGeneration: UInt64
}

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
    @nonobjc internal let credentialStore: any CredentialStore
    @nonobjc internal let userDefaults: UserDefaults
    @nonobjc private let credentialRecoveryLock = NSLock()
    @nonobjc private var credentialRecoveryGeneration: UInt64 = 0
    @nonobjc private var authenticationGeneration: UInt64 = 0
    @nonobjc private var manualAuthenticationGeneration: UInt64?
    
    // MARK: - Initialization
    
    override init() {
        self.httpClient = HTTPClient()
        self.credentialStore = KeychainManager.shared
        self.userDefaults = Self.defaultUserDefaults
        super.init()
        device = PandoraDevice.android.toDictionary()
    }
    
    init(
        httpClient: HTTPClient,
        credentialStore: (any CredentialStore)? = nil,
        userDefaults: UserDefaults? = nil
    ) {
        self.httpClient = httpClient
        self.credentialStore = credentialStore ?? KeychainManager.shared
        self.userDefaults = userDefaults ?? Self.defaultUserDefaults
        super.init()
        device = PandoraDevice.android.toDictionary()
    }

    init(
        credentialStore: any CredentialStore,
        userDefaults: UserDefaults
    ) {
        self.httpClient = HTTPClient()
        self.credentialStore = credentialStore
        self.userDefaults = userDefaults
        super.init()
        device = PandoraDevice.android.toDictionary()
    }

    private static var defaultUserDefaults: UserDefaults {
        if TestProcessDetection.isRunningTests {
            return UserDefaults(suiteName: "com.hermes.tests.pandora.\(UUID().uuidString)")!
        }
        return .standard
    }

    @nonobjc
    internal func beginAutomaticCredentialRecovery() -> PandoraCredentialRecoveryToken? {
        credentialRecoveryLock.lock()
        defer { credentialRecoveryLock.unlock() }
        guard manualAuthenticationGeneration == nil else {
            return nil
        }
        credentialRecoveryGeneration &+= 1
        return PandoraCredentialRecoveryToken(
            recoveryGeneration: credentialRecoveryGeneration,
            authenticationGeneration: authenticationGeneration
        )
    }

    @nonobjc
    internal func beginManualCredentialAuthentication() -> UInt64 {
        credentialRecoveryLock.lock()
        defer { credentialRecoveryLock.unlock() }
        credentialRecoveryGeneration &+= 1
        authenticationGeneration &+= 1
        manualAuthenticationGeneration = authenticationGeneration
        return authenticationGeneration
    }

    @nonobjc
    internal func beginAutomaticCredentialAuthentication(
        token: PandoraCredentialRecoveryToken
    ) -> UInt64? {
        credentialRecoveryLock.lock()
        defer { credentialRecoveryLock.unlock() }
        guard manualAuthenticationGeneration == nil,
              credentialRecoveryGeneration == token.recoveryGeneration,
              authenticationGeneration == token.authenticationGeneration else {
            return nil
        }
        authenticationGeneration &+= 1
        return authenticationGeneration
    }

    @nonobjc
    internal func isCredentialRecoveryTokenCurrent(
        _ token: PandoraCredentialRecoveryToken
    ) -> Bool {
        credentialRecoveryLock.lock()
        defer { credentialRecoveryLock.unlock() }
        return manualAuthenticationGeneration == nil &&
            credentialRecoveryGeneration == token.recoveryGeneration &&
            authenticationGeneration == token.authenticationGeneration
    }

    @nonobjc
    internal func isAuthenticationGenerationCurrent(_ generation: UInt64) -> Bool {
        credentialRecoveryLock.lock()
        defer { credentialRecoveryLock.unlock() }
        return authenticationGeneration == generation
    }

    @nonobjc
    internal func currentAuthenticationGeneration() -> UInt64 {
        credentialRecoveryLock.lock()
        defer { credentialRecoveryLock.unlock() }
        return authenticationGeneration
    }

    @nonobjc
    internal func performIfAuthenticationGenerationCurrent(
        _ generation: UInt64,
        operation: () -> Void
    ) -> Bool {
        credentialRecoveryLock.lock()
        defer { credentialRecoveryLock.unlock() }
        guard authenticationGeneration == generation else {
            return false
        }
        operation()
        return true
    }

    @nonobjc
    internal func completeCredentialAuthenticationIfCurrent(_ generation: UInt64) -> Bool {
        credentialRecoveryLock.lock()
        defer { credentialRecoveryLock.unlock() }
        guard authenticationGeneration == generation else {
            return false
        }
        if manualAuthenticationGeneration == generation {
            manualAuthenticationGeneration = nil
        }
        return true
    }

    @nonobjc
    internal func finishCredentialAuthentication(_ generation: UInt64) {
        credentialRecoveryLock.lock()
        defer { credentialRecoveryLock.unlock() }
        if manualAuthenticationGeneration == generation {
            manualAuthenticationGeneration = nil
        }
    }

    @nonobjc
    internal func invalidateAutomaticCredentialRecovery(_ operation: () -> Void = {}) {
        credentialRecoveryLock.lock()
        defer { credentialRecoveryLock.unlock() }
        credentialRecoveryGeneration &+= 1
        authenticationGeneration &+= 1
        manualAuthenticationGeneration = nil
        operation()
    }

    @nonobjc
    internal func invalidateAuthenticationIfCurrent(
        _ generation: UInt64,
        operation: () -> Void
    ) -> Bool {
        credentialRecoveryLock.lock()
        defer { credentialRecoveryLock.unlock() }
        guard authenticationGeneration == generation else {
            return false
        }
        credentialRecoveryGeneration &+= 1
        authenticationGeneration &+= 1
        manualAuthenticationGeneration = nil
        operation()
        return true
    }
    
    // MARK: - Notification Helpers
    
    internal func postNotification(
        _ name: String,
        object: Any? = nil,
        userInfo: [String: Any]? = nil,
        authenticationGeneration: UInt64? = nil,
        credentialRecoveryToken: PandoraCredentialRecoveryToken? = nil
    ) {
        DispatchQueue.main.async { [weak self] in
            if let authenticationGeneration {
                guard let self,
                      self.isAuthenticationGenerationCurrent(authenticationGeneration) else {
                    return
                }
            }
            if let credentialRecoveryToken {
                guard let self,
                      self.isCredentialRecoveryTokenCurrent(credentialRecoveryToken) else {
                    return
                }
            }
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
