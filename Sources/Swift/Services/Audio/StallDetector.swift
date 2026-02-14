//
//  StallDetector.swift
//  Hermes
//
//  Monitors buffer health using hysteresis to trigger proactive reconnects.
//  Arms when buffers reach the high mark, triggers when they drain below the low mark.
//

import Foundation

// MARK: - StallDetector

/// Encapsulates hysteresis logic for proactive stall detection during audio streaming.
///
/// The detector uses a two-threshold approach to avoid false triggers during initial buffering:
/// 1. It **arms** when the buffer fill ratio reaches or exceeds the high mark (75%)
/// 2. It **triggers** when the fill ratio drops below the low mark (25%) while armed,
///    with no queued packets pending and no reconnect already in progress
///
/// Call `reset()` when starting a new stream or after a successful reconnect.
struct StallDetector {

    /// Fill ratio threshold to arm the detector (default: 0.75)
    let highMark: Double

    /// Fill ratio threshold to trigger reconnect when armed (default: 0.25)
    let lowMark: Double
    
    /// Number of consecutive evaluations below lowMark required before triggering
    let debounceCount: Int

    /// Whether buffers have previously reached the high mark
    private(set) var armed: Bool = false
    
    /// Number of consecutive evaluations below the low mark
    private var consecutiveLowCount: Int = 0

    init(highMark: Double = 0.75, lowMark: Double = 0.40, debounceCount: Int = 3) {
        self.highMark = highMark
        self.lowMark = lowMark
        self.debounceCount = debounceCount
    }

    // MARK: - Evaluation

    /// Evaluates current buffer health and determines whether a proactive reconnect should trigger.
    ///
    /// - Parameters:
    ///   - fillRatio: Current buffer fill ratio in [0.0, 1.0]
    ///   - hasQueuedPackets: Whether there are audio packets queued but not yet enqueued into buffers
    ///   - isReconnecting: Whether an in-place reconnect is already in progress
    /// - Returns: `true` when a proactive reconnect should be initiated
    mutating func evaluate(fillRatio: Double, hasQueuedPackets: Bool, isReconnecting: Bool) -> Bool {
        // Never trigger while a reconnect is already in progress
        guard !isReconnecting else { return false }

        // Arm when buffers reach the high mark
        if fillRatio >= highMark {
            armed = true
            consecutiveLowCount = 0
        }

        // Count consecutive evaluations below low mark when armed
        if armed && fillRatio < lowMark && !hasQueuedPackets {
            consecutiveLowCount += 1
            if consecutiveLowCount >= debounceCount {
                armed = false
                consecutiveLowCount = 0
                return true
            }
        } else if fillRatio >= lowMark {
            consecutiveLowCount = 0
        }

        return false
    }

    // MARK: - Reset

    /// Clears the armed state. Call when starting a new stream or after reconnection.
    mutating func reset() {
        armed = false
        consecutiveLowCount = 0
    }
}
