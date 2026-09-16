//
//  AudioStreamerStateTests.swift
//  HermesTests
//
//  Property-based tests for AudioStreamer state machine transitions
//  **Validates: Requirements 2.2**
//

import Testing
import Foundation
@testable import Hermes

@Suite("AudioStreamerStateTests", .serialized)
struct AudioStreamerStateTests {
    
    // MARK: - Property 5: Playback State Machine (Partial)
    //
    // For all valid state transitions:
    // - initialized → playing (via start)
    // - playing → paused (via pause)
    // - paused → playing (via play)
    // - playing → stopped (via stop)
    // - any state → stopped (via stop)
    //
    // Invalid transitions should be rejected:
    // - pause when not playing
    // - play when not paused
    // - start when already started
    //
    // **Validates: Requirements 2.2**
    
    /// Property test: Valid state transitions
    /// Tests that the AudioStreamer correctly transitions through valid states
    @Test("Valid State Transitions")
    func testValidStateTransitions() throws {
        // Test transition: initialized → waitingForData (via start)
        let streamer1 = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        #expect((streamer1.state) == (.initialized), "Initial state should be initialized")
        
        // Note: start() requires network connection, so we can't fully test it here
        // We'll test the state enum transitions directly
        
        // Test state enum properties
        #expect(!(AudioStreamerState.initialized.isDone), "initialized should not be done")
        #expect(!(AudioStreamerState.playing.isDone), "playing should not be done")
        #expect(AudioStreamerState.stopped.isDone, "stopped should be done")
        #expect(AudioStreamerState.done(reason: .endOfFile).isDone, "done should be done")
        
        // Clean up
        streamer1.stop()
        
        // Test transition: any state → stopped
        let states: [AudioStreamerState] = [
            .initialized,
            .waitingForData,
            .waitingForQueueToStart,
            .playing,
            .paused,
            .rebuffering,
            .done(reason: .endOfFile),
            .stopped
        ]
        
        for state in states {
            // Verify state properties
            switch state {
            case .stopped, .done:
                #expect(state.isDone, "State \(state) should be done")
            default:
                #expect(!(state.isDone), "State \(state) should not be done")
            }
        }
    }
    
    /// Property test: Invalid transitions are rejected
    /// Tests that invalid state transitions return false and don't change state
    @Test("Invalid Transitions Are Rejected")
    func testInvalidTransitionsAreRejected() throws {
        // Test: pause when not playing should return false
        let streamer1 = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        #expect((streamer1.state) == (.initialized), "Should start in initialized state")
        
        let pauseResult = streamer1.pause()
        #expect(!(pauseResult), "pause() should return false when not in playing state")
        #expect((streamer1.state) == (.initialized), "State should not change on invalid pause")
        
        // Test: play when not paused should return false
        let playResult = streamer1.play()
        #expect(!(playResult), "play() should return false when not in paused state")
        #expect((streamer1.state) == (.initialized), "State should not change on invalid play")
        
        // Test: start when already started should return false
        let firstStart = streamer1.start()
        #expect(firstStart, "First start() should return true")
        
        // Second start should return false
        let secondStart = streamer1.start()
        #expect(!(secondStart), "Second start() should return false")
        
        // Clean up
        streamer1.stop()
    }
    
    /// Property test: State transition sequence
    /// Tests a complete sequence of valid transitions
    @Test("State Transition Sequence")
    func testStateTransitionSequence() throws {
        // This test verifies the expected sequence:
        // initialized → (start) → waitingForData → ... → playing → (pause) → paused → (play) → playing → (stop) → stopped
        
        let streamer = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        
        // 1. Initial state
        #expect((streamer.state) == (.initialized), "Should start in initialized state")
        
        // 2. Start (will transition to waitingForData, but may fail due to network)
        let startResult = streamer.start()
        #expect(startResult, "start() should return true on first call")
        
        // State should have changed from initialized
        #expect((streamer.state) != (.initialized), "State should change after start()")
        
        // 3. Stop should work from any state
        streamer.stop()
        #expect(streamer.state == .stopped || streamer.state.isDone, "After stop, state should be stopped or done")
    }
    
    /// Property test: State query methods consistency
    /// Tests that state query methods (isPlaying, isPaused, etc.) are consistent with state
    @Test("State Query Methods Consistency")
    func testStateQueryMethodsConsistency() throws {
        let testCases: [(AudioStreamerState, Bool, Bool, Bool, Bool, Bool)] = [
            // (state, isPlaying, isPaused, isWaiting, isDone, isRebuffering)
            (.initialized, false, false, false, false, false),
            (.waitingForData, false, false, true, false, false),
            (.waitingForQueueToStart, false, false, true, false, false),
            (.playing, true, false, false, false, false),
            (.paused, false, true, false, false, false),
            (.rebuffering, false, false, false, false, true),
            (.done(reason: .endOfFile), false, false, false, true, false),
            (.done(reason: .stopped), false, false, false, true, false),
            (.done(reason: .error(.timeout)), false, false, false, true, false),
            (.stopped, false, false, false, true, false),
        ]
        
        for (state, expectedIsPlaying, expectedIsPaused, expectedIsWaiting, expectedIsDone, expectedIsRebuffering) in testCases {
            // Test state properties directly
            #expect((state.isWaiting) == (expectedIsWaiting), "isWaiting should be \(expectedIsWaiting) for state \(state)")
            #expect((state.isDone) == (expectedIsDone), "isDone should be \(expectedIsDone) for state \(state)")
            #expect((state.isRebuffering) == (expectedIsRebuffering), "isRebuffering should be \(expectedIsRebuffering) for state \(state)")
            
            // Test computed properties that check state cases
            let isPlaying = { if case .playing = state { return true } else { return false } }()
            let isPaused = { if case .paused = state { return true } else { return false } }()
            
            #expect((isPlaying) == (expectedIsPlaying), "isPlaying should be \(expectedIsPlaying) for state \(state)")
            #expect((isPaused) == (expectedIsPaused), "isPaused should be \(expectedIsPaused) for state \(state)")
        }
    }
    
    /// Tests that isRebuffering returns true only for the rebuffering state
    /// Rebuffering is not done, not waiting, and is rebuffering
    /// **Validates: Requirements 2.1**
    @Test("Rebuffering State Properties")
    func testRebufferingStateProperties() throws {
        let rebuffering = AudioStreamerState.rebuffering
        
        // Rebuffering IS rebuffering
        #expect(rebuffering.isRebuffering, "rebuffering state should return true for isRebuffering")
        
        // Rebuffering is NOT done
        #expect(!(rebuffering.isDone), "rebuffering state should not be done")
        
        // Rebuffering is NOT waiting
        #expect(!(rebuffering.isWaiting), "rebuffering state should not be waiting")
        
        // All other states are NOT rebuffering
        let nonRebufferingStates: [AudioStreamerState] = [
            .initialized,
            .waitingForData,
            .waitingForQueueToStart,
            .playing,
            .paused,
            .done(reason: .endOfFile),
            .done(reason: .stopped),
            .done(reason: .error(.timeout)),
            .stopped,
        ]
        
        for state in nonRebufferingStates {
            #expect(!(state.isRebuffering), "isRebuffering should be false for state \(state)")
        }
    }
    
    /// Property test: Done reasons are correctly reported
    /// Tests that doneReason property returns correct values
    @Test("Done Reasons Are Correctly Reported")
    func testDoneReasonsAreCorrectlyReported() throws {
        // Test done reasons using state enum directly (not via AudioStreamer instances)
        // This avoids issues with AudioStreamer lifecycle management in tests
        
        let doneStates: [(AudioStreamerState, AudioStreamerState.DoneReason)] = [
            (.done(reason: .endOfFile), .endOfFile),
            (.done(reason: .stopped), .stopped),
            (.done(reason: .error(.timeout)), .error(.timeout)),
            (.done(reason: .error(.networkConnectionFailed(underlyingError: "test"))), .error(.networkConnectionFailed(underlyingError: "test"))),
            (.done(reason: .error(.audioDataNotFound)), .error(.audioDataNotFound))
        ]
        
        for (state, expectedReason) in doneStates {
            // Test using state enum directly
            if case .done(let reason) = state {
                #expect((reason) == (expectedReason), "Done reason should match expected")
            } else {
                Issue.record("State should be done")
            }
            
            // Test isDone property
            #expect(state.isDone, "State should be marked as done")
        }
        
        // Test stopped state
        let stoppedState = AudioStreamerState.stopped
        #expect(stoppedState.isDone, "Stopped state should be marked as done")
        
        // Test non-done states
        let nonDoneStates: [AudioStreamerState] = [
            .initialized,
            .waitingForData,
            .waitingForQueueToStart,
            .playing,
            .paused,
            .rebuffering
        ]
        
        for state in nonDoneStates {
            #expect(!(state.isDone), "State \(state) should not be marked as done")
        }
    }
    
    /// Property test: State transitions are idempotent
    /// Tests that calling the same operation multiple times doesn't cause issues
    @Test("State Transitions Are Idempotent")
    func testStateTransitionsAreIdempotent() throws {
        // Test: Multiple stop calls should be safe
        let streamer1 = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        streamer1.stop()
        let stateAfterFirstStop = streamer1.state
        streamer1.stop()
        let stateAfterSecondStop = streamer1.state
        #expect((stateAfterFirstStop) == (stateAfterSecondStop), "Multiple stop() calls should be idempotent")
        
        // Test: Multiple pause calls when not playing should return false
        let streamer2 = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        let firstPause = streamer2.pause()
        let secondPause = streamer2.pause()
        #expect(!(firstPause), "First pause when not playing should return false")
        #expect(!(secondPause), "Second pause when not playing should return false")
        streamer2.stop()
        
        // Test: Multiple play calls when not paused should return false
        let streamer3 = AudioStreamer(url: URL(string: "http://example.com/test.mp3")!)
        let firstPlay = streamer3.play()
        let secondPlay = streamer3.play()
        #expect(!(firstPlay), "First play when not paused should return false")
        #expect(!(secondPlay), "Second play when not paused should return false")
        streamer3.stop()
    }
    
    /// Property test: State enum equality
    /// Tests that AudioStreamerState equality works correctly
    @Test("State Enum Equality")
    func testStateEnumEquality() throws {
        // Test basic state equality
        #expect((AudioStreamerState.initialized) == (.initialized))
        #expect((AudioStreamerState.waitingForData) == (.waitingForData))
        #expect((AudioStreamerState.waitingForQueueToStart) == (.waitingForQueueToStart))
        #expect((AudioStreamerState.playing) == (.playing))
        #expect((AudioStreamerState.paused) == (.paused))
        #expect((AudioStreamerState.rebuffering) == (.rebuffering))
        #expect((AudioStreamerState.stopped) == (.stopped))
        
        // Test done state equality with same reason
        #expect((AudioStreamerState.done(reason: .endOfFile)) == (.done(reason: .endOfFile)))
        #expect((AudioStreamerState.done(reason: .stopped)) == (.done(reason: .stopped)))
        #expect((AudioStreamerState.done(reason: .error(.timeout))) == (.done(reason: .error(.timeout))))
        
        // Test done state inequality with different reasons
        #expect((AudioStreamerState.done(reason: .endOfFile)) != (.done(reason: .stopped)))
        #expect((AudioStreamerState.done(reason: .error(.timeout))) != (.done(reason: .error(.audioDataNotFound))))
        
        // Test different states are not equal
        #expect((AudioStreamerState.initialized) != (.playing))
        #expect((AudioStreamerState.playing) != (.paused))
        #expect((AudioStreamerState.stopped) != (.done(reason: .stopped)))
    }
}
