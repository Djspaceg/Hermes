//
//  AudioStreamerCoreTests.swift
//  HermesTests
//
//  Tests for AudioStreamer core functionality including error handling,
//  configuration, and file type hints.
//  **Validates: Requirements 20.1**
//

import Testing
import Foundation
import AudioToolbox
@testable import Hermes

@Suite("AudioStreamerCoreTests", .serialized)
struct AudioStreamerCoreTests {
    // MARK: - AudioStreamerError Tests
    
    /// Test that all error types have proper descriptions
    @Test("Error Descriptions")
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
            #expect((error.errorDescription) != nil, "Error \(error) should have a description")
            #expect(!(error.errorDescription!.isEmpty), "Error description should not be empty")
        }
    }
    
    /// Test error equality for same error types
    @Test("Error Equality")
    func testErrorEquality() throws {
        // Same errors should be equal
        #expect((AudioStreamerError.timeout) == (AudioStreamerError.timeout))
        #expect((AudioStreamerError.audioDataNotFound) == (AudioStreamerError.audioDataNotFound))
        #expect((AudioStreamerError.audioStreamerFailed) == (AudioStreamerError.audioStreamerFailed))
        #expect((AudioStreamerError.audioQueueBufferMismatch) == (AudioStreamerError.audioQueueBufferMismatch))
        #expect((AudioStreamerError.audioBufferTooSmall) == (AudioStreamerError.audioBufferTooSmall))
        
        // Same errors with same parameters should be equal
        #expect((AudioStreamerError.networkConnectionFailed(underlyingError: "test")) == (AudioStreamerError.networkConnectionFailed(underlyingError: "test")))
        #expect((AudioStreamerError.networkConnectionFailed(underlyingError: nil)) == (AudioStreamerError.networkConnectionFailed(underlyingError: nil)))
        #expect((AudioStreamerError.fileStreamOpenFailed(status: -50)) == (AudioStreamerError.fileStreamOpenFailed(status: -50)))
        #expect((AudioStreamerError.audioQueueCreationFailed(status: 100)) == (AudioStreamerError.audioQueueCreationFailed(status: 100)))
    }
    
    /// Test error inequality for different error types
    @Test("Error Inequality")
    func testErrorInequality() throws {
        // Different error types should not be equal
        #expect((AudioStreamerError.timeout) != (AudioStreamerError.audioDataNotFound))
        #expect((AudioStreamerError.audioStreamerFailed) != (AudioStreamerError.audioBufferTooSmall))
        
        // Same error type with different parameters should not be equal
        #expect((AudioStreamerError.networkConnectionFailed(underlyingError: "error1")) != (AudioStreamerError.networkConnectionFailed(underlyingError: "error2")))
        #expect((AudioStreamerError.networkConnectionFailed(underlyingError: "test")) != (AudioStreamerError.networkConnectionFailed(underlyingError: nil)))
        #expect((AudioStreamerError.fileStreamOpenFailed(status: -50)) != (AudioStreamerError.fileStreamOpenFailed(status: -51)))
        #expect((AudioStreamerError.audioQueueCreationFailed(status: 100)) != (AudioStreamerError.audioQueueCreationFailed(status: 200)))
    }
    
    /// Test error descriptions contain relevant information
    @Test("Error Descriptions Contain Relevant Info")
    func testErrorDescriptionsContainRelevantInfo() throws {
        // Network error with underlying error should include it
        let networkError = AudioStreamerError.networkConnectionFailed(underlyingError: "Connection refused")
        #expect(networkError.errorDescription!.contains("Connection refused"), "Network error description should contain underlying error")
        
        // OSStatus errors should include the status code
        let fileStreamError = AudioStreamerError.fileStreamOpenFailed(status: -50)
        #expect(fileStreamError.errorDescription!.contains("-50"), "File stream error should contain OSStatus code")
        
        let audioQueueError = AudioStreamerError.audioQueueCreationFailed(status: 1234)
        #expect(audioQueueError.errorDescription!.contains("1234"), "Audio queue error should contain OSStatus code")
    }
    
    // MARK: - Configuration Tests
    
    /// Test default configuration values
    @Test("Default Configuration")
    func testDefaultConfiguration() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Verify default values
        #expect((streamer.bufferCount) == (kDefaultNumAQBufs), "Default buffer count should be \(kDefaultNumAQBufs)")
        #expect((streamer.bufferSize) == (kDefaultAQDefaultBufSize), "Default buffer size should be \(kDefaultAQDefaultBufSize)")
        #expect(!(streamer.bufferInfinite), "Buffer infinite should be false by default")
        #expect((streamer.timeoutInterval) == (10), "Default timeout should be 10 seconds")
        #expect((streamer.fileType) == nil, "File type should be nil by default")
        
        streamer.stop()
    }
    
    /// Test configuration can be modified before start
    @Test("Configuration Modification")
    func testConfigurationModification() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Modify configuration
        streamer.bufferCount = 32
        streamer.bufferSize = 4096
        streamer.bufferInfinite = true
        streamer.timeoutInterval = 30
        
        // Verify modifications
        #expect((streamer.bufferCount) == (32))
        #expect((streamer.bufferSize) == (4096))
        #expect(streamer.bufferInfinite)
        #expect((streamer.timeoutInterval) == (30))
        
        streamer.stop()
    }
    
    /// Test URL is correctly stored
    @Test("URL Storage")
    func testURLStorage() throws {
        let testURL = URL(string: "http://example.com/test.mp3")!
        let streamer = AudioStreamer(url: testURL)
        
        #expect((streamer.url) == (testURL), "URL should be stored correctly")
        
        streamer.stop()
    }
    
    /// Test factory method creates streamer correctly
    @Test("Factory Method")
    func testFactoryMethod() throws {
        let testURL = URL(string: "http://example.com/test.mp3")!
        let streamer = AudioStreamer.stream(with: testURL)
        
        #expect((streamer.url) == (testURL), "Factory method should create streamer with correct URL")
        #expect((streamer.state) == (.initialized), "Factory method should create streamer in initialized state")
        
        streamer.stop()
    }
    
    // MARK: - Proxy Configuration Tests
    
    /// Test HTTP proxy configuration
    @Test("HTTP Proxy Configuration")
    func testHTTPProxyConfiguration() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Setting proxy should not crash
        streamer.setHTTPProxy(host: "proxy.example.com", port: 8080)
        
        // Streamer should still be in initialized state
        #expect((streamer.state) == (.initialized))
        
        streamer.stop()
    }
    
    /// Test SOCKS proxy configuration
    @Test("SOCKS Proxy Configuration")
    func testSOCKSProxyConfiguration() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Setting proxy should not crash
        streamer.setSOCKSProxy(host: "socks.example.com", port: 1080)
        
        // Streamer should still be in initialized state
        #expect((streamer.state) == (.initialized))
        
        streamer.stop()
    }
    
    // MARK: - Initial State Tests
    
    /// Test initial state properties
    @Test("Initial State Properties")
    func testInitialStateProperties() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Initial state checks
        #expect((streamer.state) == (.initialized))
        #expect(!(streamer.isPlaying))
        #expect(!(streamer.isPaused))
        #expect(!(streamer.isWaiting))
        #expect(!(streamer.isDone))
        #expect((streamer.doneReason) == nil)
        #expect((streamer.httpHeaders) == nil)
        
        streamer.stop()
    }
    
    /// Test progress and duration return nil before streaming
    @Test("Progress And Duration Before Streaming")
    func testProgressAndDurationBeforeStreaming() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Progress and duration should be nil before streaming starts
        #expect((streamer.progress()) == nil, "Progress should be nil before streaming")
        #expect((streamer.duration()) == nil, "Duration should be nil before streaming")
        #expect((streamer.calculatedBitRate()) == nil, "Bit rate should be nil before streaming")
        
        streamer.stop()
    }

    @Test("Normal URLSession completion enables drained-buffer termination")
    func testNormalCompletionClearsTaskForDrainedBufferPath() {
        let session = URLSession(configuration: .ephemeral)
        let url = URL(string: "https://example.invalid/audio.mp3")!
        let task = session.dataTask(with: url)
        let streamer = AudioStreamer(url: url)

        defer {
            streamer.stop()
            session.invalidateAndCancel()
        }

        streamer.dataTask = task
        streamer.buffersUsed = 1
        streamer.urlSession(session, task: task, didCompleteWithError: nil)

        // A queued final buffer keeps the terminal predicate false.
        #expect(streamer.queuedPackets.isEmpty)
        #expect(!streamer.hasDrainedCompletedInput())

        // This models the final buffer completion on the production buffer path.
        streamer.buffersUsed = 0
        #expect(
            streamer.hasDrainedCompletedInput(),
            "Normal completion plus final-buffer drain must reach the clean EOF predicate"
        )
    }

    @Test("Normal URLSession completion preserves cached-packet enqueueing")
    func testNormalCompletionAllowsCachedPacketsToDrainAfterTaskClears() {
        let session = URLSession(configuration: .ephemeral)
        let url = URL(string: "https://example.invalid/audio.mp3")!
        let task = session.dataTask(with: url)
        let streamer = AudioStreamer(url: url)

        defer {
            streamer.stop()
            session.invalidateAndCancel()
        }

        streamer.dataTask = task
        streamer.queuedPackets = [
            QueuedPacketData(
                description: AudioStreamPacketDescription(),
                data: Data([0])
            )
        ]
        streamer.urlSession(session, task: task, didCompleteWithError: nil)

        #expect(streamer.dataTask == nil)
        #expect(
            streamer.canEnqueueBufferedInput(),
            "Normal completion must not strand cached packets after clearing the task"
        )
        #expect(
            !streamer.hasDrainedCompletedInput(),
            "Cached packets must prevent clean EOF until they drain"
        )

        streamer.queuedPackets.removeAll()
        #expect(streamer.hasDrainedCompletedInput())
    }

    @Test("Cached packets flush their final partial buffer after normal completion")
    func testCachedPacketDrainEnqueuesFinalPartialBufferAfterCompletion() {
        let session = URLSession(configuration: .ephemeral)
        let url = URL(string: "https://example.invalid/audio.mp3")!
        let task = session.dataTask(with: url)
        let streamer = AudioStreamer(url: url)

        defer {
            streamer.stop()
            session.invalidateAndCancel()
        }

        streamer.dataTask = task
        streamer.queuedPackets = [
            QueuedPacketData(
                description: AudioStreamPacketDescription(),
                data: Data([0])
            )
        ]
        streamer.urlSession(session, task: task, didCompleteWithError: nil)
        streamer.bytesFilled = 1

        #expect(
            !streamer.needsFinalBufferEnqueueAfterCachedPacketDrain(),
            "Cached packets must drain before their final partial buffer flushes"
        )

        streamer.queuedPackets.removeAll()
        #expect(
            streamer.needsFinalBufferEnqueueAfterCachedPacketDrain(),
            "The remaining partial buffer must be enqueued once cached packets drain"
        )

        streamer.bytesFilled = 0
        #expect(!streamer.needsFinalBufferEnqueueAfterCachedPacketDrain())
    }

    @Test("Incomplete stream drain still triggers in-place reconnect")
    func testIncompleteStreamDrainStillTriggersReconnect() {
        let streamer = AudioStreamer(
            url: URL(string: "https://example.invalid/audio.mp3")!
        )

        defer {
            streamer.stop()
        }

        streamer.bufferCount = 4
        streamer.bitrateNotificationSent = true
        streamer.stallDetector = StallDetector(
            highMark: 0.75,
            lowMark: 0.40,
            debounceCount: 1
        )
        streamer.setState(.playing)

        streamer.buffersUsed = 3
        streamer.checkBufferHealth()

        streamer.buffersUsed = 1
        streamer.checkBufferHealth()

        #expect(
            streamer.state == .rebuffering,
            "An incomplete stream that drains below the low-water mark must reconnect"
        )
    }
    
    /// Test volume setting before audio queue is ready
    @Test("Volume Setting Before Audio Queue")
    func testVolumeSettingBeforeAudioQueue() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Setting volume before audio queue should return false
        let result = streamer.setVolume(0.5)
        #expect(!(result), "setVolume should return false when audio queue is not ready")
        
        streamer.stop()
    }
    
    /// Test seek before streaming
    @Test("Seek Before Streaming")
    func testSeekBeforeStreaming() throws {
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // Seeking before streaming should return false
        let result = streamer.seekToTime(30.0)
        #expect(!(result), "seekToTime should return false before streaming")
        
        streamer.stop()
    }
    
    // MARK: - Constants Tests
    
    /// Test that constants have expected values
    @Test("Constants")
    func testConstants() throws {
        #expect((kAQMaxPacketDescs) == (512), "kAQMaxPacketDescs should be 512")
        #expect((kDefaultNumAQBufs) == (32), "kDefaultNumAQBufs should be 32")
        #expect((kDefaultAQDefaultBufSize) == (4096), "kDefaultAQDefaultBufSize should be 4096")
        #expect((kBitRateEstimationMinPackets) == (50), "kBitRateEstimationMinPackets should be 50")
    }
}
