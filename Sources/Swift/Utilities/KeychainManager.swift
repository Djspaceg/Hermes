//
//  KeychainManager.swift
//  Hermes
//
//  Modern Swift keychain manager using Security framework
//

import Foundation
import Security

// MARK: - Keychain Protocol

/// Protocol for keychain operations - allows mocking in tests
protocol KeychainProtocol {
    func saveCredentials(username: String, password: String) throws
    func retrievePassword(username: String) throws -> String?
    func deleteCredentials(username: String) throws
    func deleteAllCredentials() throws
    func hasCredentials(username: String) -> Bool
}

/// Modern keychain manager for secure credential storage
final class KeychainManager: KeychainProtocol {
    
    // MARK: - Singleton
    
    static let shared: KeychainProtocol = {
        // Use mock keychain during unit tests
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return MockKeychainManager()
        }
        return KeychainManager()
    }()
    
    private init() {}
    
    // MARK: - Constants
    
    private let service = "org.hermesapp.Hermes"
    
    // MARK: - Public API
    
    /// Save credentials to keychain
    func saveCredentials(username: String, password: String) throws {
        guard !username.isEmpty, !password.isEmpty else {
            throw KeychainError.invalidInput
        }
        
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.encodingError
        }
        
        // Delete any existing item first
        try? deleteCredentials(username: username)
        
        // Create query for new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: false // Don't sync to iCloud
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
        
        print("KeychainManager: Saved credentials for user: \(username)")
    }
    
    /// Retrieve password for username from keychain
    func retrievePassword(username: String) throws -> String? {
        guard !username.isEmpty else {
            throw KeychainError.invalidInput
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // Item not found is not an error - just return nil
        if status == errSecItemNotFound {
            print("KeychainManager: No password found for user: \(username)")
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
        
        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingError
        }
        
        print("KeychainManager: Retrieved password for user: \(username)")
        return password
    }
    
    /// Delete credentials from keychain
    func deleteCredentials(username: String) throws {
        guard !username.isEmpty else {
            throw KeychainError.invalidInput
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // Item not found is not an error when deleting
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
        
        print("KeychainManager: Deleted credentials for user: \(username)")
    }
    
    /// Delete all Hermes credentials from keychain
    func deleteAllCredentials() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // Item not found is not an error when deleting
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
        
        print("KeychainManager: Deleted all credentials")
    }
    
    /// Check if credentials exist for username
    func hasCredentials(username: String) -> Bool {
        guard !username.isEmpty else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Keychain Error

enum KeychainError: LocalizedError {
    case invalidInput
    case encodingError
    case decodingError
    case unhandledError(status: OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Invalid username or password"
        case .encodingError:
            return "Failed to encode password"
        case .decodingError:
            return "Failed to decode password"
        case .unhandledError(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return "Keychain error: \(message)"
            }
            return "Keychain error: \(status)"
        }
    }
}


// MARK: - Mock Keychain Manager (for testing)

/// Mock keychain manager that stores credentials in memory during tests
final class MockKeychainManager: KeychainProtocol {
    
    private var storage: [String: String] = [:]
    
    func saveCredentials(username: String, password: String) throws {
        guard !username.isEmpty, !password.isEmpty else {
            throw KeychainError.invalidInput
        }
        storage[username] = password
        print("MockKeychainManager: Saved credentials for user: \(username)")
    }
    
    func retrievePassword(username: String) throws -> String? {
        guard !username.isEmpty else {
            throw KeychainError.invalidInput
        }
        let password = storage[username]
        print("MockKeychainManager: Retrieved password for user: \(username) - found: \(password != nil)")
        return password
    }
    
    func deleteCredentials(username: String) throws {
        guard !username.isEmpty else {
            throw KeychainError.invalidInput
        }
        storage.removeValue(forKey: username)
        print("MockKeychainManager: Deleted credentials for user: \(username)")
    }
    
    func deleteAllCredentials() throws {
        storage.removeAll()
        print("MockKeychainManager: Deleted all credentials")
    }
    
    func hasCredentials(username: String) -> Bool {
        guard !username.isEmpty else { return false }
        return storage[username] != nil
    }
}
