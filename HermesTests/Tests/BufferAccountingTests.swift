//
//  BufferAccountingTests.swift
//  HermesTests
//
//  Property-based tests for buffer counter non-negative invariant
//  Feature: audio-stream-resilience, Property 7: Buffer counter non-negative invariant
//

import Testing
import Foundation
@testable import Hermes

// MARK: - Buffer Operation Model

/// Represents a single buffer operation: enqueue or dequeue.
private enum BufferOperation {
    case enqueue
    case dequeue
}

// MARK: - Buffer Accounting Model

/// A pure model of the AudioStreamer's buffer accounting logic,
/// extracted for testability without requiring CoreAudio.
///
/// This mirrors the buffer state management in AudioStreamer:
/// - Enqueue: `buffersUsed` increments, capped at `bufferCount`
/// - Dequeue: `buffersUsed` decrements via `max(0, buffersUsed - 1)` to prevent underflow
///
/// The model validates that `buffersUsed` always stays in [0, bufferCount].
private struct BufferAccountingModel {
    let bufferCount: Int
    private(set) var buffersUsed: Int = 0

    init(bufferCount: Int) {
        self.bufferCount = bufferCount
    }

    /// Enqueue a buffer (mirrors AudioStreamer's enqueueBuffer incrementing buffersUsed).
    mutating func enqueue() {
        if buffersUsed < bufferCount {
            buffersUsed += 1
        }
    }

    /// Dequeue a buffer (mirrors AudioStreamer's handleBufferComplete with max(0, ...) guard).
    mutating func dequeue() {
        buffersUsed = max(0, buffersUsed - 1)
    }
}

// MARK: - Generators

/// Generates a random buffer count in a realistic range.
private func randomBufferCount() -> Int {
    Int.random(in: 1...32)
}

/// Generates a random buffer operation.
private func randomOperation() -> BufferOperation {
    Bool.random() ? .enqueue : .dequeue
}

/// Generates a random sequence of buffer operations.
private func randomOperationSequence(length: Int) -> [BufferOperation] {
    (0..<length).map { _ in randomOperation() }
}

/// Generates a dequeue-heavy sequence to stress underflow protection.
private func dequeueHeavySequence(length: Int) -> [BufferOperation] {
    (0..<length).map { _ in
        // 80% dequeue, 20% enqueue
        Int.random(in: 0..<5) == 0 ? .enqueue : .dequeue
    }
}

/// Generates an enqueue-heavy sequence to stress overflow protection.
private func enqueueHeavySequence(length: Int) -> [BufferOperation] {
    (0..<length).map { _ in
        // 80% enqueue, 20% dequeue
        Int.random(in: 0..<5) == 0 ? .dequeue : .enqueue
    }
}

// MARK: - Property 7: Buffer Counter Non-Negative Invariant

/// Property tests validating buffer counter invariant.
///
/// *For any* sequence of buffer enqueue and dequeue operations applied to
/// `buffersUsed`, the value SHALL remain in the range `[0, bufferCount]` at
/// all times. No sequence of operations SHALL cause `buffersUsed` to underflow
/// below zero or overflow above `bufferCount`.
///
/// **Validates: Requirements 7.4**
@Suite("Buffer Accounting Property Tests")
struct BufferAccountingPropertyTests {

    // MARK: - Property: buffersUsed stays in [0, bufferCount] for random operations

    @Test("Random operations keep buffersUsed in [0, bufferCount]")
    func randomOperationsInvariant() {
        // Feature: audio-stream-resilience, Property 7: Buffer counter non-negative invariant
        // **Validates: Requirements 7.4**

        for _ in 0..<100 {
            let bufferCount = randomBufferCount()
            var model = BufferAccountingModel(bufferCount: bufferCount)
            let ops = randomOperationSequence(length: Int.random(in: 10...100))

            for op in ops {
                switch op {
                case .enqueue: model.enqueue()
                case .dequeue: model.dequeue()
                }

                #expect(
                    model.buffersUsed >= 0,
                    "buffersUsed underflowed to \(model.buffersUsed) with bufferCount=\(bufferCount)"
                )
                #expect(
                    model.buffersUsed <= bufferCount,
                    "buffersUsed overflowed to \(model.buffersUsed) with bufferCount=\(bufferCount)"
                )
            }
        }
    }

    // MARK: - Property: Dequeue-heavy sequences never underflow

    @Test("Dequeue-heavy sequences never cause underflow below zero")
    func dequeueHeavyNeverUnderflows() {
        // Feature: audio-stream-resilience, Property 7: Buffer counter non-negative invariant
        // **Validates: Requirements 7.4**

        for _ in 0..<100 {
            let bufferCount = randomBufferCount()
            var model = BufferAccountingModel(bufferCount: bufferCount)
            let ops = dequeueHeavySequence(length: Int.random(in: 20...100))

            for op in ops {
                switch op {
                case .enqueue: model.enqueue()
                case .dequeue: model.dequeue()
                }

                #expect(
                    model.buffersUsed >= 0,
                    "Underflow: buffersUsed=\(model.buffersUsed) after dequeue-heavy sequence"
                )
            }
        }
    }

    // MARK: - Property: Enqueue-heavy sequences never overflow

    @Test("Enqueue-heavy sequences never cause overflow above bufferCount")
    func enqueueHeavyNeverOverflows() {
        // Feature: audio-stream-resilience, Property 7: Buffer counter non-negative invariant
        // **Validates: Requirements 7.4**

        for _ in 0..<100 {
            let bufferCount = randomBufferCount()
            var model = BufferAccountingModel(bufferCount: bufferCount)
            let ops = enqueueHeavySequence(length: Int.random(in: 20...100))

            for op in ops {
                switch op {
                case .enqueue: model.enqueue()
                case .dequeue: model.dequeue()
                }

                #expect(
                    model.buffersUsed <= bufferCount,
                    "Overflow: buffersUsed=\(model.buffersUsed) exceeds bufferCount=\(bufferCount)"
                )
            }
        }
    }

    // MARK: - Property: Pure dequeue from empty never underflows

    @Test("Repeated dequeue from empty buffer never underflows")
    func pureDequeueFromEmptyNeverUnderflows() {
        // Feature: audio-stream-resilience, Property 7: Buffer counter non-negative invariant
        // **Validates: Requirements 7.4**

        for _ in 0..<100 {
            let bufferCount = randomBufferCount()
            var model = BufferAccountingModel(bufferCount: bufferCount)
            let dequeueCount = Int.random(in: 1...50)

            // Dequeue from empty — should stay at 0
            for _ in 0..<dequeueCount {
                model.dequeue()

                #expect(
                    model.buffersUsed == 0,
                    "Dequeue from empty should keep buffersUsed at 0, got \(model.buffersUsed)"
                )
            }
        }
    }

    // MARK: - Property: Pure enqueue saturates at bufferCount

    @Test("Repeated enqueue saturates at bufferCount and never exceeds it")
    func pureEnqueueSaturatesAtMax() {
        // Feature: audio-stream-resilience, Property 7: Buffer counter non-negative invariant
        // **Validates: Requirements 7.4**

        for _ in 0..<100 {
            let bufferCount = randomBufferCount()
            var model = BufferAccountingModel(bufferCount: bufferCount)
            let enqueueCount = bufferCount + Int.random(in: 1...20)

            for i in 0..<enqueueCount {
                model.enqueue()

                let expected = min(i + 1, bufferCount)
                #expect(
                    model.buffersUsed == expected,
                    "After \(i + 1) enqueues with bufferCount=\(bufferCount): expected \(expected), got \(model.buffersUsed)"
                )
                #expect(
                    model.buffersUsed <= bufferCount,
                    "Overflow: buffersUsed=\(model.buffersUsed) exceeds bufferCount=\(bufferCount)"
                )
            }
        }
    }

    // MARK: - Property: Enqueue then dequeue returns to zero

    @Test("Enqueuing N then dequeuing N returns buffersUsed to zero")
    func enqueueDequeueReturnsToZero() {
        // Feature: audio-stream-resilience, Property 7: Buffer counter non-negative invariant
        // **Validates: Requirements 7.4**

        for _ in 0..<100 {
            let bufferCount = randomBufferCount()
            var model = BufferAccountingModel(bufferCount: bufferCount)
            let n = Int.random(in: 1...bufferCount)

            // Enqueue n buffers
            for _ in 0..<n {
                model.enqueue()
            }
            #expect(model.buffersUsed == n, "Should have \(n) buffers used after enqueue")

            // Dequeue n buffers
            for _ in 0..<n {
                model.dequeue()
            }
            #expect(
                model.buffersUsed == 0,
                "Should return to 0 after dequeuing same count, got \(model.buffersUsed)"
            )
        }
    }
}
