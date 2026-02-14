//
//  StallDetectorTests.swift
//  HermesTests
//
//  Property-based tests for StallDetector
//  Feature: audio-stream-resilience, Property 3: StallDetector hysteresis correctness
//

import Testing
import Foundation
@testable import Hermes

// MARK: - Generators

private func randomFillRatio() -> Double {
    Double.random(in: 0.0...1.0)
}

// MARK: - Property 3: StallDetector Hysteresis Correctness

@Suite("StallDetector Property Tests")
struct StallDetectorPropertyTests {

    @Test("evaluate returns false until fill ratio reaches high mark at least once")
    func noTriggerBeforeArming() {
        for _ in 0..<100 {
            var detector = StallDetector(highMark: 0.75, lowMark: 0.25, debounceCount: 1)
            let seqLength = Int.random(in: 1...20)

            for _ in 0..<seqLength {
                let fillRatio = Double.random(in: 0.0..<0.75)
                let result = detector.evaluate(
                    fillRatio: fillRatio,
                    hasQueuedPackets: Bool.random(),
                    isReconnecting: Bool.random()
                )
                #expect(result == false)
                #expect(detector.armed == false)
            }
        }
    }

    @Test("evaluate always returns false when isReconnecting is true")
    func reconnectingAlwaysSuppresses() {
        for _ in 0..<100 {
            var detector = StallDetector(highMark: 0.75, lowMark: 0.25, debounceCount: 1)
            _ = detector.evaluate(fillRatio: 0.9, hasQueuedPackets: false, isReconnecting: false)
            #expect(detector.armed == true)

            let seqLength = Int.random(in: 1...20)
            for _ in 0..<seqLength {
                let result = detector.evaluate(
                    fillRatio: randomFillRatio(),
                    hasQueuedPackets: Bool.random(),
                    isReconnecting: true
                )
                #expect(result == false)
            }
        }
    }

    @Test("after triggering, detector must re-arm before triggering again")
    func rearmingRequiredAfterTrigger() {
        for _ in 0..<100 {
            var detector = StallDetector(highMark: 0.75, lowMark: 0.25, debounceCount: 1)
            _ = detector.evaluate(fillRatio: 0.9, hasQueuedPackets: false, isReconnecting: false)
            let triggered = detector.evaluate(fillRatio: 0.1, hasQueuedPackets: false, isReconnecting: false)
            #expect(triggered == true)
            #expect(detector.armed == false)

            for _ in 0..<Int.random(in: 1...10) {
                let fillRatio = Double.random(in: 0.0..<0.75)
                let result = detector.evaluate(fillRatio: fillRatio, hasQueuedPackets: false, isReconnecting: false)
                #expect(result == false)
            }
        }
    }

    @Test("hasQueuedPackets prevents trigger even when armed and below low mark")
    func queuedPacketsPreventTrigger() {
        for _ in 0..<100 {
            var detector = StallDetector(highMark: 0.75, lowMark: 0.25, debounceCount: 1)
            _ = detector.evaluate(fillRatio: 0.9, hasQueuedPackets: false, isReconnecting: false)
            let result = detector.evaluate(
                fillRatio: Double.random(in: 0.0..<0.25),
                hasQueuedPackets: true,
                isReconnecting: false
            )
            #expect(result == false)
            #expect(detector.armed == true)
        }
    }
}

// MARK: - Debounce Tests

@Suite("StallDetector Debounce Tests")
struct StallDetectorDebounceTests {

    @Test("requires N consecutive low evaluations before triggering")
    func debounceRequiresConsecutiveLow() {
        var detector = StallDetector(highMark: 0.75, lowMark: 0.40, debounceCount: 3)
        _ = detector.evaluate(fillRatio: 0.9, hasQueuedPackets: false, isReconnecting: false)
        #expect(detector.armed == true)

        // First two below low mark — should not trigger
        #expect(detector.evaluate(fillRatio: 0.3, hasQueuedPackets: false, isReconnecting: false) == false)
        #expect(detector.evaluate(fillRatio: 0.2, hasQueuedPackets: false, isReconnecting: false) == false)
        // Third — should trigger
        #expect(detector.evaluate(fillRatio: 0.1, hasQueuedPackets: false, isReconnecting: false) == true)
    }

    @Test("going above low mark resets debounce counter")
    func aboveLowMarkResetsCounter() {
        var detector = StallDetector(highMark: 0.75, lowMark: 0.40, debounceCount: 3)
        _ = detector.evaluate(fillRatio: 0.9, hasQueuedPackets: false, isReconnecting: false)

        // Two below
        #expect(detector.evaluate(fillRatio: 0.3, hasQueuedPackets: false, isReconnecting: false) == false)
        #expect(detector.evaluate(fillRatio: 0.2, hasQueuedPackets: false, isReconnecting: false) == false)
        // Go above — resets counter
        #expect(detector.evaluate(fillRatio: 0.5, hasQueuedPackets: false, isReconnecting: false) == false)
        // Need 3 more consecutive
        #expect(detector.evaluate(fillRatio: 0.3, hasQueuedPackets: false, isReconnecting: false) == false)
        #expect(detector.evaluate(fillRatio: 0.2, hasQueuedPackets: false, isReconnecting: false) == false)
        #expect(detector.evaluate(fillRatio: 0.1, hasQueuedPackets: false, isReconnecting: false) == true)
    }

    @Test("reset clears debounce counter")
    func resetClearsDebounce() {
        var detector = StallDetector(highMark: 0.75, lowMark: 0.40, debounceCount: 3)
        _ = detector.evaluate(fillRatio: 0.9, hasQueuedPackets: false, isReconnecting: false)
        _ = detector.evaluate(fillRatio: 0.3, hasQueuedPackets: false, isReconnecting: false)
        _ = detector.evaluate(fillRatio: 0.2, hasQueuedPackets: false, isReconnecting: false)
        detector.reset()
        #expect(detector.armed == false)
        // After reset, even below low mark should not trigger (not armed)
        #expect(detector.evaluate(fillRatio: 0.1, hasQueuedPackets: false, isReconnecting: false) == false)
    }

    @Test("default debounce count is 3")
    func defaultDebounceCount() {
        let detector = StallDetector()
        #expect(detector.debounceCount == 3)
        #expect(detector.highMark == 0.75)
        #expect(detector.lowMark == 0.40)
    }
}

// MARK: - Unit Tests

@Suite("StallDetector Unit Tests")
struct StallDetectorUnitTests {

    @Test("not armed initially")
    func notArmedInitially() {
        let detector = StallDetector(highMark: 0.75, lowMark: 0.25, debounceCount: 1)
        #expect(detector.armed == false)
    }

    @Test("arms at exactly 0.75 fill ratio")
    func armsAtHighMark() {
        var detector = StallDetector(highMark: 0.75, lowMark: 0.25, debounceCount: 1)
        let result = detector.evaluate(fillRatio: 0.75, hasQueuedPackets: false, isReconnecting: false)
        #expect(detector.armed == true)
        #expect(result == false)
    }

    @Test("does not trigger at 0.25 when not armed")
    func doesNotTriggerWhenNotArmed() {
        var detector = StallDetector(highMark: 0.75, lowMark: 0.25, debounceCount: 1)
        let result = detector.evaluate(fillRatio: 0.25, hasQueuedPackets: false, isReconnecting: false)
        #expect(result == false)
        #expect(detector.armed == false)
    }

    @Test("triggers when armed and below low mark (debounce=1)")
    func triggersWhenArmedAndBelowLowMark() {
        var detector = StallDetector(highMark: 0.75, lowMark: 0.25, debounceCount: 1)
        _ = detector.evaluate(fillRatio: 0.80, hasQueuedPackets: false, isReconnecting: false)
        #expect(detector.armed == true)
        let result = detector.evaluate(fillRatio: 0.10, hasQueuedPackets: false, isReconnecting: false)
        #expect(result == true)
        #expect(detector.armed == false)
    }

    @Test("does not trigger when isReconnecting is true")
    func doesNotTriggerWhenReconnecting() {
        var detector = StallDetector(highMark: 0.75, lowMark: 0.25, debounceCount: 1)
        _ = detector.evaluate(fillRatio: 0.90, hasQueuedPackets: false, isReconnecting: false)
        let result = detector.evaluate(fillRatio: 0.10, hasQueuedPackets: false, isReconnecting: true)
        #expect(result == false)
    }

    @Test("reset clears armed state")
    func resetClearsArmedState() {
        var detector = StallDetector(highMark: 0.75, lowMark: 0.25, debounceCount: 1)
        _ = detector.evaluate(fillRatio: 0.90, hasQueuedPackets: false, isReconnecting: false)
        #expect(detector.armed == true)
        detector.reset()
        #expect(detector.armed == false)
        let result = detector.evaluate(fillRatio: 0.10, hasQueuedPackets: false, isReconnecting: false)
        #expect(result == false)
    }
}
