//
//  KeychainManager.swift
//  Hermes
//
//  Modern Swift keychain manager using Security framework
//

import Foundation
import LocalAuthentication
import Security

enum TestProcessDetection {
    static var isRunningTests: Bool {
        detectsTestProcess(
            environment: ProcessInfo.processInfo.environment,
            arguments: ProcessInfo.processInfo.arguments,
            hasTestRuntime: NSClassFromString("XCTest") != nil ||
                NSClassFromString("XCTestCase") != nil
        )
    }

    static func detectsTestProcess(
        environment: [String: String],
        arguments: [String],
        hasTestRuntime: Bool
    ) -> Bool {
        let hasGuardedTestEnvironment = environment["HERMES_TEST_ROOT"] != nil ||
            environment["HERMES_TEST_CANONICAL_TMP"] != nil ||
            environment["HERMES_TEST_HOME"] != nil ||
            environment["HERMES_TEST_STATE_PATH"] != nil
        return environment["XCTestConfigurationFilePath"] != nil ||
            environment["XCTestSessionIdentifier"] != nil ||
            environment["XCTestBundlePath"] != nil ||
            hasGuardedTestEnvironment ||
            hasTestRuntime ||
            arguments.contains { argument in
                argument.contains("xctest") ||
                    argument.contains("XCTest") ||
                    argument.hasSuffix(".xctest")
            }
    }
}

enum CredentialLookupResult: Equatable, Sendable {
    case found(String)
    case absent
    case temporarilyUnavailable
}

enum CredentialExistence: Equatable, Sendable {
    case present
    case absent
    case temporarilyUnavailable
}

enum CredentialStoreError: Error, LocalizedError, Sendable {
    case invalidInput
    case encodingError
    case decodingError
    case temporarilyUnavailable
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Invalid username or password"
        case .encodingError:
            return "Failed to encode password"
        case .decodingError:
            return "Failed to decode password"
        case .temporarilyUnavailable:
            return "Saved credentials are temporarily unavailable"
        case .unhandledStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return "Keychain error: \(message)"
            }
            return "Keychain error: \(status)"
        }
    }
}

protocol CredentialStore: Sendable {
    func saveCredentials(username: String, password: String) async throws
    func retrievePassword(username: String) async throws -> CredentialLookupResult
    func deleteCredentials(username: String) async throws
    func deleteAllCredentials() async throws
    func credentialStatus(username: String) async throws -> CredentialExistence
}

final class KeychainManager: CredentialStore, @unchecked Sendable {
    static let shared: any CredentialStore = {
        if TestProcessDetection.isRunningTests {
            return MockKeychainManager()
        }
        return KeychainManager()
    }()

    private let service = "org.hermesapp.Hermes"
    private let securityQueue = DispatchQueue(label: "org.hermesapp.Hermes.credentials")

    func saveCredentials(username: String, password: String) async throws {
        try await performSecurityOperation {
            guard !username.isEmpty, !password.isEmpty else {
                throw CredentialStoreError.invalidInput
            }
            guard let passwordData = password.data(using: .utf8) else {
                throw CredentialStoreError.encodingError
            }

            let context = Self.noninteractiveContext()
            let matchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.service,
                kSecAttrAccount as String: username,
                kSecUseAuthenticationContext as String: context
            ]
            let updateAttributes: [String: Any] = [
                kSecValueData as String: passwordData
            ]
            let updateStatus = SecItemUpdate(
                matchQuery as CFDictionary,
                updateAttributes as CFDictionary
            )
            if updateStatus == errSecSuccess {
                return
            }
            if updateStatus != errSecItemNotFound {
                try Self.throwIfMutationFailed(updateStatus)
            }

            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.service,
                kSecAttrAccount as String: username,
                kSecValueData as String: passwordData,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
                kSecAttrSynchronizable as String: false
            ]
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            try Self.throwIfMutationFailed(addStatus)
        }
    }

    func retrievePassword(username: String) async throws -> CredentialLookupResult {
        try await performSecurityOperation {
            guard !username.isEmpty else {
                throw CredentialStoreError.invalidInput
            }

            let context = Self.noninteractiveContext()
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.service,
                kSecAttrAccount as String: username,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecUseAuthenticationContext as String: context
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            return try Self.lookupResult(status: status, result: result)
        }
    }

    func deleteCredentials(username: String) async throws {
        try await performSecurityOperation {
            guard !username.isEmpty else {
                throw CredentialStoreError.invalidInput
            }
            try self.deleteCredentialsSynchronously(username: username)
        }
    }

    func deleteAllCredentials() async throws {
        try await performSecurityOperation {
            let context = Self.noninteractiveContext()
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.service,
                kSecUseAuthenticationContext as String: context
            ]
            let status = SecItemDelete(query as CFDictionary)
            try Self.throwIfMutationFailed(status)
        }
    }

    func credentialStatus(username: String) async throws -> CredentialExistence {
        try await performSecurityOperation {
            guard !username.isEmpty else {
                throw CredentialStoreError.invalidInput
            }

            let context = Self.noninteractiveContext()
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.service,
                kSecAttrAccount as String: username,
                kSecReturnData as String: false,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecUseAuthenticationContext as String: context
            ]
            let status = SecItemCopyMatching(query as CFDictionary, nil)
            switch status {
            case errSecSuccess:
                return .present
            case errSecItemNotFound:
                return .absent
            case errSecInteractionNotAllowed, errSecInteractionRequired, errSecDataNotAvailable,
                 errSecNotAvailable:
                return .temporarilyUnavailable
            default:
                throw CredentialStoreError.unhandledStatus(status)
            }
        }
    }

    static func lookupResult(status: OSStatus, result: AnyObject?) throws -> CredentialLookupResult {
        switch status {
        case errSecItemNotFound:
            return .absent
        case errSecInteractionNotAllowed, errSecInteractionRequired, errSecDataNotAvailable,
             errSecNotAvailable:
            return .temporarilyUnavailable
        case errSecSuccess:
            guard let data = result as? Data,
                  let password = String(data: data, encoding: .utf8) else {
                throw CredentialStoreError.decodingError
            }
            return .found(password)
        default:
            throw CredentialStoreError.unhandledStatus(status)
        }
    }

    private func deleteCredentialsSynchronously(username: String) throws {
        let context = Self.noninteractiveContext()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username,
            kSecUseAuthenticationContext as String: context
        ]
        let status = SecItemDelete(query as CFDictionary)
        try Self.throwIfMutationFailed(status)
    }

    private static func noninteractiveContext() -> LAContext {
        let context = LAContext()
        context.interactionNotAllowed = true
        return context
    }

    private static func throwIfMutationFailed(_ status: OSStatus) throws {
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        case errSecInteractionNotAllowed, errSecInteractionRequired, errSecDataNotAvailable,
             errSecNotAvailable:
            throw CredentialStoreError.temporarilyUnavailable
        default:
            throw CredentialStoreError.unhandledStatus(status)
        }
    }

    private func performSecurityOperation<T>(
        _ operation: @escaping () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            securityQueue.async {
                do {
                    continuation.resume(returning: try operation())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

actor MockKeychainManager: CredentialStore {
    private var storage: [String: String] = [:]

    func saveCredentials(username: String, password: String) async throws {
        guard !username.isEmpty, !password.isEmpty else {
            throw CredentialStoreError.invalidInput
        }
        storage[username] = password
    }

    func retrievePassword(username: String) async throws -> CredentialLookupResult {
        guard !username.isEmpty else {
            throw CredentialStoreError.invalidInput
        }
        guard let password = storage[username] else {
            return .absent
        }
        return .found(password)
    }

    func deleteCredentials(username: String) async throws {
        guard !username.isEmpty else {
            throw CredentialStoreError.invalidInput
        }
        storage.removeValue(forKey: username)
    }

    func deleteAllCredentials() async throws {
        storage.removeAll()
    }

    func credentialStatus(username: String) async throws -> CredentialExistence {
        guard !username.isEmpty else {
            throw CredentialStoreError.invalidInput
        }
        return storage[username] == nil ? .absent : .present
    }
}
