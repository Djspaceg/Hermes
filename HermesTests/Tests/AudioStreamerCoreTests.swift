//
//  AudioStreamerCoreTests.swift
//  HermesTests
//
//  Tests for AudioStreamer core functionality including error handling,
//  configuration, and file type hints.
//  **Validates: Requirements 20.1**
//

import XCTest
import AudioToolbox
@testable import Hermes

final class AudioStreamerCoreTests: XCTestCase {
    
    // MARK: - Test Lifecycle
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - AudioStreamerError Tests
    
    /// Test that all error types have proper descriptions
    func testErrorDescriptions() throws {
        let errors: [AudioStreamerError] = [
            .networkConnectionFailed(underlyingError: "Connection refused"),
            .networkConnectionFailed(underlyingError: nil),
            .fileStreamGetPropertyFailed(status: -50),
            .fileStreamSetPropertyFailed(status: -50),
            .fileStreamSeekFailed(status: -50),
            .fileStreamParseFailed(status: -50),
            .fileStreamOpenFailed(status: -50),
            .fileStreamCloseFailed(status: -50),
            .audioDataNotFound,
            .audioQueueCreationFailed(status: -50),
            .audioQueueBufferAllocationFailed(status: -50),
            .audioQueueEnqueueFailed(status: -50),
            .audioQueueAddListenerFailed(status: -50),
            .audioQueueRemoveListenerFailed(status: -50),
            .audioQueueStartFailed(status: -50),
            .audioQueuePauseFailed(status: -50),
            .audioQueueBufferMismatch,
            .audioQueueDisposeFailed(status: -50),
            .audioQueueStopFailed(status: -50),
            .audioQueueFlushFailed(status: -50),
            .audioStreamerFailed,
            .getAudioTimeFailed(status: -50),
            .audioBufferTooSmall,
            .timeout
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }
    
    /// Test error equality for same error types
    func testErrorEquality() throws {
        // Same errors should be equal
        XCTAssertEqual(
            AudioStreamerError.timeout,
            AudioStreamerError.timeout
        )
        XCTAssertEqual(
            AudioStreamerError.audioDataNotFound,
            AudioStreamerError.audioDataNotFound
        )
        XCTAssertEqual(
            AudioStreamerError.audioStreamerFailed,
            AudioStreamerError.audioStreamerFailed
        )
        XCTAssertEqual(
            AudioStreamerError.audioQueueBufferMismatch,
            AudioStreamerError.audioQueueBufferMismatch
        )
        XCTAssertEqual(
            AudioStreamerError.audioBufferTooSmall,
            AudioStreamerError.audioBufferTooSmall
        )
        
        // Same errors with same parameters should be equal
        XCTAssertEqual(
            AudioStreamerError.networkConnectionFailed(underlyingError: "test"),
            AudioStreamerError.networkConnectionFailed(underlyingError: "test")
        )
        XCTAssertEqual(
            AudioStreamerError.networkConnectionFailed(underlyingError: nil),
            AudioStreamerError.networkConnectionFailed(underlyingError: nil)
        )
        XCTAssertEqual(
            AudioStreamerError.fileStreamOpenFailed(status: -50),
            AudioStreamerError.fileStreamOpenFailed(status: -50)
        )
        XCTAssertEqual(
            AudioStreamerError.audioQueueCreationFailed(status: 100),
            AudioStreamerError.audioQueueCreationFailed(status: 100)
        )
    }
    
    /// Test error inequality for different error types
    func testErrorInequality() throws {
        // Different error types should not be equal
        XCTAssertNotEqual(
            AudioStreamerError.timeout,
            AudioStreamerError.audioDataNotFound
        )
        XCTAssertNotEqual(
            AudioStreamerError.audioStreamerFailed,
            AudioStreamerError.audioBufferTooSmall
        )
        
        // Same error type with different parameters should not be equal
        XCTAssertNotEqual(
            AudioStreamerError.networkConnectionFailed(underlyingError: "error1"),
            AudioStreamerError.networkConnectionFailed(underlyingError: "error2")
        )
        XCTAssertNotEqual(
            AudioStreamerError.networkConnectionFailed(underlyingError: "test"),
            AudioStreamerError.networkConnectionFailed(underlyingError: nil)
        )
        XCTAssertNotEqual(
            AudioStreamerError.fileStreamOpenFailed(status: -50),
            AudioStreamerError.fileStreamOpenFailed(status: -51)
        )
        XCTAssertNotEqual(
            AudioStreamerError.audioQueueCreationFailed(status: 100),
            AudioStreamerError.audioQueueCreationFailed(status: 200)
        )
    }
    
    /// Test error descriptions contain relevant information
    func testErrorDescriptionsContainRelevantInfo() throws {
        // Network error with underlying error should include it
        let networkError = AudioStreamerError.networkConnectionFailed(underlyingError: "Connection refused")
        XCTAssertTrue(
            networkError.errorDescription!.contains("Connection refused"),
            "Network error description should contain underlying error"
        )
        
        // OSStatus errors should include the status code
        let fileStreamError = AudioStreamerError.fileStreamOpenFailed(status: -50)
        XCTAssertTrue(
            fileStreamError.errorDescription!.contains("-50"),
            "File stream error should contain OSStatus code"
        )
        
        let audioQueueError = AudioStreamerError.audioQueueCreationFailed(status: 1234)
        XCTAssertTrue(
            audioQueueError.errorDescription!.contains("1234"),
            "Audio queue error should contain OSStatus code"
        )
    }
    
    // MARK: - Configuration Tests
    
    /// Test default configuration values
    func testDefaultConfiguration() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Verify default values
        XCTAssertEqual(streamer.bufferCount, kDefaultNumAQBufs, "Default buffer count should be \(kDefaultNumAQBufs)")
        XCTAssertEqual(streamer.bufferSize, kDefaultAQDefaultBufSize, "Default buffer size should be \(kDefaultAQDefaultBufSize)")
        XCTAssertFalse(streamer.bufferInfinite, "Buffer infinite should be false by default")
        XCTAssertEqual(streamer.timeoutInterval, 10, "Default timeout should be 10 seconds")
        XCTAssertNil(streamer.fileType, "File type should be nil by default")
        
        streamer.stop()
    }
    
    /// Test configuration can be modified before start
    func testConfigurationModification() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Modify configuration
        streamer.bufferCount = 32
        streamer.bufferSize = 4096
        streamer.bufferInfinite = true
        streamer.timeoutInterval = 30
        
        // Verify modifications
        XCTAssertEqual(streamer.bufferCount, 32)
        XCTAssertEqual(streamer.bufferSize, 4096)
        XCTAssertTrue(streamer.bufferInfinite)
        XCTAssertEqual(streamer.timeoutInterval, 30)
        
        streamer.stop()
    }
    
    /// Test URL is correctly stored
    func testURLStorage() throws {
        let testURL = URL(string: "http://example.com/test.mp3")!
        let streamer = AudioStreamer(url: testURL)
        
        XCTAssertEqual(streamer.url, testURL, "URL should be stored correctly")
        
        streamer.stop()
    }
    
    /// Test factory method creates streamer correctly
    func testFactoryMethod() throws {
        let testURL = URL(string: "http://example.com/test.mp3")!
        let streamer = AudioStreamer.stream(with: testURL)
        
        XCTAssertEqual(streamer.url, testURL, "Factory method should create streamer with correct URL")
        XCTAssertEqual(streamer.state, .initialized, "Factory method should create streamer in initialized state")
        
        streamer.stop()
    }
    
    // MARK: - Proxy Configuration Tests
    
    /// Test HTTP proxy configuration
    func testHTTPProxyConfiguration() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Setting proxy should not crash
        streamer.setHTTPProxy(host: "proxy.example.com", port: 8080)
        
        // Streamer should still be in initialized state
        XCTAssertEqual(streamer.state, .initialized)
        
        streamer.stop()
    }
    
    /// Test SOCKS proxy configuration
    func testSOCKSProxyConfiguration() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Setting proxy should not crash
        streamer.setSOCKSProxy(host: "socks.example.com", port: 1080)
        
        // Streamer should still be in initialized state
        XCTAssertEqual(streamer.state, .initialized)
        
        streamer.stop()
    }
    
    // MARK: - Initial State Tests
    
    /// Test initial state properties
    func testInitialStateProperties() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Initial state checks
        XCTAssertEqual(streamer.state, .initialized)
        XCTAssertFalse(streamer.isPlaying)
        XCTAssertFalse(streamer.isPaused)
        XCTAssertFalse(streamer.isWaiting)
        XCTAssertFalse(streamer.isDone)
        XCTAssertNil(streamer.doneReason)
        XCTAssertNil(streamer.httpHeaders)
        
        streamer.stop()
    }
    
    /// Test progress and duration return nil before streaming
    func testProgressAndDurationBeforeStreaming() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Progress and duration should be nil before streaming starts
        XCTAssertNil(streamer.progress(), "Progress should be nil before streaming")
        XCTAssertNil(streamer.duration(), "Duration should be nil before streaming")
        XCTAssertNil(streamer.calculatedBitRate(), "Bit rate should be nil before streaming")
        
        streamer.stop()
    }
    
    /// Test volume setting before audio queue is ready
    func testVolumeSettingBeforeAudioQueue() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Setting volume before audio queue should return false
        let result = streamer.setVolume(0.5)
        XCTAssertFalse(result, "setVolume should return false when audio queue is not ready")
        
        streamer.stop()
    }
    
    /// Test seek before streaming
    func testSeekBeforeStreaming() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Seeking before streaming should return false
        let result = streamer.seekToTime(30.0)
        XCTAssertFalse(result, "seekToTime should return false before streaming")
        
        streamer.stop()
    }
    
    // MARK: - Constants Tests
    
    /// Test that constants have expected values
    func testConstants() throws {
        XCTAssertEqual(kAQMaxPacketDescs, 512, "kAQMaxPacketDescs should be 512")
        XCTAssertEqual(kDefaultNumAQBufs, 32, "kDefaultNumAQBufs should be 32")
        XCTAssertEqual(kDefaultAQDefaultBufSize, 4096, "kDefaultAQDefaultBufSize should be 4096")
        XCTAssertEqual(kBitRateEstimationMinPackets, 50, "kBitRateEstimationMinPackets should be 50")
    }
}
