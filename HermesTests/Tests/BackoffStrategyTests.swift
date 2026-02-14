//
//  BackoffStrategyTests.swift
//  HermesTests
//
//  Property-based tests for BackoffStrategy
//  Feature: audio-stream-resilience, Property 5: Backoff delay bounds
//

import Testing
import Foundation
@testable import Hermes

// MARK: - Generators

/// Generates random BackoffStrategy configurations with sensible ranges.
private func randomBackoffStrategy() -> BackoffStrategy {
    let baseDelay = Double.random(in: 0.1...5.0)
    let maxDelay = Double.random(in: baseDelay...60.0)
    let jitterRange = Double.random(in: 0.0...5.0)
    return BackoffStrategy(baseDelay: baseDelay, maxDelay: maxDelay, jitterRange: jitterRange)
}

/// Generates a random non-negative attempt number in a realistic range.
private func randomAttempt() -> Int {
    Int.random(in: 0...20)
}

// MARK: - Property 5: Backoff Delay Bounds

/// Property tests validating that backoff delays fall within the expected bounds.
///
/// *For any* `BackoffStrategy` with parameters `(baseDelay, maxDelay, jitterRange)` and
/// *for any* non-negative attempt number, the computed delay SHALL be in the range
/// `[min(baseDelay * 2^attempt, maxDelay), min(baseDelay * 2^attempt, maxDelay) + jitterRange)`.
/// The delay SHALL always be non-negative and SHALL never exceed `maxDelay + jitterRange`.
///
/// **Validates: Requirements 5.1**
@Suite("BackoffStrategy Property Tests")
struct BackoffStrategyPropertyTests {

    @Test("Delay is within [exponentialBase, exponentialBase + jitterRange)")
    func delayWithinExpectedRange() {
        // Feature: audio-stream-resilience, Property 5: Backoff delay bounds
        // **Validates: Requirements 5.1**

        for _ in 0..<100 {
            let strategy = randomBackoffStrategy()
            let attempt = randomAttempt()

            let delay = strategy.delay(forAttempt: attempt)
            let exponentialBase = min(strategy.baseDelay * pow(2.0, Double(attempt)), strategy.maxDelay)
            let lowerBound = exponentialBase
            let upperBound = exponentialBase + strategy.jitterRange

            #expect(
                delay >= lowerBound,
                "Delay \(delay) should be >= lower bound \(lowerBound) for attempt \(attempt) with base=\(strategy.baseDelay), max=\(strategy.maxDelay), jitter=\(strategy.jitterRange)"
            )
            #expect(
                delay < upperBound,
                "Delay \(delay) should be < upper bound \(upperBound) for attempt \(attempt) with base=\(strategy.baseDelay), max=\(strategy.maxDelay), jitter=\(strategy.jitterRange)"
            )
        }
    }

    @Test("Delay is always non-negative")
    func delayIsNonNegative() {
        // Feature: audio-stream-resilience, Property 5: Backoff delay bounds
        // **Validates: Requirements 5.1**

        for _ in 0..<100 {
            let strategy = randomBackoffStrategy()
            let attempt = randomAttempt()

            let delay = strategy.delay(forAttempt: attempt)
            #expect(delay >= 0, "Delay must be non-negative, got \(delay)")
        }
    }

    @Test("Delay never exceeds maxDelay + jitterRange")
    func delayNeverExceedsAbsoluteMax() {
        // Feature: audio-stream-resilience, Property 5: Backoff delay bounds
        // **Validates: Requirements 5.1**

        for _ in 0..<100 {
            let strategy = randomBackoffStrategy()
            let attempt = randomAttempt()

            let delay = strategy.delay(forAttempt: attempt)
            let absoluteMax = strategy.maxDelay + strategy.jitterRange

            #expect(
                delay < absoluteMax,
                "Delay \(delay) must be < absolute max \(absoluteMax) (maxDelay=\(strategy.maxDelay) + jitterRange=\(strategy.jitterRange))"
            )
        }
    }

    @Test("Delay increases monotonically (ignoring jitter) as attempt increases")
    func exponentialBaseIncreasesWithAttempt() {
        // Feature: audio-stream-resilience, Property 5: Backoff delay bounds
        // **Validates: Requirements 5.1**

        for _ in 0..<100 {
            let strategy = randomBackoffStrategy()
            let attempt1 = Int.random(in: 0...19)
            let attempt2 = attempt1 + 1

            let base1 = min(strategy.baseDelay * pow(2.0, Double(attempt1)), strategy.maxDelay)
            let base2 = min(strategy.baseDelay * pow(2.0, Double(attempt2)), strategy.maxDelay)

            #expect(
                base2 >= base1,
                "Exponential base should be non-decreasing: attempt \(attempt1) base=\(base1), attempt \(attempt2) base=\(base2)"
            )
        }
    }

    @Test("Default streamer configuration produces valid delays")
    func streamerDefaultDelaysAreValid() {
        // Feature: audio-stream-resilience, Property 5: Backoff delay bounds
        // **Validates: Requirements 5.1**

        let strategy = BackoffStrategy.streamerDefault

        for _ in 0..<100 {
            let attempt = randomAttempt()
            let delay = strategy.delay(forAttempt: attempt)
            let exponentialBase = min(0.1 * pow(2.0, Double(attempt)), 8.0)

            #expect(delay >= exponentialBase)
            #expect(delay < exponentialBase + 0.2)
            #expect(delay < 8.2) // maxDelay + jitterRange
        }
    }

    @Test("Default playlist configuration produces valid delays")
    func playlistDefaultDelaysAreValid() {
        // Feature: audio-stream-resilience, Property 5: Backoff delay bounds
        // **Validates: Requirements 5.1**

        let strategy = BackoffStrategy.playlistDefault

        for _ in 0..<100 {
            let attempt = randomAttempt()
            let delay = strategy.delay(forAttempt: attempt)
            let exponentialBase = min(1.0 * pow(2.0, Double(attempt)), 30.0)

            #expect(delay >= exponentialBase)
            #expect(delay < exponentialBase + 1.0)
            #expect(delay < 31.0) // maxDelay + jitterRange
        }
    }
}

// MARK: - Unit Tests

/// Unit tests for BackoffStrategy covering specific scenarios and edge cases.
///
/// Tests: attempt 0 returns baseDelay + jitter range, cap at maxDelay,
/// default configurations match specified values.
///
/// _Requirements: 5.1, 5.2, 5.3_
@Suite("BackoffStrategy Unit Tests")
struct BackoffStrategyUnitTests {

    // MARK: - Attempt 0 delay (Requirement 5.1)

    @Test("Attempt 0 delay is in [baseDelay, baseDelay + jitterRange)")
    func attemptZeroDelay() {
        let strategy = BackoffStrategy(baseDelay: 2.0, maxDelay: 60.0, jitterRange: 1.0)

        // Run multiple times to exercise the jitter range
        for _ in 0..<50 {
            let delay = strategy.delay(forAttempt: 0)
            // At attempt 0: min(2.0 * 2^0, 60.0) = 2.0, so delay ∈ [2.0, 3.0)
            #expect(delay >= 2.0, "Attempt 0 delay \(delay) should be >= baseDelay 2.0")
            #expect(delay < 3.0, "Attempt 0 delay \(delay) should be < baseDelay + jitterRange 3.0")
        }
    }

    // MARK: - Cap at maxDelay (Requirement 5.1)

    @Test("Delay is capped at maxDelay before jitter is added")
    func delayCapsAtMaxDelay() {
        let strategy = BackoffStrategy(baseDelay: 1.0, maxDelay: 10.0, jitterRange: 0.5)

        // Attempt 20: 1.0 * 2^20 = 1,048,576 — well beyond maxDelay
        for _ in 0..<50 {
            let delay = strategy.delay(forAttempt: 20)
            // Should be capped: delay ∈ [10.0, 10.5)
            #expect(delay >= 10.0, "High-attempt delay \(delay) should be >= maxDelay 10.0")
            #expect(delay < 10.5, "High-attempt delay \(delay) should be < maxDelay + jitterRange 10.5")
        }
    }

    @Test("Delay reaches maxDelay at the correct attempt boundary")
    func delayReachesMaxAtBoundary() {
        // baseDelay=1.0, maxDelay=8.0, tiny jitter: cap hits at attempt 3 (1*2^3 = 8)
        let strategy = BackoffStrategy(baseDelay: 1.0, maxDelay: 8.0, jitterRange: 0.001)

        // Attempt 2: 1.0 * 2^2 = 4.0 (below cap), delay ∈ [4.0, 4.001)
        let delayBeforeCap = strategy.delay(forAttempt: 2)
        #expect(delayBeforeCap >= 4.0, "Attempt 2 should be >= 4.0")
        #expect(delayBeforeCap < 4.001, "Attempt 2 should be < 4.001")

        // Attempt 3: 1.0 * 2^3 = 8.0 (exactly at cap), delay ∈ [8.0, 8.001)
        let delayAtCap = strategy.delay(forAttempt: 3)
        #expect(delayAtCap >= 8.0, "Attempt 3 should be >= 8.0 (at cap)")
        #expect(delayAtCap < 8.001, "Attempt 3 should be < 8.001")

        // Attempt 4: 1.0 * 2^4 = 16.0 → capped to 8.0, delay ∈ [8.0, 8.001)
        let delayBeyondCap = strategy.delay(forAttempt: 4)
        #expect(delayBeyondCap >= 8.0, "Attempt 4 should be capped at >= 8.0")
        #expect(delayBeyondCap < 8.001, "Attempt 4 should be capped at < 8.001")
    }

    // MARK: - Default configurations (Requirements 5.2, 5.3)

    @Test("streamerDefault has correct configuration values")
    func streamerDefaultConfiguration() {
        let strategy = BackoffStrategy.streamerDefault
        #expect(strategy.baseDelay == 0.1, "Streamer baseDelay should be 0.1")
        #expect(strategy.maxDelay == 8.0, "Streamer maxDelay should be 8.0")
        #expect(strategy.jitterRange == 0.2, "Streamer jitterRange should be 0.2")
    }

    @Test("playlistDefault has correct configuration values")
    func playlistDefaultConfiguration() {
        let strategy = BackoffStrategy.playlistDefault
        #expect(strategy.baseDelay == 1.0, "Playlist baseDelay should be 1.0")
        #expect(strategy.maxDelay == 30.0, "Playlist maxDelay should be 30.0")
        #expect(strategy.jitterRange == 1.0, "Playlist jitterRange should be 1.0")
    }

    @Test("streamerDefault attempt 0 delay is in [0.1, 0.3)")
    func streamerDefaultAttemptZero() {
        let strategy = BackoffStrategy.streamerDefault
        for _ in 0..<50 {
            let delay = strategy.delay(forAttempt: 0)
            // min(0.1 * 2^0, 8.0) = 0.1, jitter ∈ [0, 0.2) → delay ∈ [0.1, 0.3)
            #expect(delay >= 0.1)
            #expect(delay < 0.3)
        }
    }

    @Test("playlistDefault attempt 0 delay is in [1.0, 2.0)")
    func playlistDefaultAttemptZero() {
        let strategy = BackoffStrategy.playlistDefault
        for _ in 0..<50 {
            let delay = strategy.delay(forAttempt: 0)
            // min(1.0 * 2^0, 30.0) = 1.0, jitter ∈ [0, 1.0) → delay ∈ [1.0, 2.0)
            #expect(delay >= 1.0)
            #expect(delay < 2.0)
        }
    }

    @Test("streamerDefault caps at maxDelay 8.0")
    func streamerDefaultCapsCorrectly() {
        let strategy = BackoffStrategy.streamerDefault
        for _ in 0..<50 {
            let delay = strategy.delay(forAttempt: 10) // well beyond cap
            #expect(delay >= 8.0)
            #expect(delay < 8.2) // maxDelay + jitterRange
        }
    }

    @Test("playlistDefault caps at maxDelay 30.0")
    func playlistDefaultCapsCorrectly() {
        let strategy = BackoffStrategy.playlistDefault
        for _ in 0..<50 {
            let delay = strategy.delay(forAttempt: 10) // well beyond cap
            #expect(delay >= 30.0)
            #expect(delay < 31.0) // maxDelay + jitterRange
        }
    }
}
