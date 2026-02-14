//
//  BackoffStrategy.swift
//  Hermes
//
//  Computes exponential backoff delays with random jitter for retry logic.
//  Used by AudioStreamer (stream-level retries) and Playlist (fresh-stream retries).
//

import Foundation

// MARK: - BackoffStrategy

/// Computes exponential backoff delays with random jitter.
///
/// The delay formula is: `min(baseDelay * 2^attempt, maxDelay) + random jitter in [0, jitterRange)`
///
/// The attempt counter is owned by the caller — this struct is purely a delay calculator.
struct BackoffStrategy {

    /// Starting delay before the first retry
    let baseDelay: TimeInterval

    /// Maximum cap on the computed exponential delay (before jitter)
    let maxDelay: TimeInterval

    /// Range for random jitter added on top of the exponential delay
    let jitterRange: TimeInterval

    /// Computes the delay for a given retry attempt.
    ///
    /// - Parameter attempt: Zero-based attempt number (0 = first retry)
    /// - Returns: Delay in seconds, always in `[min(baseDelay * 2^attempt, maxDelay), min(baseDelay * 2^attempt, maxDelay) + jitterRange)`
    func delay(forAttempt attempt: Int) -> TimeInterval {
        let exponential = min(baseDelay * pow(2.0, Double(attempt)), maxDelay)
        let jitter = Double.random(in: 0..<jitterRange)
        return exponential + jitter
    }

    // MARK: - Defaults

    /// Default backoff for AudioStreamer in-place reconnection attempts
    static let streamerDefault = BackoffStrategy(
        baseDelay: 0.1, maxDelay: 8.0, jitterRange: 0.2
    )

    /// Default backoff for Playlist fresh-stream retry attempts
    static let playlistDefault = BackoffStrategy(
        baseDelay: 1.0, maxDelay: 30.0, jitterRange: 1.0
    )
}
