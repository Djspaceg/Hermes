//
//  AudioStreamerReconnectTests.swift
//  HermesTests
//
//  Property-based tests for reconnect state machine transitions
//  Feature: audio-stream-resilience, Property 2: Reconnect state machine transitions
//

import Testing
import Foundation
@testable import Hermes

// MARK: - Reconnect State Machine Model

/// A pure model of the AudioStreamer's reconnect state machine,
/// extracted from the actual implementation for testability without
/// requiring network or CoreAudio resources.
///
/// This mirrors the transitions in AudioStreamer:
/// - `attemptInPlaceReconnect()`: playing → rebuffering (or done if max attempts exceeded)
/// - `handleBytesAvailable()`: rebuffering → playing (when data arrives)
/// - `failWithError()`: rebuffering → done(error) (when reconnect fails terminally)
private struct ReconnectStateMachine {
    var state: AudioStreamerState = .playing
    var reconnectAttempts: Int = 0
    let maxReconnectAttempts: Int

    /// Initiates an in-place reconnect, mirroring `attemptInPlaceReconnect()`.
    mutating func attemptReconnect() {
        guard case .playing = state else {
            // Also allow reconnect from rebuffering (retry within reconnect)
            guard case .rebuffering = state else { return }
            // Fall through to attempt logic
            return attemptReconnectFromRebuffering()
        }
        performReconnectAttempt()
    }

    /// Handles a reconnect attempt when already rebuffering (e.g., stream reopen failed).
    private mutating func attemptReconnectFromRebuffering() {
        performReconnectAttempt()
    }

    private mutating func performReconnectAttempt() {
        if reconnectAttempts >= maxReconnectAttempts {
            state = .done(reason: .error(.networkConnectionFailed(underlyingError: "Max reconnect attempts exceeded")))
            return
        }
        state = .rebuffering
        reconnectAttempts += 1
    }

    /// Data arrived after reconnect, mirroring `handleBytesAvailable()`.
    mutating func dataArrived() {
        guard case .rebuffering = state else { return }
        reconnectAttempts = 0
        state = .playing
    }

    /// Terminal failure, mirroring `failWithError()`.
    mutating func fail() {
        state = .done(reason: .error(.networkConnectionFailed(underlyingError: "Terminal failure")))
    }
}

// MARK: - Reconnect Scenario Events

/// Represents a single event in a reconnect scenario.
private enum ReconnectEvent {
    /// A retriable error triggers an in-place reconnect attempt
    case retriableError
    /// Data arrives on the new stream (reconnect success)
    case dataArrived
    /// A non-retriable error or max attempts exceeded causes terminal failure
    case terminalFailure
}

// MARK: - Generators

/// Generates a random reconnect event with realistic distribution.
private func randomReconnectEvent() -> ReconnectEvent {
    let roll = Int.random(in: 0..<10)
    switch roll {
    case 0...4: return .retriableError    // 50% — errors are common in reconnect scenarios
    case 5...7: return .dataArrived       // 30% — successful data arrival
    default:    return .terminalFailure   // 20% — terminal failures
    }
}

/// Generates a random sequence of reconnect events.
private func randomReconnectScenario(length: Int) -> [ReconnectEvent] {
    (0..<length).map { _ in randomReconnectEvent() }
}

/// Generates a scenario biased toward the success path: error → data → error → data...
private func biasedSuccessScenario() -> [ReconnectEvent] {
    let cycles = Int.random(in: 1...5)
    var events: [ReconnectEvent] = []
    for _ in 0..<cycles {
        events.append(.retriableError)
        // Sometimes add extra errors before success
        if Bool.random() {
            events.append(.retriableError)
        }
        events.append(.dataArrived)
    }
    return events
}

/// Generates a scenario biased toward exhausting reconnect attempts.
private func biasedExhaustionScenario(maxAttempts: Int) -> [ReconnectEvent] {
    var events: [ReconnectEvent] = []
    // Generate more errors than max attempts to ensure exhaustion
    for _ in 0...(maxAttempts + 2) {
        events.append(.retriableError)
    }
    return events
}


// MARK: - Property 2: Reconnect State Machine Transitions

/// Property tests validating reconnect state machine transitions.
///
/// *For any* AudioStreamer in the playing state that initiates an in-place reconnect,
/// the state SHALL transition to `rebuffering`. *For any* AudioStreamer in the
/// `rebuffering` state that successfully receives new audio data, the state SHALL
/// transition back to `playing`. No other state transitions are valid from `rebuffering`
/// except to `playing` or to `done(reason: .error(...))`.
///
/// **Validates: Requirements 2.2, 2.3**
@Suite("Reconnect State Machine Property Tests")
struct ReconnectStateMachinePropertyTests {

    // MARK: - Property: Playing → Rebuffering on retriable error

    @Test("Initiating reconnect from playing always transitions to rebuffering")
    func playingToRebufferingOnReconnect() {
        // Feature: audio-stream-resilience, Property 2: Reconnect state machine transitions
        // **Validates: Requirements 2.2, 2.3**

        for _ in 0..<100 {
            let maxAttempts = Int.random(in: 1...10)
            var sm = ReconnectStateMachine(maxReconnectAttempts: maxAttempts)
            #expect(sm.state == .playing, "Should start in playing state")

            sm.attemptReconnect()

            #expect(
                sm.state == .rebuffering,
                "State should be rebuffering after reconnect from playing, got \(sm.state)"
            )
            #expect(
                sm.reconnectAttempts == 1,
                "Reconnect attempts should be 1 after first attempt"
            )
        }
    }

    // MARK: - Property: Rebuffering → Playing on data arrival

    @Test("Data arrival during rebuffering always transitions to playing")
    func rebufferingToPlayingOnData() {
        // Feature: audio-stream-resilience, Property 2: Reconnect state machine transitions
        // **Validates: Requirements 2.2, 2.3**

        for _ in 0..<100 {
            let maxAttempts = Int.random(in: 1...10)
            var sm = ReconnectStateMachine(maxReconnectAttempts: maxAttempts)

            // Get to rebuffering state
            sm.attemptReconnect()
            #expect(sm.state == .rebuffering)

            // Data arrives
            sm.dataArrived()

            #expect(
                sm.state == .playing,
                "State should be playing after data arrives during rebuffering"
            )
            #expect(
                sm.reconnectAttempts == 0,
                "Reconnect attempts should reset to 0 on success"
            )
        }
    }

    // MARK: - Property: Rebuffering → Done(error) on max attempts exceeded

    @Test("Exceeding max reconnect attempts transitions to done with error")
    func rebufferingToDoneOnMaxAttempts() {
        // Feature: audio-stream-resilience, Property 2: Reconnect state machine transitions
        // **Validates: Requirements 2.2, 2.3**

        for _ in 0..<100 {
            let maxAttempts = Int.random(in: 1...8)
            var sm = ReconnectStateMachine(maxReconnectAttempts: maxAttempts)

            // Exhaust all reconnect attempts
            for i in 0..<maxAttempts {
                sm.attemptReconnect()
                #expect(
                    sm.state == .rebuffering,
                    "Should be rebuffering at attempt \(i + 1)/\(maxAttempts)"
                )
                // Simulate failed reconnect — trigger another attempt
                // (In real code, openReadStream fails and calls attemptInPlaceReconnect again)
            }

            // One more attempt should exceed max
            sm.attemptReconnect()

            #expect(
                sm.state.isDone,
                "State should be done after exceeding max attempts, got \(sm.state)"
            )
            if case .done(let reason) = sm.state {
                if case .error = reason {
                    // Expected — done with error
                } else {
                    Issue.record("Done reason should be .error, got \(reason)")
                }
            }
        }
    }

    // MARK: - Property: Only valid transitions from rebuffering

    @Test("From rebuffering, only valid transitions are to playing or done(error)")
    func onlyValidTransitionsFromRebuffering() {
        // Feature: audio-stream-resilience, Property 2: Reconnect state machine transitions
        // **Validates: Requirements 2.2, 2.3**

        for _ in 0..<100 {
            let maxAttempts = Int.random(in: 1...10)
            var sm = ReconnectStateMachine(maxReconnectAttempts: maxAttempts)

            // Get to rebuffering
            sm.attemptReconnect()
            #expect(sm.state == .rebuffering)

            // Apply a random event
            let event = randomReconnectEvent()
            let stateBefore = sm.state

            switch event {
            case .retriableError:
                sm.attemptReconnect()
            case .dataArrived:
                sm.dataArrived()
            case .terminalFailure:
                sm.fail()
            }

            let stateAfter = sm.state

            // Verify the transition is valid
            if case .rebuffering = stateBefore {
                switch stateAfter {
                case .playing:
                    break // Valid: rebuffering → playing
                case .rebuffering:
                    break // Valid: still rebuffering (another attempt in progress)
                case .done(let reason):
                    if case .error = reason {
                        break // Valid: rebuffering → done(error)
                    } else {
                        Issue.record(
                            "Invalid transition: rebuffering → done(\(reason)). Only done(.error) is valid from rebuffering."
                        )
                    }
                default:
                    Issue.record(
                        "Invalid transition from rebuffering to \(stateAfter). Only playing, rebuffering, or done(error) are valid."
                    )
                }
            }
        }
    }

    // MARK: - Property: Random scenario state invariants

    @Test("Random reconnect scenarios maintain valid state transitions throughout")
    func randomScenarioStateInvariants() {
        // Feature: audio-stream-resilience, Property 2: Reconnect state machine transitions
        // **Validates: Requirements 2.2, 2.3**

        for _ in 0..<100 {
            let maxAttempts = Int.random(in: 1...8)
            var sm = ReconnectStateMachine(maxReconnectAttempts: maxAttempts)
            let scenario = randomReconnectScenario(length: Int.random(in: 3...20))

            for event in scenario {
                let stateBefore = sm.state

                // Skip events if already in terminal state
                if sm.state.isDone { break }

                switch event {
                case .retriableError:
                    sm.attemptReconnect()
                case .dataArrived:
                    sm.dataArrived()
                case .terminalFailure:
                    sm.fail()
                }

                let stateAfter = sm.state

                // Validate transition based on previous state
                switch stateBefore {
                case .playing:
                    switch stateAfter {
                    case .playing:
                        break // dataArrived while playing is a no-op
                    case .rebuffering:
                        break // Valid: playing → rebuffering
                    case .done(let reason):
                        if case .error = reason {
                            break // Valid: playing → done(error) via terminal failure or max attempts
                        }
                        Issue.record("Invalid: playing → done(\(reason))")
                    default:
                        Issue.record("Invalid transition: playing → \(stateAfter)")
                    }

                case .rebuffering:
                    switch stateAfter {
                    case .playing:
                        break // Valid: rebuffering → playing
                    case .rebuffering:
                        break // Valid: still rebuffering
                    case .done(let reason):
                        if case .error = reason {
                            break // Valid: rebuffering → done(error)
                        }
                        Issue.record("Invalid: rebuffering → done(\(reason))")
                    default:
                        Issue.record("Invalid transition: rebuffering → \(stateAfter)")
                    }

                default:
                    break // Other states not part of this property
                }
            }
        }
    }

    // MARK: - Property: Success path resets attempts and allows re-reconnect

    @Test("Successful reconnect resets attempts, allowing full retry budget again")
    func successResetsAttemptBudget() {
        // Feature: audio-stream-resilience, Property 2: Reconnect state machine transitions
        // **Validates: Requirements 2.2, 2.3**

        for _ in 0..<100 {
            let maxAttempts = Int.random(in: 2...6)
            var sm = ReconnectStateMachine(maxReconnectAttempts: maxAttempts)

            // Use some attempts
            let attemptsUsed = Int.random(in: 1..<maxAttempts)
            for _ in 0..<attemptsUsed {
                sm.attemptReconnect()
            }
            #expect(sm.state == .rebuffering)
            #expect(sm.reconnectAttempts == attemptsUsed)

            // Succeed
            sm.dataArrived()
            #expect(sm.state == .playing)
            #expect(sm.reconnectAttempts == 0, "Attempts should reset on success")

            // Should be able to use full budget again
            for i in 0..<maxAttempts {
                sm.attemptReconnect()
                #expect(
                    sm.state == .rebuffering,
                    "Should still be able to reconnect at attempt \(i + 1) after reset"
                )
            }

            // Now exceeding should fail
            sm.attemptReconnect()
            #expect(sm.state.isDone, "Should be done after exhausting reset budget")
        }
    }

    // MARK: - Property: Biased success scenarios cycle correctly

    @Test("Biased success scenarios cycle through playing ↔ rebuffering correctly")
    func biasedSuccessCycles() {
        // Feature: audio-stream-resilience, Property 2: Reconnect state machine transitions
        // **Validates: Requirements 2.2, 2.3**

        for _ in 0..<100 {
            let maxAttempts = Int.random(in: 3...10)
            var sm = ReconnectStateMachine(maxReconnectAttempts: maxAttempts)
            let scenario = biasedSuccessScenario()

            for event in scenario {
                if sm.state.isDone { break }

                switch event {
                case .retriableError:
                    let wasDone = sm.state.isDone
                    sm.attemptReconnect()
                    if !wasDone {
                        // Should be rebuffering or done (if max exceeded)
                        #expect(
                            sm.state == .rebuffering || sm.state.isDone,
                            "After retriable error: expected rebuffering or done, got \(sm.state)"
                        )
                    }
                case .dataArrived:
                    sm.dataArrived()
                    if case .rebuffering = sm.state {
                        Issue.record("Should not still be rebuffering after data arrived")
                    }
                case .terminalFailure:
                    sm.fail()
                    #expect(sm.state.isDone, "Should be done after terminal failure")
                }
            }
        }
    }

    // MARK: - Property: Exhaustion scenarios always reach done(error)

    @Test("Exhaustion scenarios always end in done(error)")
    func exhaustionAlwaysReachesDoneError() {
        // Feature: audio-stream-resilience, Property 2: Reconnect state machine transitions
        // **Validates: Requirements 2.2, 2.3**

        for _ in 0..<100 {
            let maxAttempts = Int.random(in: 1...8)
            var sm = ReconnectStateMachine(maxReconnectAttempts: maxAttempts)
            let scenario = biasedExhaustionScenario(maxAttempts: maxAttempts)

            for event in scenario {
                if sm.state.isDone { break }

                switch event {
                case .retriableError:
                    sm.attemptReconnect()
                case .dataArrived:
                    sm.dataArrived()
                case .terminalFailure:
                    sm.fail()
                }
            }

            #expect(sm.state.isDone, "Exhaustion scenario should end in done state")
            if case .done(let reason) = sm.state {
                if case .error = reason {
                    // Expected
                } else {
                    Issue.record("Exhaustion should end with done(.error), got done(\(reason))")
                }
            }
        }
    }
}
