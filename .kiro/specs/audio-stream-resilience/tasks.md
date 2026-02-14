# Implementation Plan: Audio Stream Resilience

## Overview

This plan implements the audio streaming resilience overhaul in incremental steps, starting with pure value types (ErrorClassifier, BackoffStrategy, StallDetector), then modifying AudioStreamerState, then wiring the reconnection logic into AudioStreamer, and finally updating Playlist. Each step builds on the previous and includes property/unit tests as sub-tasks.

## Tasks

- [x] 1. Implement ErrorClassifier
  - [x] 1.1 Create `Sources/Swift/Services/Audio/ErrorClassifier.swift` with `NetworkErrorCategory` enum and `ErrorClassifier` struct
    - Implement `classify(_ error: Error) -> NetworkErrorCategory` handling POSIX codes 50, 54, 61, 65, DNS failures, TLS failures, CFNetwork timeouts
    - Implement `classifyHTTPStatus(_ statusCode: Int) -> NetworkErrorCategory` handling 5xx as retriable, 4xx as non-retriable (except 408, 429)
    - _Requirements: 4.1, 4.2_
  - [x] 1.2 Write property test for ErrorClassifier
    - **Property 4: Error classification correctness**
    - Generate random POSIX error codes, HTTP status codes; verify classification matches spec and is deterministic
    - **Validates: Requirements 4.1, 4.2**
  - [x] 1.3 Write unit tests for ErrorClassifier
    - Test specific known error codes: POSIX 54, 61, 65, 50 → retriable; HTTP 404, 403 → non-retriable; HTTP 408, 429, 500, 502, 503 → retriable
    - _Requirements: 4.1, 4.2_

- [x] 2. Implement BackoffStrategy
  - [x] 2.1 Create `Sources/Swift/Services/Audio/BackoffStrategy.swift` with `BackoffStrategy` struct
    - Implement `delay(forAttempt:)` using `min(baseDelay * 2^attempt, maxDelay) + random jitter in [0, jitterRange)`
    - Add `static let streamerDefault` (base: 0.5, max: 16, jitter: 0.5) and `static let playlistDefault` (base: 1.0, max: 30, jitter: 1.0)
    - _Requirements: 5.1, 5.2, 5.3_
  - [x] 2.2 Write property test for BackoffStrategy
    - **Property 5: Backoff delay bounds**
    - Generate random attempt numbers and configurations; verify delay is in [min(base*2^attempt, max), min(base*2^attempt, max) + jitterRange)
    - **Validates: Requirements 5.1**
  - [x] 2.3 Write unit tests for BackoffStrategy
    - Test attempt 0 returns baseDelay + jitter range, test cap at maxDelay, test default configurations match specified values
    - _Requirements: 5.1, 5.2, 5.3_

- [x] 3. Implement StallDetector
  - [x] 3.1 Create `Sources/Swift/Services/Audio/StallDetector.swift` with `StallDetector` struct
    - Implement `mutating func evaluate(fillRatio:hasQueuedPackets:isReconnecting:) -> Bool` with hysteresis logic (highMark: 0.75, lowMark: 0.25)
    - Implement `mutating func reset()` to clear armed state
    - _Requirements: 3.2, 3.3, 3.4_
  - [x] 3.2 Write property test for StallDetector
    - **Property 3: StallDetector hysteresis correctness**
    - Generate random sequences of fill ratios; verify arming, triggering, and reconnect-guard behavior
    - **Validates: Requirements 3.2, 3.3, 3.4**
  - [x] 3.3 Write unit tests for StallDetector
    - Test: not armed initially, arms at 0.75, does not trigger at 0.25 when not armed, triggers when armed and below 0.25, does not trigger when isReconnecting is true, reset clears armed state
    - _Requirements: 3.2, 3.3, 3.4_

- [x] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Update AudioStreamerState and AudioStreamError
  - [x] 5.1 Add `rebuffering` case to `AudioStreamerState` in `AudioStreamState.swift`
    - Update `isDone` to return false for rebuffering
    - Update `isWaiting` to return false for rebuffering
    - Add `isRebuffering` computed property
    - _Requirements: 2.1_
  - [x] 5.2 Add `isRetriable` computed property to `AudioStreamerError` in `AudioStreamError.swift`
    - Return true for `.networkConnectionFailed` and `.timeout`
    - _Requirements: 4.3, 4.4_
  - [x] 5.3 Update existing `AudioStreamerStateTests.swift` for rebuffering state
    - Verify rebuffering is not done, not waiting, is rebuffering
    - _Requirements: 2.1_

- [x] 6. Implement in-place reconnection in AudioStreamer
  - [x] 6.1 Add reconnection state fields to AudioStreamer
    - Add `reconnectAttempts`, `maxReconnectAttempts` (5), `streamerBackoff` (BackoffStrategy.streamerDefault), `stallDetector`, `lastFillRatio`, `reconnectTimer`
    - _Requirements: 1.1, 5.5_
  - [x] 6.2 Implement `attemptInPlaceReconnect()` method
    - Close CFReadStream only (not AudioQueue), set state to rebuffering, compute byte offset from progress, schedule reconnect with backoff delay, reopen stream with Range header
    - On success (data arrives): transition to playing, reset reconnectAttempts
    - On max retries exceeded: call failWithError
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.2, 2.3, 5.4, 5.5_
  - [x] 6.3 Update `handleReadStreamEvent` to use ErrorClassifier
    - Replace the POSIX-54-only check with ErrorClassifier.classify; call attemptInPlaceReconnect for retriable errors, failWithError for non-retriable
    - _Requirements: 4.3, 4.4_
  - [x] 6.4 Implement smart timeout logic in `checkTimeout()`
    - Track lastFillRatio between checks; if data arrived but fill ratio dropped >20pp, treat as stalled and call attemptInPlaceReconnect; if no data, call attemptInPlaceReconnect instead of failWithError
    - _Requirements: 6.1, 6.2, 6.3, 6.4_
  - [x] 6.5 Enable proactive stall detection in `handleBufferComplete`
    - Uncomment and replace the existing checkBufferHealth with StallDetector.evaluate; trigger attemptInPlaceReconnect when evaluate returns true
    - _Requirements: 3.1, 3.2, 3.3, 3.4_
  - [x] 6.6 Write property test for reconnect state transitions
    - **Property 2: Reconnect state machine transitions**
    - Generate random reconnect scenarios; verify state goes playing → rebuffering → playing or playing → rebuffering → done(error)
    - **Validates: Requirements 2.2, 2.3**
  - [x] 6.7 Write property test for timeout with buffer health
    - **Property 6: Timeout considers buffer health**
    - Generate random (lastFillRatio, currentFillRatio, eventCount, state) tuples; verify timeout behavior
    - **Validates: Requirements 6.2, 6.4**

- [x] 7. Implement thread-safe buffer accounting
  - [x] 7.1 Refactor buffer mutations in AudioStreamer to use bufferQueue
    - Wrap `handleBufferComplete` buffer state changes in `bufferQueue.async`
    - Wrap `enqueueBuffer` buffer tracking in `bufferQueue.sync`
    - Replace `buffersUsed -= 1` with `max(0, buffersUsed - 1)`
    - Ensure `bufferInUse`, `fillBufferIndex`, `bytesFilled`, `packetsFilled` mutations are serialized
    - _Requirements: 7.1, 7.2, 7.3, 7.4_
  - [x] 7.2 Write property test for buffer counter invariant
    - **Property 7: Buffer counter non-negative invariant**
    - Generate random sequences of enqueue/dequeue operations; verify buffersUsed stays in [0, bufferCount]
    - **Validates: Requirements 7.4**

- [x] 8. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Update Playlist retry logic
  - [x] 9.1 Add BackoffStrategy to Playlist
    - Add `playlistBackoff` property using `BackoffStrategy.playlistDefault`
    - Change `maxRetries` from 2 to 4
    - _Requirements: 8.2, 5.6_
  - [x] 9.2 Update `handleStreamError` to use exponential backoff
    - Replace flat 1-second delay with `playlistBackoff.delay(forAttempt: tries)`
    - Reset tries to 0 on successful retry (in `bitrateReady` or `playbackStateChanged` when playing)
    - _Requirements: 8.1, 8.2, 8.3, 8.4_
  - [x] 9.3 Write unit tests for Playlist retry improvements
    - Test: backoff delays increase between retries, retry counter resets on success, ASStreamError posted after 4 retries exhausted
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [x] 10. Wire AudioQueue preservation test
  - [x] 10.1 Write property test for AudioQueue preservation
    - **Property 1: AudioQueue preservation during in-place reconnect**
    - Generate random retriable errors; trigger reconnect; assert AudioQueue ref and buffers remain non-nil
    - **Validates: Requirements 1.1, 1.2, 2.4**

- [x] 11. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The pure value types (ErrorClassifier, BackoffStrategy, StallDetector) are implemented first because they have no dependencies and are easy to test in isolation
- AudioStreamer modifications come after the supporting types are ready
- Playlist changes come last since they depend on AudioStreamer's new behavior
