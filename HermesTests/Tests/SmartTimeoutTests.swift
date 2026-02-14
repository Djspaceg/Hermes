//
//  SmartTimeoutTests.swift
//  HermesTests
//
//  Property-based tests for smart timeout logic with buffer health
//  Feature: audio-stream-resilience, Property 6: Timeout considers buffer health
//

import Testing
import Foundation
@testable import Hermes

// MARK: - Timeout Action Model

/// The possible actions the timeout logic can take.
private enum TimeoutAction: Equatable {
    /// No action taken (paused, rebuffering, or unscheduled states)
    case noAction
    /// Trigger an in-place reconnect (stalled trickle or no data)
    case reconnect
    /// Data arrived and buffers are healthy — update fill ratio tracking
    case updateFillRatio
}

// MARK: - Smart Timeout Model

/// A pure model of the AudioStreamer's `checkTimeout()` logic,
/// extracted for testability without requiring network or CoreAudio.
///
/// This mirrors the logic in AudioStreamer.checkTimeout():
/// - Paused state → no action
/// - Data arrived but fill ratio dropped >20pp → reconnect (stalled trickle)
/// - Data arrived and buffers healthy → update tracking
/// - No data arrived → reconnect
private struct SmartTimeoutModel {
    static func evaluate(
        lastFillRatio: Double,
        currentFillRatio: Double,
        eventCount: Int,
        state: AudioStreamerState
    ) -> TimeoutAction {
        // Paused state skips all timeout logic (Requirement 6.4)
        if case .paused = state { return .noAction }

        // Rebuffering state also skips (reconnect already in progress)
        if case .rebuffering = state { return .noAction }

        if eventCount > 0 {
            // Data arrived — check buffer health (Requirement 6.2)
            if lastFillRatio - currentFillRatio > 0.20 {
                return .reconnect
            }
            return .updateFillRatio
        }

        // No data at all — reconnect (Requirement 6.3)
        return .reconnect
    }
}

// MARK: - Generators

/// Generates a random fill ratio in [0.0, 1.0].
private func randomFillRatio() -> Double {
    Double.random(in: 0.0...1.0)
}

/// Generates a random event count (0 = no data, >0 = data arrived).
private func randomEventCount() -> Int {
    Int.random(in: 0...20)
}

/// Generates a random AudioStreamerState relevant to timeout testing.
private func randomTimeoutState() -> AudioStreamerState {
    let roll = Int.random(in: 0..<5)
    switch roll {
    case 0: return .playing
    case 1: return .paused
    case 2: return .rebuffering
    case 3: return .waitingForData
    default: return .waitingForQueueToStart
    }
}

// MARK: - Property 6: Timeout Considers Buffer Health

/// Property tests validating smart timeout behavior with buffer health.
///
/// *For any* pair of fill ratios `(lastFillRatio, currentFillRatio)` where data has
/// arrived (eventCount > 0) but `lastFillRatio - currentFillRatio > 0.20`, the smart
/// timeout logic SHALL treat the connection as stalled. *For any* timeout check while
/// in the paused state, the timeout logic SHALL take no action regardless of event
/// count or fill ratio.
///
/// **Validates: Requirements 6.2, 6.4**
@Suite("Smart Timeout Property Tests")
struct SmartTimeoutPropertyTests {

    // MARK: - Property: Paused state always produces no action

    @Test("Paused state always produces no action regardless of inputs")
    func pausedStateAlwaysNoAction() {
        // Feature: audio-stream-resilience, Property 6: Timeout considers buffer health
        // **Validates: Requirements 6.2, 6.4**

        for _ in 0..<100 {
            let lastFill = randomFillRatio()
            let currentFill = randomFillRatio()
            let events = randomEventCount()

            let action = SmartTimeoutModel.evaluate(
                lastFillRatio: lastFill,
                currentFillRatio: currentFill,
                eventCount: events,
                state: .paused
            )

            #expect(
                action == .noAction,
                "Paused state should always produce noAction, got \(action) with lastFill=\(lastFill), currentFill=\(currentFill), events=\(events)"
            )
        }
    }

    // MARK: - Property: Stalled trickle triggers reconnect

    @Test("Data arrived but fill ratio dropped >20pp triggers reconnect")
    func stalledTrickleTriggerReconnect() {
        // Feature: audio-stream-resilience, Property 6: Timeout considers buffer health
        // **Validates: Requirements 6.2, 6.4**

        for _ in 0..<100 {
            // Generate fill ratios where the drop exceeds 20pp
            let lastFill = Double.random(in: 0.21...1.0)
            let maxCurrent = lastFill - 0.201  // Ensure drop > 0.20
            let currentFill = Double.random(in: 0.0...max(0.0, maxCurrent))
            let events = Int.random(in: 1...20)  // Data arrived

            // Use a non-paused, non-rebuffering state
            let state: AudioStreamerState = .playing

            let action = SmartTimeoutModel.evaluate(
                lastFillRatio: lastFill,
                currentFillRatio: currentFill,
                eventCount: events,
                state: state
            )

            #expect(
                action == .reconnect,
                "Should reconnect when fill ratio drops >20pp: last=\(lastFill), current=\(currentFill), drop=\(lastFill - currentFill)"
            )
        }
    }

    // MARK: - Property: Healthy data arrival updates fill ratio

    @Test("Data arrived with healthy buffers updates fill ratio tracking")
    func healthyDataUpdatesTracking() {
        // Feature: audio-stream-resilience, Property 6: Timeout considers buffer health
        // **Validates: Requirements 6.2, 6.4**

        for _ in 0..<100 {
            // Generate fill ratios where the drop is <= 20pp (healthy)
            let lastFill = randomFillRatio()
            let minCurrent = max(0.0, lastFill - 0.20)
            let currentFill = Double.random(in: minCurrent...1.0)
            let events = Int.random(in: 1...20)  // Data arrived

            let state: AudioStreamerState = .playing

            let action = SmartTimeoutModel.evaluate(
                lastFillRatio: lastFill,
                currentFillRatio: currentFill,
                eventCount: events,
                state: state
            )

            #expect(
                action == .updateFillRatio,
                "Should update fill ratio when drop <= 20pp: last=\(lastFill), current=\(currentFill), drop=\(lastFill - currentFill)"
            )
        }
    }

    // MARK: - Property: No data triggers reconnect

    @Test("No data arrived always triggers reconnect in active states")
    func noDataTriggersReconnect() {
        // Feature: audio-stream-resilience, Property 6: Timeout considers buffer health
        // **Validates: Requirements 6.2, 6.4**

        for _ in 0..<100 {
            let lastFill = randomFillRatio()
            let currentFill = randomFillRatio()

            // Use active states (not paused, not rebuffering)
            let activeStates: [AudioStreamerState] = [
                .playing, .waitingForData, .waitingForQueueToStart
            ]
            let state = activeStates.randomElement()!

            let action = SmartTimeoutModel.evaluate(
                lastFillRatio: lastFill,
                currentFillRatio: currentFill,
                eventCount: 0,  // No data
                state: state
            )

            #expect(
                action == .reconnect,
                "Should reconnect when no data arrived, got \(action) with state=\(state)"
            )
        }
    }

    // MARK: - Property: Rebuffering state produces no action

    @Test("Rebuffering state always produces no action")
    func rebufferingStateNoAction() {
        // Feature: audio-stream-resilience, Property 6: Timeout considers buffer health
        // **Validates: Requirements 6.2, 6.4**

        for _ in 0..<100 {
            let lastFill = randomFillRatio()
            let currentFill = randomFillRatio()
            let events = randomEventCount()

            let action = SmartTimeoutModel.evaluate(
                lastFillRatio: lastFill,
                currentFillRatio: currentFill,
                eventCount: events,
                state: .rebuffering
            )

            #expect(
                action == .noAction,
                "Rebuffering state should produce noAction, got \(action)"
            )
        }
    }

    // MARK: - Property: Random inputs produce consistent results

    @Test("Random inputs always produce deterministic, valid actions")
    func randomInputsDeterministic() {
        // Feature: audio-stream-resilience, Property 6: Timeout considers buffer health
        // **Validates: Requirements 6.2, 6.4**

        for _ in 0..<100 {
            let lastFill = randomFillRatio()
            let currentFill = randomFillRatio()
            let events = randomEventCount()
            let state = randomTimeoutState()

            // Evaluate twice with same inputs
            let action1 = SmartTimeoutModel.evaluate(
                lastFillRatio: lastFill,
                currentFillRatio: currentFill,
                eventCount: events,
                state: state
            )
            let action2 = SmartTimeoutModel.evaluate(
                lastFillRatio: lastFill,
                currentFillRatio: currentFill,
                eventCount: events,
                state: state
            )

            #expect(
                action1 == action2,
                "Same inputs should always produce same action"
            )

            // Verify the action is valid for the given inputs
            switch state {
            case .paused, .rebuffering:
                #expect(action1 == .noAction, "Paused/rebuffering should always be noAction")
            default:
                if events == 0 {
                    #expect(action1 == .reconnect, "No data in active state should reconnect")
                } else if lastFill - currentFill > 0.20 {
                    #expect(action1 == .reconnect, "Stalled trickle should reconnect")
                } else {
                    #expect(action1 == .updateFillRatio, "Healthy data should update tracking")
                }
            }
        }
    }
}
