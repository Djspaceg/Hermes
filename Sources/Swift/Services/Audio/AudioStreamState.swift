//
//  AudioStreamState.swift
//  Hermes
//
//  State management for audio streaming operations.
//  Extracted from AudioStreamer.swift as part of code modernization.
//

import Foundation

// MARK: - AudioStreamerState

/// Represents the current state of an audio streamer
///
/// The audio streamer progresses through these states during its lifecycle:
/// - `initialized`: Initial state after creation, before streaming begins
/// - `waitingForData`: Waiting for audio data from the network
/// - `waitingForQueueToStart`: Audio data received, waiting for AudioQueue to begin playback
/// - `playing`: Actively playing audio
/// - `paused`: Playback paused by user
/// - `rebuffering`: Reconnecting HTTP stream while AudioQueue continues playing from existing buffers
/// - `done`: Streaming completed (with reason)
/// - `stopped`: Streaming stopped by user or error
public enum AudioStreamerState: Equatable {
    /// Initial state after creation, before streaming begins
    case initialized
    
    /// Waiting for audio data from the network
    case waitingForData
    
    /// Audio data received, waiting for AudioQueue to begin playback
    case waitingForQueueToStart
    
    /// Actively playing audio
    case playing
    
    /// Playback paused by user
    case paused
    
    /// Reconnecting HTTP stream; AudioQueue continues playing from existing buffers
    case rebuffering
    
    /// Streaming completed with a specific reason
    case done(reason: DoneReason)
    
    /// Streaming stopped by user or due to error
    case stopped
    
    /// Reason why the stream is done
    public enum DoneReason: Equatable {
        /// Stream was explicitly stopped
        case stopped
        
        /// Stream ended due to an error
        case error(AudioStreamerError)
        
        /// Stream reached end of file naturally
        case endOfFile
        
        public static func == (lhs: DoneReason, rhs: DoneReason) -> Bool {
            switch (lhs, rhs) {
            case (.stopped, .stopped):
                return true
            case (.endOfFile, .endOfFile):
                return true
            case let (.error(lhsError), .error(rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    /// Returns true if the streamer is in a "done" state (done or stopped)
    public var isDone: Bool {
        switch self {
        case .done, .stopped:
            return true
        case .initialized, .waitingForData, .waitingForQueueToStart, .playing, .paused, .rebuffering:
            return false
        }
    }
    
    /// Returns true if the streamer is waiting for something
    public var isWaiting: Bool {
        switch self {
        case .waitingForData, .waitingForQueueToStart:
            return true
        case .initialized, .playing, .paused, .rebuffering, .done, .stopped:
            return false
        }
    }
    
    /// Returns true if the streamer is reconnecting the HTTP stream
    public var isRebuffering: Bool {
        switch self {
        case .rebuffering:
            return true
        case .initialized, .waitingForData, .waitingForQueueToStart, .playing, .paused, .done, .stopped:
            return false
        }
    }
}
