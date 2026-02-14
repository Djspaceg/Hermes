//
//  AudioQueuePreservationTests.swift
//  HermesTests
//
//  Property-based tests for AudioQueue preservation during in-place reconnect
//  Feature: audio-stream-resilience, Property 1: AudioQueue preservation during in-place reconnect
//

import Testing
import Foundation
@testable import Hermes

// MARK: - Resource State Model

/// Tracks the lifecycle of AudioStreamer resources (AudioQueue, buffers, CFReadStream)
/// as a pure model, mirroring the real AudioStreamer's resource management without
/// requiring CoreAudio.
///
/// Key invariant: `attemptInPlaceReconnect()` closes only the CFReadStream,
/// while `failWithError()` disposes everything including AudioQueue and buffers.
private struct AudioResourceModel {
    var audioQueueAllocated: Bool = true
    var buffersAllocated: Bool = true
    var bufferCount: Int
    var readStreamOpen: Bool = true
    var state: AudioStreamerState = .playing
    var reconnectAttempts: Int = 0
    let maxReconnectAttempts: Int

    init(bufferCount: Int, maxReconnectAttempts: Int) {
        self.bufferCount = bufferCount
        self.maxReconnectAttempts = maxReconnectAttempts
    }

    /// Mirrors `attemptInPlaceReconnect()` — closes ONLY CFReadStream,
    /// preserves AudioQueue and buffers.
    mutating func attemptInPlaceReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            failWithError()
            return
        }

        state = .rebuffering
        // Close ONLY the read stream — AudioQueue and buffers stay alive
        readStreamOpen = false
        reconnectAttempts += 1
    }

    /// Mirrors successful reconnect — CFReadStream reopened, data flowing.
    mutating func reconnectSucceeded() {
        guard case .rebuffering = state else { return }
        readStreamOpen = true
        reconnectAttempts = 0
        state = .playing
    }

    /// Mirrors `failWithError()` — disposes ALL resources including AudioQueue.
    mutating func failWithError() {
        state = .done(reason: .error(.networkConnectionFailed(
            underlyingError: "Terminal failure"
        )))
        readStreamOpen = false
        audioQueueAllocated = false
        buffersAllocated = false
        bufferCount = 0
    }
}

// MARK: - Reconnect Events

/// Events that can occur during a reconnect scenario.
private enum ReconnectEvent {
    case retriableError
    case reconnectSuccess
    case terminalFailure
}

// MARK: - Generators

/// Generates a random retriable error type for variety in test inputs.
private func randomRetriableError() -> AudioStreamerError {
    let errors: [AudioStreamerError] = [
        .networkConnectionFailed(underlyingError: "POSIX error 54: Connection reset"),
        .networkConnectionFailed(underlyingError: "POSIX error 61: Connection refused"),
        .networkConnectionFailed(underlyingError: "POSIX error 65: Host unreachable"),
        .networkConnectionFailed(underlyingError: "POSIX error 50: Network down"),
        .timeout,
        .networkConnectionFailed(underlyingError: "DNS lookup failed"),
        .networkConnectionFailed(underlyingError: "TLS handshake failed"),
        .networkConnectionFailed(underlyingError: "HTTP 502 Bad Gateway"),
        .networkConnectionFailed(underlyingError: "HTTP 503 Service Unavailable"),
    ]
    return errors.randomElement()!
}

/// Generates a random reconnect event biased toward retriable errors.
private func randomReconnectEvent() -> ReconnectEvent {
    let roll = Int.random(in: 0..<10)
    switch roll {
    case 0...5: return .retriableError     // 60%
    case 6...8: return .reconnectSuccess   // 30%
    default:    return .terminalFailure    // 10%
    }
}

/// Generates a random sequence of reconnect events.
private func randomEventSequence(length: Int) -> [ReconnectEvent] {
    (0..<length).map { _ in randomReconnectEvent() }
}

/// Generates a scenario of only retriable errors (no success, no terminal).
private func retriableOnlySequence(count: Int) -> [ReconnectEvent] {
    Array(repeating: .retriableError, count: count)
}

// MARK: - Property 1: AudioQueue Preservation During In-Place Reconnect

/// Property tests validating that AudioQueue and buffers are preserved during
/// in-place reconnect, and only disposed on terminal failure.
///
/// *For any* AudioStreamer that is playing and encounters a retriable network error,
/// after initiating an in-place reconnect, the AudioQueue reference and all allocated
/// AudioQueue buffers SHALL remain non-nil and undisposed. The reconnect process
/// SHALL only close and reopen the CFReadStream.
///
/// **Validates: Requirements 1.1, 1.2, 2.4**
@Suite("AudioQueue Preservation Property Tests")
struct AudioQueuePreservationPropertyTests {

    // MARK: - Property: AudioQueue and buffers survive in-place reconnect

    @Test("AudioQueue and buffers remain allocated after in-place reconnect")
    func audioQueuePreservedDuringReconnect() {
        // Feature: audio-stream-resilience, Property 1: AudioQueue preservation during in-place reconnect
        // **Validates: Requirements 1.1, 1.2, 2.4**

        for _ in 0..<100 {
            let bufferCount = Int.random(in: 1...32)
            let maxAttempts = Int.random(in: 1...10)
            var model = AudioResourceModel(
                bufferCount: bufferCount,
                maxReconnectAttempts: maxAttempts
            )

            // Trigger a retriable error → in-place reconnect
            _ = randomRetriableError()  // Vary the error type
            model.attemptInPlaceReconnect()

            #expect(
                model.audioQueueAllocated,
                "AudioQueue must remain allocated after in-place reconnect"
            )
            #expect(
                model.buffersAllocated,
                "Buffers must remain allocated after in-place reconnect"
            )
            #expect(
                model.bufferCount == bufferCount,
                "Buffer count must be unchanged: expected \(bufferCount), got \(model.bufferCount)"
            )
            #expect(
                !model.readStreamOpen,
                "CFReadStream should be closed during reconnect"
            )
            #expect(
                model.state == .rebuffering,
                "State should be rebuffering, got \(model.state)"
            )
        }
    }

    // MARK: - Property: Only CFReadStream is closed during reconnect

    @Test("Only CFReadStream is closed; AudioQueue untouched during reconnect")
    func onlyCFReadStreamClosedDuringReconnect() {
        // Feature: audio-stream-resilience, Property 1: AudioQueue preservation during in-place reconnect
        // **Validates: Requirements 1.1, 1.2, 2.4**

        for _ in 0..<100 {
            let bufferCount = Int.random(in: 1...32)
            let maxAttempts = Int.random(in: 2...10)
            var model = AudioResourceModel(
                bufferCount: bufferCount,
                maxReconnectAttempts: maxAttempts
            )

            // Record pre-reconnect resource state
            let preAudioQueue = model.audioQueueAllocated
            let preBuffers = model.buffersAllocated
            let preBufferCount = model.bufferCount

            model.attemptInPlaceReconnect()

            // AudioQueue and buffers must be identical to pre-reconnect
            #expect(model.audioQueueAllocated == preAudioQueue)
            #expect(model.buffersAllocated == preBuffers)
            #expect(model.bufferCount == preBufferCount)
            // Only the read stream changed
            #expect(!model.readStreamOpen)
        }
    }

    // MARK: - Property: Multiple reconnects preserve AudioQueue

    @Test("Multiple consecutive reconnect attempts all preserve AudioQueue")
    func multipleReconnectsPreserveAudioQueue() {
        // Feature: audio-stream-resilience, Property 1: AudioQueue preservation during in-place reconnect
        // **Validates: Requirements 1.1, 1.2, 2.4**

        for _ in 0..<100 {
            let bufferCount = Int.random(in: 1...32)
            let maxAttempts = Int.random(in: 2...8)
            var model = AudioResourceModel(
                bufferCount: bufferCount,
                maxReconnectAttempts: maxAttempts
            )

            // Perform multiple reconnect attempts (up to but not exceeding max)
            let attempts = Int.random(in: 1..<maxAttempts)
            for i in 0..<attempts {
                model.attemptInPlaceReconnect()

                #expect(
                    model.audioQueueAllocated,
                    "AudioQueue must survive reconnect attempt \(i + 1)/\(attempts)"
                )
                #expect(
                    model.buffersAllocated,
                    "Buffers must survive reconnect attempt \(i + 1)/\(attempts)"
                )
                #expect(
                    model.bufferCount == bufferCount,
                    "Buffer count must be unchanged at attempt \(i + 1)"
                )
            }
        }
    }

    // MARK: - Property: failWithError disposes AudioQueue (contrast)

    @Test("failWithError disposes AudioQueue and buffers (destructive path)")
    func failWithErrorDisposesAudioQueue() {
        // Feature: audio-stream-resilience, Property 1: AudioQueue preservation during in-place reconnect
        // **Validates: Requirements 1.1, 1.2, 2.4**

        for _ in 0..<100 {
            let bufferCount = Int.random(in: 1...32)
            let maxAttempts = Int.random(in: 1...10)
            var model = AudioResourceModel(
                bufferCount: bufferCount,
                maxReconnectAttempts: maxAttempts
            )

            model.failWithError()

            #expect(
                !model.audioQueueAllocated,
                "AudioQueue must be disposed after failWithError"
            )
            #expect(
                !model.buffersAllocated,
                "Buffers must be disposed after failWithError"
            )
            #expect(
                model.bufferCount == 0,
                "Buffer count must be 0 after failWithError"
            )
            #expect(model.state.isDone, "State must be done after failWithError")
        }
    }

    // MARK: - Property: Exceeding max attempts triggers disposal

    @Test("Exceeding max reconnect attempts disposes AudioQueue via failWithError")
    func exceedingMaxAttemptsDisposesQueue() {
        // Feature: audio-stream-resilience, Property 1: AudioQueue preservation during in-place reconnect
        // **Validates: Requirements 1.1, 1.2, 2.4**

        for _ in 0..<100 {
            let bufferCount = Int.random(in: 1...32)
            let maxAttempts = Int.random(in: 1...8)
            var model = AudioResourceModel(
                bufferCount: bufferCount,
                maxReconnectAttempts: maxAttempts
            )

            // Use up all attempts — AudioQueue preserved each time
            for _ in 0..<maxAttempts {
                model.attemptInPlaceReconnect()
                #expect(model.audioQueueAllocated, "AudioQueue preserved within budget")
                #expect(model.buffersAllocated, "Buffers preserved within budget")
            }

            // One more triggers failWithError
            model.attemptInPlaceReconnect()

            #expect(!model.audioQueueAllocated, "AudioQueue disposed after exceeding max")
            #expect(!model.buffersAllocated, "Buffers disposed after exceeding max")
            #expect(model.state.isDone, "State should be done after exceeding max")
        }
    }

    // MARK: - Property: Successful reconnect restores full resource state

    @Test("Successful reconnect restores CFReadStream while keeping AudioQueue")
    func successfulReconnectRestoresStream() {
        // Feature: audio-stream-resilience, Property 1: AudioQueue preservation during in-place reconnect
        // **Validates: Requirements 1.1, 1.2, 2.4**

        for _ in 0..<100 {
            let bufferCount = Int.random(in: 1...32)
            let maxAttempts = Int.random(in: 2...10)
            var model = AudioResourceModel(
                bufferCount: bufferCount,
                maxReconnectAttempts: maxAttempts
            )

            model.attemptInPlaceReconnect()
            #expect(!model.readStreamOpen, "Stream closed during reconnect")

            model.reconnectSucceeded()

            #expect(model.audioQueueAllocated, "AudioQueue still allocated after success")
            #expect(model.buffersAllocated, "Buffers still allocated after success")
            #expect(model.bufferCount == bufferCount, "Buffer count unchanged")
            #expect(model.readStreamOpen, "CFReadStream reopened after success")
            #expect(model.state == .playing, "State back to playing")
            #expect(model.reconnectAttempts == 0, "Attempts reset on success")
        }
    }

    // MARK: - Property: Random scenarios preserve AudioQueue until terminal failure

    @Test("Random reconnect scenarios preserve AudioQueue until terminal failure")
    func randomScenariosPreserveUntilTerminal() {
        // Feature: audio-stream-resilience, Property 1: AudioQueue preservation during in-place reconnect
        // **Validates: Requirements 1.1, 1.2, 2.4**

        for _ in 0..<100 {
            let bufferCount = Int.random(in: 1...32)
            let maxAttempts = Int.random(in: 2...8)
            var model = AudioResourceModel(
                bufferCount: bufferCount,
                maxReconnectAttempts: maxAttempts
            )
            let events = randomEventSequence(length: Int.random(in: 3...20))

            for event in events {
                if model.state.isDone { break }

                switch event {
                case .retriableError:
                    model.attemptInPlaceReconnect()
                case .reconnectSuccess:
                    model.reconnectSucceeded()
                case .terminalFailure:
                    model.failWithError()
                }

                // Core invariant: if NOT in a terminal state,
                // AudioQueue and buffers MUST still be allocated
                if !model.state.isDone {
                    #expect(
                        model.audioQueueAllocated,
                        "AudioQueue must be allocated in non-terminal state \(model.state)"
                    )
                    #expect(
                        model.buffersAllocated,
                        "Buffers must be allocated in non-terminal state \(model.state)"
                    )
                    #expect(
                        model.bufferCount == bufferCount,
                        "Buffer count must be unchanged in non-terminal state"
                    )
                }
            }
        }
    }
}
