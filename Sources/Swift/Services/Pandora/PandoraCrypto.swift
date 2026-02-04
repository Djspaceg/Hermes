//
//  PandoraCrypto.swift
//  Hermes
//
//  Pandora API encryption/decryption using Blowfish ECB mode.
//  Pure Swift implementation.
//

import Foundation
import CryptoSwift

// MARK: - Errors

/// Errors that can occur during Pandora encryption/decryption operations
enum CryptoError: Error, LocalizedError {
    case invalidKey
    case invalidHexString
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Invalid encryption key"
        case .invalidHexString:
            return "Invalid hex-encoded string"
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        }
    }
}

// MARK: - PandoraCrypto

/// Pandora API encryption/decryption using Blowfish ECB mode
///
/// The Pandora API uses Blowfish encryption in ECB mode with zero padding.
/// Data is encrypted and returned as a lowercase hex-encoded string.
/// Decryption takes a hex-encoded string and returns the raw decrypted bytes.
enum PandoraCrypto {
    
    // MARK: - Public Methods
    
    /// Encrypt data for Pandora API requests
    ///
    /// - Parameters:
    ///   - data: The data to encrypt
    ///   - key: The encryption key from device configuration
    /// - Returns: Hex-encoded encrypted string (lowercase)
    /// - Throws: `CryptoError` if encryption fails
    static func encrypt(_ data: Data, key: String) throws -> String {
        guard !key.isEmpty else {
            throw CryptoError.invalidKey
        }
        
        do {
            let blowfish = try Blowfish(key: Array(key.utf8), blockMode: ECB(), padding: .zeroPadding)
            let encrypted = try blowfish.encrypt(Array(data))
            return encrypted.toHexString()
        } catch {
            NSLog("PandoraCrypto.encrypt: Encryption failed: \(error)")
            throw CryptoError.encryptionFailed
        }
    }
    
    /// Decrypt data from Pandora API responses
    ///
    /// - Parameters:
    ///   - hexString: The hex-encoded encrypted string
    ///   - key: The decryption key from device configuration
    /// - Returns: Decrypted data
    /// - Throws: `CryptoError` if decryption fails
    static func decrypt(_ hexString: String, key: String) throws -> Data {
        guard !key.isEmpty else {
            throw CryptoError.invalidKey
        }
        
        // Convert hex string to bytes
        guard let encryptedData = hexStringToData(hexString) else {
            throw CryptoError.invalidHexString
        }
        
        do {
            let blowfish = try Blowfish(key: Array(key.utf8), blockMode: ECB(), padding: .zeroPadding)
            let decrypted = try blowfish.decrypt(Array(encryptedData))
            return Data(decrypted)
        } catch {
            throw CryptoError.decryptionFailed
        }
    }
    
    // MARK: - Private Helpers
    
    /// Convert a hex string to Data
    private static func hexStringToData(_ hexString: String) -> Data? {
        let hex = hexString.lowercased()
        
        // Must have even number of characters
        guard hex.count % 2 == 0 else {
            return nil
        }
        
        var data = Data()
        data.reserveCapacity(hex.count / 2)
        
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = String(hex[index..<nextIndex])
            
            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }
            
            data.append(byte)
            index = nextIndex
        }
        
        return data
    }
}
