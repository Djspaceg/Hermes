//
//  AudioStreamError.swift
//  Hermes
//
//  Error types for audio streaming operations.
//  Extracted from AudioStreamer.swift as part of code modernization.
//

import AudioToolbox
import Foundation

// MARK: - AudioStreamerError

/// Errors that can occur during audio streaming
///
/// These error cases provide detailed information about what went wrong during streaming,
/// including CoreAudio OSStatus codes for low-level audio failures.
public enum AudioStreamerError: Error, Equatable, LocalizedError {
    /// Network connection failed
    case networkConnectionFailed(underlyingError: String?)
    
    /// Failed to get property from file stream
    case fileStreamGetPropertyFailed(status: OSStatus)
    
    /// Failed to set property on file stream
    case fileStreamSetPropertyFailed(status: OSStatus)
    
    /// Failed to seek in file stream
    case fileStreamSeekFailed(status: OSStatus)
    
    /// Failed to parse bytes in file stream
    case fileStreamParseFailed(status: OSStatus)
    
    /// Failed to open file stream
    case fileStreamOpenFailed(status: OSStatus)
    
    /// Failed to close file stream
    case fileStreamCloseFailed(status: OSStatus)
    
    /// No audio data found in stream
    case audioDataNotFound
    
    /// Failed to create audio queue
    case audioQueueCreationFailed(status: OSStatus)
    
    /// Failed to allocate audio queue buffer
    case audioQueueBufferAllocationFailed(status: OSStatus)
    
    /// Failed to enqueue buffer to audio queue
    case audioQueueEnqueueFailed(status: OSStatus)
    
    /// Failed to add listener to audio queue
    case audioQueueAddListenerFailed(status: OSStatus)
    
    /// Failed to remove listener from audio queue
    case audioQueueRemoveListenerFailed(status: OSStatus)
    
    /// Failed to start audio queue
    case audioQueueStartFailed(status: OSStatus)
    
    /// Failed to pause audio queue
    case audioQueuePauseFailed(status: OSStatus)
    
    /// Audio queue buffer mismatch
    case audioQueueBufferMismatch
    
    /// Failed to dispose audio queue
    case audioQueueDisposeFailed(status: OSStatus)
    
    /// Failed to stop audio queue
    case audioQueueStopFailed(status: OSStatus)
    
    /// Failed to flush audio queue
    case audioQueueFlushFailed(status: OSStatus)
    
    /// General audio streamer failure
    case audioStreamerFailed
    
    /// Failed to get audio time
    case getAudioTimeFailed(status: OSStatus)
    
    /// Audio buffer too small
    case audioBufferTooSmall
    
    /// Connection timed out
    case timeout
    
    // MARK: - LocalizedError
    
    public var errorDescription: String? {
        switch self {
        case .networkConnectionFailed(let error):
            if let error = error {
                return "Network connection failed: \(error)"
            }
            return "Network connection failed"
            
        case .fileStreamGetPropertyFailed(let status):
            return "File stream get property failed (OSStatus: \(status))"
            
        case .fileStreamSetPropertyFailed(let status):
            return "File stream set property failed (OSStatus: \(status))"
            
        case .fileStreamSeekFailed(let status):
            return "File stream seek failed (OSStatus: \(status))"
            
        case .fileStreamParseFailed(let status):
            return "Parse bytes failed (OSStatus: \(status))"
            
        case .fileStreamOpenFailed(let status):
            return "Failed to open file stream (OSStatus: \(status))"
            
        case .fileStreamCloseFailed(let status):
            return "Failed to close file stream (OSStatus: \(status))"
            
        case .audioDataNotFound:
            return "No audio data found"
            
        case .audioQueueCreationFailed(let status):
            return "Audio queue creation failed (OSStatus: \(status))"
            
        case .audioQueueBufferAllocationFailed(let status):
            return "Audio queue buffer allocation failed (OSStatus: \(status))"
            
        case .audioQueueEnqueueFailed(let status):
            return "Queueing of audio buffer failed (OSStatus: \(status))"
            
        case .audioQueueAddListenerFailed(let status):
            return "Failed to add listener to audio queue (OSStatus: \(status))"
            
        case .audioQueueRemoveListenerFailed(let status):
            return "Failed to remove listener from audio queue (OSStatus: \(status))"
            
        case .audioQueueStartFailed(let status):
            return "Failed to start the audio queue (OSStatus: \(status))"
            
        case .audioQueuePauseFailed(let status):
            return "Failed to pause the audio queue (OSStatus: \(status))"
            
        case .audioQueueBufferMismatch:
            return "Audio queue buffer mismatch"
            
        case .audioQueueDisposeFailed(let status):
            return "Couldn't dispose of audio queue (OSStatus: \(status))"
            
        case .audioQueueStopFailed(let status):
            return "Audio queue stop failed (OSStatus: \(status))"
            
        case .audioQueueFlushFailed(let status):
            return "Failed to flush the audio queue (OSStatus: \(status))"
            
        case .audioStreamerFailed:
            return "Audio streamer failed"
            
        case .getAudioTimeFailed(let status):
            return "Couldn't get audio time (OSStatus: \(status))"
            
        case .audioBufferTooSmall:
            return "Audio buffer too small"
            
        case .timeout:
            return "Connection timed out"
        }
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: AudioStreamerError, rhs: AudioStreamerError) -> Bool {
        switch (lhs, rhs) {
        case let (.networkConnectionFailed(lhsErr), .networkConnectionFailed(rhsErr)):
            return lhsErr == rhsErr
        case let (.fileStreamGetPropertyFailed(lhsStatus), .fileStreamGetPropertyFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case let (.fileStreamSetPropertyFailed(lhsStatus), .fileStreamSetPropertyFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case let (.fileStreamSeekFailed(lhsStatus), .fileStreamSeekFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case let (.fileStreamParseFailed(lhsStatus), .fileStreamParseFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case let (.fileStreamOpenFailed(lhsStatus), .fileStreamOpenFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case let (.fileStreamCloseFailed(lhsStatus), .fileStreamCloseFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case (.audioDataNotFound, .audioDataNotFound):
            return true
        case let (.audioQueueCreationFailed(lhsStatus), .audioQueueCreationFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case let (.audioQueueBufferAllocationFailed(lhsStatus), .audioQueueBufferAllocationFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case let (.audioQueueEnqueueFailed(lhsStatus), .audioQueueEnqueueFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case let (.audioQueueAddListenerFailed(lhsStatus), .audioQueueAddListenerFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case let (.audioQueueRemoveListenerFailed(lhsStatus), .audioQueueRemoveListenerFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case let (.audioQueueStartFailed(lhsStatus), .audioQueueStartFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case let (.audioQueuePauseFailed(lhsStatus), .audioQueuePauseFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case (.audioQueueBufferMismatch, .audioQueueBufferMismatch):
            return true
        case let (.audioQueueDisposeFailed(lhsStatus), .audioQueueDisposeFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case let (.audioQueueStopFailed(lhsStatus), .audioQueueStopFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case let (.audioQueueFlushFailed(lhsStatus), .audioQueueFlushFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case (.audioStreamerFailed, .audioStreamerFailed):
            return true
        case let (.getAudioTimeFailed(lhsStatus), .getAudioTimeFailed(rhsStatus)):
            return lhsStatus == rhsStatus
        case (.audioBufferTooSmall, .audioBufferTooSmall):
            return true
        case (.timeout, .timeout):
            return true
        default:
            return false
        }
    }
}
