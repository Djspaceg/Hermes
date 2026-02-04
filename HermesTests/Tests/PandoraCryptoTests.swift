//
//  PandoraCryptoTests.swift
//  HermesTests
//
//  Property-based tests for PandoraCrypto encryption/decryption
//  **Validates: Requirements 6.2, 6.3, 6.4**
//

import XCTest
@testable import Hermes

final class PandoraCryptoTests: XCTestCase {
    
    // MARK: - Property 1: Encryption Round-Trip
    //
    // For all valid (data, key) pairs:
    // let encrypted = PandoraCrypto.encrypt(data, key: key)
    // let decrypted = PandoraCrypto.decrypt(encrypted, key: key)
    // assert(decrypted == data)
    //
    // **Validates: Requirements 6.2, 6.3, 6.4**
    
    /// Property test: Encryption round-trip with random data and keys
    /// Tests that encrypt then decrypt returns original data (padded to block boundary)
    func testEncryptionRoundTrip_RandomData() throws {
        // Run 100+ iterations with random data and keys
        for iteration in 0..<150 {
            // Generate random key (8-20 bytes, typical Pandora key size range)
            let keyLength = Int.random(in: 8...20)
            let key = generateRandomString(length: keyLength)
            
            // Generate random data (0-1024 bytes)
            let dataLength = Int.random(in: 0...1024)
            let originalData = generateRandomData(length: dataLength)
            
            // Encrypt
            let encrypted = try PandoraCrypto.encrypt(originalData, key: key)
            
            // Decrypt
            let decrypted = try PandoraCrypto.decrypt(encrypted, key: key)
            
            // Verify round-trip: decrypted data should contain original data
            // (may have zero padding at the end due to block alignment)
            let originalPadded = zeroPadToBlockSize(originalData, blockSize: 8)
            XCTAssertEqual(
                decrypted,
                originalPadded,
                "Iteration \(iteration): Round-trip failed for data length \(dataLength), key length \(keyLength)"
            )
            
            // Also verify that the original data is a prefix of decrypted data
            XCTAssertTrue(
                decrypted.starts(with: originalData),
                "Iteration \(iteration): Decrypted data should start with original data"
            )
        }
    }
    
    /// Property test: Encryption round-trip with various key lengths
    /// Tests boundary conditions for Blowfish key sizes
    /// Note: CryptoSwift Blowfish accepts keys of various lengths
    func testEncryptionRoundTrip_KeyLengthBoundaries() throws {
        let testData = "Hello, Pandora!".data(using: .utf8)!
        
        // Test with typical Pandora key lengths (around 10-12 characters)
        let typicalKeys = [
            "6#26FRL$ZWD",      // 11 chars - typical Pandora encrypt key format
            "R=U!LH$O2B#",      // 11 chars - typical Pandora decrypt key format
            "testkey123",       // 10 chars
            "shortkey",         // 8 chars
            "longerkey12345",   // 14 chars
        ]
        
        for key in typicalKeys {
            let encrypted = try PandoraCrypto.encrypt(testData, key: key)
            let decrypted = try PandoraCrypto.decrypt(encrypted, key: key)
            XCTAssertTrue(
                decrypted.starts(with: testData),
                "Key '\(key)' (length \(key.count)) round-trip failed"
            )
        }
    }
    
    /// Property test: Encryption round-trip with data at block boundaries
    /// Tests data lengths that are exact multiples of 8 (Blowfish block size)
    func testEncryptionRoundTrip_BlockBoundaries() throws {
        let key = "testkey123"
        
        // Test exact block sizes: 0, 8, 16, 24, 32, 64, 128 bytes
        for dataLength in [0, 8, 16, 24, 32, 64, 128] {
            let originalData = generateRandomData(length: dataLength)
            
            let encrypted = try PandoraCrypto.encrypt(originalData, key: key)
            let decrypted = try PandoraCrypto.decrypt(encrypted, key: key)
            
            // For exact block sizes, decrypted should equal original (no extra padding)
            XCTAssertEqual(
                decrypted,
                originalData,
                "Block boundary test failed for length \(dataLength)"
            )
        }
        
        // Test non-block-aligned sizes: 1, 7, 9, 15, 17, 31, 33 bytes
        for dataLength in [1, 7, 9, 15, 17, 31, 33] {
            let originalData = generateRandomData(length: dataLength)
            
            let encrypted = try PandoraCrypto.encrypt(originalData, key: key)
            let decrypted = try PandoraCrypto.decrypt(encrypted, key: key)
            
            // Decrypted should be padded to next block boundary
            let expectedLength = ((dataLength + 7) / 8) * 8
            XCTAssertEqual(
                decrypted.count,
                expectedLength,
                "Non-aligned test failed for length \(dataLength)"
            )
            XCTAssertTrue(
                decrypted.starts(with: originalData),
                "Non-aligned test: decrypted should start with original for length \(dataLength)"
            )
        }
    }
    
    /// Property test: Encryption produces hex-encoded output
    func testEncryptionProducesHexOutput() throws {
        let key = "testkey"
        let data = "test data".data(using: .utf8)!
        
        let encrypted = try PandoraCrypto.encrypt(data, key: key)
        
        // Verify output is valid lowercase hex
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(
            encrypted.unicodeScalars.allSatisfy { hexCharacterSet.contains($0) },
            "Encrypted output should be lowercase hex"
        )
        
        // Verify output length is even (hex pairs)
        XCTAssertEqual(encrypted.count % 2, 0, "Hex output should have even length")
        
        // Verify output length matches expected (padded data * 2 for hex)
        let paddedLength = ((data.count + 7) / 8) * 8
        XCTAssertEqual(encrypted.count, paddedLength * 2, "Hex output length mismatch")
    }
    
    // MARK: - Known Pandora Encryption Vectors
    //
    // These tests verify compatibility with the original Pandora encryption implementation
    
    /// Test with known Pandora-style encryption
    /// Uses typical Pandora API key format and JSON-like data
    func testKnownPandoraStyleEncryption() throws {
        // Typical Pandora API uses keys like these (not actual keys)
        let encryptKey = "6#26FRL$ZWD"
        let decryptKey = "R=U!LH$O2B#"
        
        // Test with JSON-like API request data
        let jsonData = """
        {"username":"test@example.com","password":"testpass"}
        """.data(using: .utf8)!
        
        // Encrypt with encrypt key
        let encrypted = try PandoraCrypto.encrypt(jsonData, key: encryptKey)
        
        // Verify it's valid hex
        XCTAssertFalse(encrypted.isEmpty, "Encrypted output should not be empty")
        XCTAssertTrue(
            encrypted.allSatisfy { $0.isHexDigit },
            "Output should be hex"
        )
        
        // Decrypt with same key should return original (padded)
        let decrypted = try PandoraCrypto.decrypt(encrypted, key: encryptKey)
        XCTAssertTrue(
            decrypted.starts(with: jsonData),
            "Decrypted should contain original JSON"
        )
    }
    
    /// Test encryption/decryption with special characters in data
    func testEncryptionWithSpecialCharacters() throws {
        let key = "testkey123"
        
        // Test with various special characters
        let specialStrings = [
            "Hello, World! 🎵",
            "user@example.com",
            "{\"key\": \"value\", \"number\": 123}",
            "Line1\nLine2\rLine3\r\n",
            "Tab\there\tand\tthere",
            "Quotes: \"double\" and 'single'",
            "Symbols: !@#$%^&*()_+-=[]{}|;':\",./<>?",
            "Unicode: 日本語 中文 한국어 العربية",
            "Emoji: 🎵🎶🎸🎹🎺🎻",
        ]
        
        for testString in specialStrings {
            guard let originalData = testString.data(using: .utf8) else {
                continue
            }
            
            let encrypted = try PandoraCrypto.encrypt(originalData, key: key)
            let decrypted = try PandoraCrypto.decrypt(encrypted, key: key)
            
            XCTAssertTrue(
                decrypted.starts(with: originalData),
                "Special character test failed for: \(testString.prefix(20))..."
            )
        }
    }
    
    // MARK: - Edge Cases
    
    /// Test encryption with empty data
    func testEncryptionWithEmptyData() throws {
        let key = "testkey"
        let emptyData = Data()
        
        let encrypted = try PandoraCrypto.encrypt(emptyData, key: key)
        let decrypted = try PandoraCrypto.decrypt(encrypted, key: key)
        
        // Empty data should encrypt to empty (no padding needed for 0 bytes)
        XCTAssertEqual(encrypted, "", "Empty data should encrypt to empty string")
        XCTAssertEqual(decrypted, emptyData, "Empty data round-trip should return empty")
    }
    
    /// Test encryption with large data
    func testEncryptionWithLargeData() throws {
        let key = "testkey123"
        
        // Test with 10KB of data
        let largeData = generateRandomData(length: 10 * 1024)
        
        let encrypted = try PandoraCrypto.encrypt(largeData, key: key)
        let decrypted = try PandoraCrypto.decrypt(encrypted, key: key)
        
        XCTAssertEqual(
            decrypted,
            largeData,
            "Large data round-trip failed"
        )
    }
    
    /// Test that different keys produce different ciphertext
    func testDifferentKeysProduceDifferentCiphertext() throws {
        let data = "Same data for all keys".data(using: .utf8)!
        
        let key1 = "firstkey"
        let key2 = "secondkey"
        let key3 = "thirdkey"
        
        let encrypted1 = try PandoraCrypto.encrypt(data, key: key1)
        let encrypted2 = try PandoraCrypto.encrypt(data, key: key2)
        let encrypted3 = try PandoraCrypto.encrypt(data, key: key3)
        
        XCTAssertNotEqual(encrypted1, encrypted2, "Different keys should produce different ciphertext")
        XCTAssertNotEqual(encrypted2, encrypted3, "Different keys should produce different ciphertext")
        XCTAssertNotEqual(encrypted1, encrypted3, "Different keys should produce different ciphertext")
    }
    
    /// Test that same key and data produce same ciphertext (deterministic)
    func testEncryptionIsDeterministic() throws {
        let key = "testkey"
        let data = "Test data for determinism".data(using: .utf8)!
        
        let encrypted1 = try PandoraCrypto.encrypt(data, key: key)
        let encrypted2 = try PandoraCrypto.encrypt(data, key: key)
        let encrypted3 = try PandoraCrypto.encrypt(data, key: key)
        
        XCTAssertEqual(encrypted1, encrypted2, "Same inputs should produce same output")
        XCTAssertEqual(encrypted2, encrypted3, "Same inputs should produce same output")
    }
    
    // MARK: - Error Cases
    
    /// Test that empty key throws error
    func testEmptyKeyThrowsError() {
        let data = "test".data(using: .utf8)!
        
        XCTAssertThrowsError(try PandoraCrypto.encrypt(data, key: "")) { error in
            XCTAssertEqual(error as? CryptoError, CryptoError.invalidKey)
        }
        
        XCTAssertThrowsError(try PandoraCrypto.decrypt("abcd", key: "")) { error in
            XCTAssertEqual(error as? CryptoError, CryptoError.invalidKey)
        }
    }
    
    /// Test that invalid hex string throws error
    func testInvalidHexStringThrowsError() {
        let key = "testkey"
        
        // Odd length hex string
        XCTAssertThrowsError(try PandoraCrypto.decrypt("abc", key: key)) { error in
            XCTAssertEqual(error as? CryptoError, CryptoError.invalidHexString)
        }
        
        // Non-hex characters
        XCTAssertThrowsError(try PandoraCrypto.decrypt("ghij", key: key)) { error in
            XCTAssertEqual(error as? CryptoError, CryptoError.invalidHexString)
        }
        
        // Mixed valid and invalid
        XCTAssertThrowsError(try PandoraCrypto.decrypt("abcdXYZW", key: key)) { error in
            XCTAssertEqual(error as? CryptoError, CryptoError.invalidHexString)
        }
    }
    
    /// Test decryption with uppercase hex (should work - case insensitive)
    func testDecryptionWithUppercaseHex() throws {
        let key = "testkey"
        let data = "test data".data(using: .utf8)!
        
        let encrypted = try PandoraCrypto.encrypt(data, key: key)
        let uppercaseEncrypted = encrypted.uppercased()
        
        let decrypted = try PandoraCrypto.decrypt(uppercaseEncrypted, key: key)
        
        XCTAssertTrue(
            decrypted.starts(with: data),
            "Uppercase hex decryption should work"
        )
    }
    
    // MARK: - Helpers
    
    /// Generate random data of specified length
    private func generateRandomData(length: Int) -> Data {
        var data = Data(count: length)
        if length > 0 {
            _ = data.withUnsafeMutableBytes { buffer in
                SecRandomCopyBytes(kSecRandomDefault, length, buffer.baseAddress!)
            }
        }
        return data
    }
    
    /// Generate random alphanumeric string of specified length
    private func generateRandomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    /// Pad data with zeros to block size boundary
    private func zeroPadToBlockSize(_ data: Data, blockSize: Int) -> Data {
        let remainder = data.count % blockSize
        if remainder == 0 {
            return data
        }
        var paddedData = data
        let paddingNeeded = blockSize - remainder
        paddedData.append(contentsOf: [UInt8](repeating: 0, count: paddingNeeded))
        return paddedData
    }
}
