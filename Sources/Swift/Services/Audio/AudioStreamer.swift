//
//  AudioStreamer.swift
//  Hermes
//
//  Swift implementation of audio streaming using CoreAudio's AudioQueue framework.
//  Migrated from Objective-C AudioStreamer.{h,m}
//
//  Original implementation by Matt Gallagher, heavily modified for Hermes.
//

import AudioToolbox
import CoreAudio
import Foundation

// MARK: - Notifications

/// Notification posted when the audio streamer's bitrate becomes available
public let ASBitrateReadyNotification = Notification.Name("ASBitrateReadyNotification")

/// Notification posted when the audio streamer's status changes
public let ASStatusChangedNotification = Notification.Name("ASStatusChangedNotification")

/// Distributed notification for state changes (for external observers)
public let ASDidChangeStateDistributedNotification = Notification.Name("hermes.state")

// MARK: - AudioStreamerState

/// Represents the current state of an audio streamer
///
/// The audio streamer progresses through these states during its lifecycle:
/// - `initialized`: Initial state after creation, before streaming begins
/// - `waitingForData`: Waiting for audio data from the network
/// - `waitingForQueueToStart`: Audio data received, waiting for AudioQueue to begin playback
/// - `playing`: Actively playing audio
/// - `paused`: Playback paused by user
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
        default:
            return false
        }
    }
    
    /// Returns true if the streamer is waiting for something
    public var isWaiting: Bool {
        switch self {
        case .waitingForData, .waitingForQueueToStart:
            return true
        default:
            return false
        }
    }
}

// MARK: - AudioStreamerError

/// Errors that can occur during audio streaming
///
/// These error cases correspond to the original Objective-C error codes
/// and provide detailed information about what went wrong during streaming.
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

// MARK: - AudioStreaming Protocol

/// Protocol defining the interface for audio streaming operations
///
/// This protocol abstracts the audio streaming functionality, allowing for
/// different implementations and easier testing through mock objects.
public protocol AudioStreaming: AnyObject {
    
    // MARK: - Properties
    
    /// The current state of the audio streamer
    var state: AudioStreamerState { get }
    
    /// The URL of the audio source
    var url: URL { get }
    
    /// HTTP headers received from the server (available after connection)
    var httpHeaders: [String: String]? { get }
    
    /// Number of audio buffers to use (default: 16)
    var bufferCount: UInt32 { get set }
    
    /// Size of each audio buffer in bytes (default: 2048)
    var bufferSize: UInt32 { get set }
    
    /// Whether to buffer the entire stream (default: false)
    var bufferInfinite: Bool { get set }
    
    /// Timeout interval in seconds for network operations (default: 10)
    var timeoutInterval: Int { get set }
    
    /// Optional file type hint for the audio stream
    var fileType: AudioFileTypeID? { get set }
    
    // MARK: - Lifecycle
    
    /// Starts playback of the audio stream
    ///
    /// This method can only be invoked once. All properties (like proxies)
    /// must be set before this method is invoked.
    ///
    /// - Returns: `true` if the stream was started, `false` if already started
    @discardableResult
    func start() -> Bool
    
    /// Stops all streams, cleaning up resources
    ///
    /// This method may be invoked at any time. It sets the state to `.stopped`
    /// if not already `.stopped` or `.done`.
    func stop()
    
    /// Pauses the audio stream if playing
    ///
    /// - Returns: `true` if paused successfully, `false` if not in playing state
    @discardableResult
    func pause() -> Bool
    
    /// Resumes playback if paused
    ///
    /// - Returns: `true` if resumed successfully, `false` if not in paused state
    @discardableResult
    func play() -> Bool
    
    // MARK: - Audio Properties
    
    /// Sets the volume of the audio stream
    ///
    /// - Parameter volume: Volume level from 0.0 (silent) to 1.0 (full volume)
    /// - Returns: `true` if volume was set, `false` if audio queue not ready
    @discardableResult
    func setVolume(_ volume: Double) -> Bool
    
    /// Seeks to a specific time in the audio stream
    ///
    /// This can only succeed once the bit rate is known. Seeking involves
    /// re-opening the connection with the proper byte offset.
    ///
    /// - Parameter time: Time in seconds to seek to
    /// - Returns: `true` if seek will be performed, `false` if not enough info
    @discardableResult
    func seekToTime(_ time: Double) -> Bool
    
    /// Returns the current playback progress in seconds
    ///
    /// - Returns: Current progress, or `nil` if not available
    func progress() -> Double?
    
    /// Returns the total duration of the audio stream in seconds
    ///
    /// - Returns: Duration, or `nil` if not yet determined
    func duration() -> Double?
    
    /// Returns the calculated bit rate of the stream
    ///
    /// - Returns: Bit rate in bits per second, or `nil` if not yet calculated
    func calculatedBitRate() -> Double?
    
    // MARK: - Proxy Configuration
    
    /// Sets an HTTP proxy for this stream
    ///
    /// - Parameters:
    ///   - host: The address/hostname of the proxy
    ///   - port: The port of the proxy
    func setHTTPProxy(host: String, port: Int)
    
    /// Sets a SOCKS proxy for this stream
    ///
    /// - Parameters:
    ///   - host: The address/hostname of the proxy
    ///   - port: The port of the proxy
    func setSOCKSProxy(host: String, port: Int)
    
    // MARK: - State Queries
    
    /// Returns `true` if the stream is currently playing
    var isPlaying: Bool { get }
    
    /// Returns `true` if the stream is currently paused
    var isPaused: Bool { get }
    
    /// Returns `true` if the stream is waiting (for data or queue)
    var isWaiting: Bool { get }
    
    /// Returns `true` if the stream is done (completed or stopped)
    var isDone: Bool { get }
    
    /// Returns the reason the stream is done, if applicable
    var doneReason: AudioStreamerState.DoneReason? { get }
}

// MARK: - Default Implementations

public extension AudioStreaming {
    
    var isPlaying: Bool {
        if case .playing = state {
            return true
        }
        return false
    }
    
    var isPaused: Bool {
        if case .paused = state {
            return true
        }
        return false
    }
    
    var isWaiting: Bool {
        state.isWaiting
    }
    
    var isDone: Bool {
        state.isDone
    }
    
    var doneReason: AudioStreamerState.DoneReason? {
        if case .done(let reason) = state {
            return reason
        }
        if case .stopped = state {
            return .stopped
        }
        return nil
    }
}

// MARK: - Constants

/// Maximum number of packet descriptions per buffer
public let kAQMaxPacketDescs: UInt32 = 512

/// Default number of audio queue buffers
public let kDefaultNumAQBufs: UInt32 = 16

/// Default size of each audio queue buffer
public let kDefaultAQDefaultBufSize: UInt32 = 2048

/// Minimum packets needed for bit rate estimation
public let kBitRateEstimationMinPackets: UInt64 = 50
//
//  AudioStreamerImpl.swift
//  Hermes
//
//  Swift implementation of audio streaming using CoreAudio's AudioQueue framework.
//  This file contains the AudioStreamer class implementation.
//

import AudioToolbox
import CoreAudio
import Foundation

// MARK: - Queued Packet

/// Internal structure for caching packets when buffers are full
private struct QueuedPacket {
    var description: AudioStreamPacketDescription
    var data: Data
    var next: UnsafeMutablePointer<QueuedPacket>?
}

// MARK: - AudioStreamer Implementation

/// Audio streamer using CoreAudio's AudioQueue framework
///
/// This class implements a pipeline of three components to stream audio:
/// ```
/// CFReadStream => AudioFileStream => AudioQueue
/// ```
///
/// - **CFReadStream**: Reads HTTP data with proxy support
/// - **AudioFileStream**: Parses audio data and extracts packets
/// - **AudioQueue**: Manages playback buffers and audio output
///
/// Thread safety is managed via a dedicated DispatchQueue for buffer operations.
public final class AudioStreamer: AudioStreaming {
    
    // MARK: - Public Properties
    
    public let url: URL
    public private(set) var state: AudioStreamerState = .initialized
    public private(set) var httpHeaders: [String: String]?
    
    // Configuration (must be set before start())
    public var bufferCount: UInt32 = kDefaultNumAQBufs
    public var bufferSize: UInt32 = kDefaultAQDefaultBufSize
    public var bufferInfinite: Bool = false
    public var timeoutInterval: Int = 10
    public var fileType: AudioFileTypeID?
    
    // MARK: - Private Properties
    
    /// Synchronization queue for thread-safe buffer management
    private let bufferQueue = DispatchQueue(label: "com.hermes.audiostreamer.buffer", qos: .userInteractive)
    
    // Proxy configuration
    private var proxyType: ProxyType = .system
    private var proxyHost: String?
    private var proxyPort: Int?
    
    // CFReadStream for HTTP
    private var stream: CFReadStream?
    
    // Timeout management
    private var timeoutTimer: Timer?
    private var isUnscheduled = false
    private var isRescheduled = false
    private var eventCount = 0
    
    // AudioFileStream for parsing
    private var audioFileStream: AudioFileStreamID?
    
    // File metadata
    private var fileLength: UInt64 = 0
    private var dataOffset: UInt64 = 0
    private var audioDataByteCount: UInt64 = 0
    private var audioStreamDescription = AudioStreamBasicDescription()
    
    // AudioQueue for playback
    private var audioQueue: AudioQueueRef?
    private var packetBufferSize: UInt32 = 0
    
    // Buffer management
    private var buffers: [AudioQueueBufferRef?] = []
    private var packetDescriptions: [AudioStreamPacketDescription] = []
    private var packetsFilled: UInt32 = 0
    private var bytesFilled: UInt32 = 0
    private var fillBufferIndex: UInt32 = 0
    private var bufferInUse: [Bool] = []
    private var buffersUsed: UInt32 = 0
    
    // Packet cache (when buffers are full)
    private var waitingOnBuffer = false
    private var queuedPackets: [QueuedPacketData] = []
    
    // State tracking
    private var errorCode: AudioStreamerError?
    private var networkError: Error?
    private var lastOSStatus: OSStatus = noErr
    
    // Seeking
    private var isDiscontinuous = false
    private var seekByteOffset: UInt64 = 0
    private var seekTime: Double = 0
    private var isSeeking = false
    private var lastProgress: Double = 0
    
    // Bitrate calculation
    private var processedPacketsCount: UInt64 = 0
    private var processedPacketsSizeTotal: UInt64 = 0
    private var bitrateNotificationSent = false
    
    // Connection retry management
    private var connectionResetCount: Int = 0
    private var maxConnectionResets: Int = 3
    private var retryTimer: Timer?
    private var isRetrying = false
    
    // MARK: - Initialization
    
    public init(url: URL) {
        self.url = url
        self.packetDescriptions = Array(repeating: AudioStreamPacketDescription(), count: Int(kAQMaxPacketDescs))
    }
    
    deinit {
        stop()
    }
    
    /// Factory method to create a new audio streamer
    public static func stream(with url: URL) -> AudioStreamer {
        AudioStreamer(url: url)
    }
    
    // MARK: - Proxy Configuration
    
    public func setHTTPProxy(host: String, port: Int) {
        proxyType = .http
        proxyHost = host
        proxyPort = port
    }
    
    public func setSOCKSProxy(host: String, port: Int) {
        proxyType = .socks
        proxyHost = host
        proxyPort = port
    }
    
    // MARK: - Playback Control
    
    @discardableResult
    public func start() -> Bool {
        guard stream == nil else {
            return false
        }
        
        assert(audioQueue == nil)
        assert(state == .initialized)
        
        // Reset connection retry counter on fresh start
        connectionResetCount = 0
        
        guard openReadStream() else {
            return false
        }
        
        // Schedule timeout timer on main run loop
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timeoutTimer = Timer.scheduledTimer(
                withTimeInterval: TimeInterval(self.timeoutInterval),
                repeats: true
            ) { [weak self] _ in
                self?.checkTimeout()
            }
        }
        
        return true
    }
    
    public func stop() {
        if !isDone {
            setState(.stopped)
        }
        
        // Invalidate timers
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        retryTimer?.invalidate()
        retryTimer = nil
        
        // Clean up streams
        closeReadStream()
        
        if let audioFileStream = audioFileStream {
            AudioFileStreamClose(audioFileStream)
            self.audioFileStream = nil
        }
        
        if let audioQueue = audioQueue {
            AudioQueueStop(audioQueue, true)
            AudioQueueDispose(audioQueue, true)
            self.audioQueue = nil
        }
        
        buffers.removeAll()
        bufferInUse.removeAll()
        
        httpHeaders = nil
        bytesFilled = 0
        packetsFilled = 0
        seekByteOffset = 0
        packetBufferSize = 0
        connectionResetCount = 0
        isRetrying = false
    }
    
    @discardableResult
    public func pause() -> Bool {
        guard case .playing = state else {
            return false
        }
        
        guard let audioQueue = audioQueue else {
            return false
        }
        
        let status = AudioQueuePause(audioQueue)
        if status != noErr {
            failWithError(.audioQueuePauseFailed(status: status))
            return false
        }
        
        setState(.paused)
        return true
    }
    
    @discardableResult
    public func play() -> Bool {
        guard case .paused = state else {
            return false
        }
        
        guard let audioQueue = audioQueue else {
            return false
        }
        
        let status = AudioQueueStart(audioQueue, nil)
        if status != noErr {
            failWithError(.audioQueueStartFailed(status: status))
            return false
        }
        
        setState(.playing)
        return true
    }
    
    // MARK: - Audio Properties
    
    @discardableResult
    public func setVolume(_ volume: Double) -> Bool {
        guard let audioQueue = audioQueue else {
            return false
        }
        
        let status = AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, Float32(volume))
        return status == noErr
    }
    
    @discardableResult
    public func seekToTime(_ time: Double) -> Bool {
        guard let bitrate = calculatedBitRate(),
              let totalDuration = duration(),
              bitrate > 0,
              fileLength > 0 else {
            return false
        }
        
        guard !isSeeking else {
            return false
        }
        
        isSeeking = true
        
        // Calculate byte offset for seeking
        seekByteOffset = dataOffset + UInt64((time / totalDuration) * Double(fileLength - dataOffset))
        
        // Try to leave some useful data at the end
        if seekByteOffset > fileLength - UInt64(2 * packetBufferSize) {
            seekByteOffset = fileLength - UInt64(2 * packetBufferSize)
        }
        
        seekTime = time
        
        // Try to align with packet boundary
        let packetDuration = Double(audioStreamDescription.mFramesPerPacket) / audioStreamDescription.mSampleRate
        if packetDuration > 0, bitrate > 0, let audioFileStream = audioFileStream {
            var ioFlags: AudioFileStreamSeekFlags = []
            var packetAlignedByteOffset: Int64 = 0
            let seekPacket = Int64(floor(time / packetDuration))
            
            let status = AudioFileStreamSeek(audioFileStream, seekPacket, &packetAlignedByteOffset, &ioFlags)
            if status == noErr && !ioFlags.contains(.offsetIsEstimated) {
                seekTime -= (Double(seekByteOffset - dataOffset) - Double(packetAlignedByteOffset)) * 8.0 / bitrate
                seekByteOffset = UInt64(packetAlignedByteOffset) + dataOffset
            }
        }
        
        closeReadStream()
        
        // Stop audio queue
        if let audioQueue = audioQueue {
            let status = AudioQueueStop(audioQueue, true)
            if status != noErr {
                isSeeking = false
                failWithError(.audioQueueStopFailed(status: status))
                return false
            }
        }
        
        // Open new stream with offset
        let result = openReadStream()
        isSeeking = false
        return result
    }
    
    public func progress() -> Double? {
        let sampleRate = audioStreamDescription.mSampleRate
        
        if case .stopped = state {
            return lastProgress
        }
        
        guard sampleRate > 0 else {
            return nil
        }
        
        switch state {
        case .playing, .paused:
            break // Allow progress query when playing or paused
        default:
            return nil
        }
        
        guard let audioQueue = audioQueue else {
            return nil
        }
        
        var queueTime = AudioTimeStamp()
        var discontinuity: DarwinBoolean = false
        
        let status = AudioQueueGetCurrentTime(audioQueue, nil, &queueTime, &discontinuity)
        if status != noErr {
            return nil
        }
        
        var progress = seekTime + queueTime.mSampleTime / sampleRate
        if progress < 0 {
            progress = 0
        }
        
        lastProgress = progress
        return progress
    }
    
    public func duration() -> Double? {
        guard let bitrate = calculatedBitRate(), bitrate > 0, fileLength > 0 else {
            return nil
        }
        
        return Double(fileLength - dataOffset) / (bitrate * 0.125)
    }
    
    public func calculatedBitRate() -> Double? {
        let sampleRate = audioStreamDescription.mSampleRate
        let framesPerPacket = audioStreamDescription.mFramesPerPacket
        
        guard sampleRate > 0, framesPerPacket > 0 else {
            return nil
        }
        
        let packetDuration = Double(framesPerPacket) / sampleRate
        
        guard packetDuration > 0, processedPacketsCount > kBitRateEstimationMinPackets else {
            return nil
        }
        
        let averagePacketByteSize = Double(processedPacketsSizeTotal) / Double(processedPacketsCount)
        // bits/byte × bytes/packet × packets/sec = bits/sec
        return 8.0 * averagePacketByteSize / packetDuration
    }
}

// MARK: - Private Implementation

private extension AudioStreamer {
    
    // MARK: - State Management
    
    func setState(_ newState: AudioStreamerState) {
        guard state != newState else {
            return
        }
        
        state = newState
        
        // Post notification on main thread
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: ASStatusChangedNotification,
                object: self
            )
        }
        
        // Post distributed notification for external observers
        var statusString: String?
        switch newState {
        case .playing:
            statusString = "playing"
        case .paused:
            statusString = "paused"
        case .stopped:
            statusString = "stopped"
        default:
            break
        }
        
        if let statusString = statusString {
            DistributedNotificationCenter.default().postNotificationName(
                ASDidChangeStateDistributedNotification,
                object: "hermes",
                userInfo: ["state": statusString],
                deliverImmediately: true
            )
        }
    }
    
    func failWithError(_ error: AudioStreamerError) {
        // Only set error once
        guard errorCode == nil else {
            return
        }
        
        // Save last progress
        _ = progress()
        
        errorCode = error
        stop()
    }
    
    // MARK: - Timeout Handling
    
    func checkTimeout() {
        // Ignore if paused
        if case .paused = state {
            return
        }
        
        // If unscheduled and not rescheduled, ignore
        if isUnscheduled && !isRescheduled {
            return
        }
        
        // If rescheduled after unscheduled, clear flags
        if isRescheduled && isUnscheduled {
            isUnscheduled = false
            isRescheduled = false
            return
        }
        
        // Events happened? No timeout
        if eventCount > 0 {
            eventCount = 0
            return
        }
        
        networkError = NSError(domain: "AudioStreamer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timed out"])
        failWithError(.timeout)
    }
    
    // MARK: - Connection Reset Handling
    
    func handleConnectionReset() {
        connectionResetCount += 1
        
        print("Connection reset detected (attempt \(connectionResetCount)/\(maxConnectionResets))")
        
        // If we've exceeded max retries, fail permanently
        guard connectionResetCount <= maxConnectionResets else {
            print("Max connection reset retries exceeded, failing")
            failWithError(.networkConnectionFailed(underlyingError: "Connection reset by peer (max retries exceeded)"))
            return
        }
        
        // Save current progress for resume
        let currentProgress = progress() ?? 0
        
        // Close the current stream
        closeReadStream()
        
        // Calculate exponential backoff delay: 0.5s, 1s, 2s
        let delay = pow(2.0, Double(connectionResetCount - 1)) * 0.5
        
        print("Retrying connection in \(delay)s...")
        
        // Schedule retry with exponential backoff
        isRetrying = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.retryTimer?.invalidate()
            self.retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.retryConnection(fromProgress: currentProgress)
            }
        }
    }
    
    func retryConnection(fromProgress progress: Double) {
        guard isRetrying else { return }
        
        print("Attempting to reconnect and resume from \(progress)s...")
        
        isRetrying = false
        retryTimer?.invalidate()
        retryTimer = nil
        
        // If we have bitrate info, seek to the last position
        if progress > 0, calculatedBitRate() != nil {
            seekTime = progress
            
            // Calculate byte offset for seeking
            if let bitrate = calculatedBitRate(), let totalDuration = duration(), bitrate > 0, fileLength > 0 {
                seekByteOffset = dataOffset + UInt64((progress / totalDuration) * Double(fileLength - dataOffset))
                
                // Try to leave some useful data at the end
                if seekByteOffset > fileLength - UInt64(2 * packetBufferSize) {
                    seekByteOffset = fileLength - UInt64(2 * packetBufferSize)
                }
            }
        }
        
        // Reopen the stream
        if !openReadStream() {
            // If reopening fails, escalate to permanent failure
            failWithError(.networkConnectionFailed(underlyingError: "Failed to reopen stream after connection reset"))
        }
    }
    
    // MARK: - File Type Hints
    
    static func hintForFileExtension(_ ext: String) -> AudioFileTypeID {
        switch ext.lowercased() {
        case "mp3":
            return kAudioFileMP3Type
        case "wav":
            return kAudioFileWAVEType
        case "aifc":
            return kAudioFileAIFCType
        case "aiff":
            return kAudioFileAIFFType
        case "m4a":
            return kAudioFileM4AType
        case "mp4":
            return kAudioFileMPEG4Type
        case "caf":
            return kAudioFileCAFType
        case "aac":
            return kAudioFileAAC_ADTSType
        default:
            return 0
        }
    }
    
    static func hintForMIMEType(_ mimeType: String) -> AudioFileTypeID {
        switch mimeType.lowercased() {
        case "audio/mpeg":
            return kAudioFileMP3Type
        case "audio/x-wav":
            return kAudioFileWAVEType
        case "audio/x-aiff":
            return kAudioFileAIFFType
        case "audio/x-m4a":
            return kAudioFileM4AType
        case "audio/mp4":
            return kAudioFileMPEG4Type
        case "audio/x-caf":
            return kAudioFileCAFType
        case "audio/aac", "audio/aacp":
            return kAudioFileAAC_ADTSType
        default:
            return 0
        }
    }
}

// MARK: - Queued Packet Data

private struct QueuedPacketData {
    var description: AudioStreamPacketDescription
    var data: Data
}


// MARK: - HTTP Streaming

private extension AudioStreamer {
    
    /// Opens the HTTP read stream with proxy support
    func openReadStream() -> Bool {
        guard stream == nil else {
            return false
        }
        
        // Create HTTP GET request
        guard let message = CFHTTPMessageCreateRequest(
            nil,
            "GET" as CFString,
            url as CFURL,
            kCFHTTPVersion1_1
        ).takeRetainedValue() as CFHTTPMessage? else {
            failWithError(.networkConnectionFailed(underlyingError: "Failed to create HTTP request"))
            return false
        }
        
        // Set User-Agent header (required by some servers)
        CFHTTPMessageSetHeaderFieldValue(
            message,
            "User-Agent" as CFString,
            "Hermes/2.0" as CFString
        )
        
        // Set Range header for seeking
        if fileLength > 0 && seekByteOffset > 0 {
            let rangeValue = "bytes=\(seekByteOffset)-\(fileLength - 1)"
            CFHTTPMessageSetHeaderFieldValue(message, "Range" as CFString, rangeValue as CFString)
            isDiscontinuous = true
            seekByteOffset = 0
        }
        
        // Create read stream for HTTP request
        stream = CFReadStreamCreateForHTTPRequest(nil, message).takeRetainedValue()
        
        guard let stream = stream else {
            failWithError(.fileStreamOpenFailed(status: -1))
            return false
        }
        
        // Enable automatic redirect following
        CFReadStreamSetProperty(
            stream,
            CFStreamPropertyKey(rawValue: kCFStreamPropertyHTTPShouldAutoredirect),
            kCFBooleanTrue
        )
        
        // Configure proxy
        configureProxy(for: stream)
        
        // Configure SSL for HTTPS
        if url.absoluteString.hasPrefix("https") {
            configureSSL(for: stream)
        }
        
        setState(.waitingForData)
        
        // Open the stream
        guard CFReadStreamOpen(stream) else {
            failWithError(.fileStreamOpenFailed(status: -1))
            return false
        }
        
        // Set up stream callbacks
        var clientContext = CFStreamClientContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let eventTypes: CFStreamEventType = [
            .hasBytesAvailable,
            .errorOccurred,
            .endEncountered
        ]
        
        CFReadStreamSetClient(stream, eventTypes.rawValue, readStreamCallback, &clientContext)
        CFReadStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.commonModes)
        
        return true
    }

    
    func configureProxy(for stream: CFReadStream) {
        switch proxyType {
        case .http:
            if let host = proxyHost, let port = proxyPort {
                let proxySettings: [String: Any] = [
                    kCFStreamPropertyHTTPProxyHost as String: host,
                    kCFStreamPropertyHTTPProxyPort as String: port
                ]
                CFReadStreamSetProperty(stream, CFStreamPropertyKey(rawValue: kCFStreamPropertyHTTPProxy), proxySettings as CFDictionary)
            }
            
        case .socks:
            if let host = proxyHost, let port = proxyPort {
                let proxySettings: [String: Any] = [
                    kCFStreamPropertySOCKSProxyHost as String: host,
                    kCFStreamPropertySOCKSProxyPort as String: port
                ]
                CFReadStreamSetProperty(stream, CFStreamPropertyKey(rawValue: kCFStreamPropertySOCKSProxy), proxySettings as CFDictionary)
            }
            
        case .system:
            if let systemProxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() {
                CFReadStreamSetProperty(stream, CFStreamPropertyKey(rawValue: kCFStreamPropertyHTTPProxy), systemProxySettings)
            }
        }
    }
    
    func configureSSL(for stream: CFReadStream) {
        let sslSettings: [String: Any] = [
            kCFStreamSSLLevel as String: kCFStreamSocketSecurityLevelNegotiatedSSL,
            kCFStreamSSLValidatesCertificateChain as String: true
        ]
        CFReadStreamSetProperty(stream, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLSettings), sslSettings as CFDictionary)
    }
    
    func closeReadStream() {
        waitingOnBuffer = false
        queuedPackets.removeAll()
        
        if let stream = stream {
            CFReadStreamClose(stream)
            self.stream = nil
        }
    }
}


// MARK: - Stream Callbacks

/// C callback for CFReadStream events
private func readStreamCallback(
    stream: CFReadStream?,
    eventType: CFStreamEventType,
    clientInfo: UnsafeMutableRawPointer?
) {
    guard let clientInfo = clientInfo else { return }
    let streamer = Unmanaged<AudioStreamer>.fromOpaque(clientInfo).takeUnretainedValue()
    streamer.handleReadStreamEvent(stream: stream, eventType: eventType)
}

private extension AudioStreamer {
    
    func handleReadStreamEvent(stream: CFReadStream?, eventType: CFStreamEventType) {
        guard stream === self.stream else { return }
        
        eventCount += 1
        
        switch eventType {
        case .errorOccurred:
            if let cfError = CFReadStreamCopyError(stream) {
                let error = cfError as Error
                networkError = error
                
                // Check if this is a connection reset (error 54)
                let nsError = error as NSError
                if nsError.domain == kCFErrorDomainPOSIX as String && nsError.code == 54 {
                    handleConnectionReset()
                } else {
                    failWithError(.networkConnectionFailed(underlyingError: error.localizedDescription))
                }
            } else {
                failWithError(.networkConnectionFailed(underlyingError: nil))
            }
            
        case .endEncountered:
            timeoutTimer?.invalidate()
            timeoutTimer = nil
            
            // Flush remaining data
            if bytesFilled > 0 {
                if enqueueBuffer() < 0 {
                    return
                }
            }
            
            // If we never received packets, we're done
            if case .waitingForData = state {
                setState(.done(reason: .endOfFile))
            }
            
        case .hasBytesAvailable:
            handleBytesAvailable()
            
        default:
            break
        }
    }

    
    func handleBytesAvailable() {
        guard let stream = stream else { return }
        
        // Read HTTP headers if not yet done
        if httpHeaders == nil {
            readHTTPHeaders(from: stream)
        }
        
        // Open audio file stream if needed
        if audioFileStream == nil {
            guard openAudioFileStream() else { return }
        }
        
        // Read and parse audio data
        var buffer = [UInt8](repeating: 0, count: 2048)
        
        for _ in 0..<3 {
            guard !isDone, CFReadStreamHasBytesAvailable(stream) else { break }
            
            let bytesRead = CFReadStreamRead(stream, &buffer, buffer.count)
            
            if bytesRead < 0 {
                failWithError(.audioDataNotFound)
                return
            } else if bytesRead == 0 {
                return
            }
            
            // Parse the audio data
            let parseFlags: AudioFileStreamParseFlags = isDiscontinuous ? .discontinuity : []
            let status = AudioFileStreamParseBytes(
                audioFileStream!,
                UInt32(bytesRead),
                buffer,
                parseFlags
            )
            
            if status != noErr {
                failWithError(.fileStreamParseFailed(status: status))
                return
            }
        }
    }
    
    func readHTTPHeaders(from stream: CFReadStream) {
        guard let response = CFReadStreamCopyProperty(stream, CFStreamPropertyKey(rawValue: kCFStreamPropertyHTTPResponseHeader)) else {
            return
        }
        
        let httpMessage = response as! CFHTTPMessage
        if let headers = CFHTTPMessageCopyAllHeaderFields(httpMessage)?.takeRetainedValue() as? [String: String] {
            httpHeaders = headers
            
            // Read content length if not seeking
            if seekByteOffset == 0, let contentLength = headers["Content-Length"], let length = UInt64(contentLength) {
                fileLength = length
            }
        }
    }
    
    func openAudioFileStream() -> Bool {
        // Determine file type
        var type = fileType ?? 0
        
        if type == 0 {
            // Try MIME type first
            if let mimeType = httpHeaders?["Content-Type"] {
                type = Self.hintForMIMEType(mimeType)
            }
            
            // Fall back to file extension
            if type == 0 {
                type = Self.hintForFileExtension(url.pathExtension)
            }
            
            // Default to MP3
            if type == 0 {
                type = kAudioFileMP3Type
            }
        }
        
        // Create audio file stream
        var streamID: AudioFileStreamID?
        let status = AudioFileStreamOpen(
            Unmanaged.passUnretained(self).toOpaque(),
            propertyListenerCallback,
            packetsCallback,
            type,
            &streamID
        )
        
        if status != noErr {
            failWithError(.fileStreamOpenFailed(status: status))
            return false
        }
        
        audioFileStream = streamID
        return true
    }
}


// MARK: - AudioFileStream Callbacks

/// C callback for AudioFileStream property changes
private func propertyListenerCallback(
    clientData: UnsafeMutableRawPointer,
    audioFileStream: AudioFileStreamID,
    propertyID: AudioFileStreamPropertyID,
    ioFlags: UnsafeMutablePointer<AudioFileStreamPropertyFlags>
) {
    let streamer = Unmanaged<AudioStreamer>.fromOpaque(clientData).takeUnretainedValue()
    streamer.handlePropertyChange(propertyID: propertyID)
}

/// C callback for AudioFileStream packets
private func packetsCallback(
    clientData: UnsafeMutableRawPointer,
    numberBytes: UInt32,
    numberPackets: UInt32,
    inputData: UnsafeRawPointer,
    packetDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?
) {
    guard let packetDescriptions = packetDescriptions else { return }
    let streamer = Unmanaged<AudioStreamer>.fromOpaque(clientData).takeUnretainedValue()
    streamer.handleAudioPackets(
        inputData: inputData,
        numberBytes: numberBytes,
        numberPackets: numberPackets,
        packetDescriptions: packetDescriptions
    )
}

private extension AudioStreamer {
    
    func handlePropertyChange(propertyID: AudioFileStreamPropertyID) {
        guard let audioFileStream = audioFileStream else { return }
        
        switch propertyID {
        case kAudioFileStreamProperty_ReadyToProducePackets:
            isDiscontinuous = true
            
        case kAudioFileStreamProperty_DataOffset:
            var offset: Int64 = 0
            var size = UInt32(MemoryLayout<Int64>.size)
            let status = AudioFileStreamGetProperty(audioFileStream, propertyID, &size, &offset)
            if status == noErr {
                dataOffset = UInt64(offset)
                if audioDataByteCount > 0 {
                    fileLength = dataOffset + audioDataByteCount
                }
            }
            
        case kAudioFileStreamProperty_AudioDataByteCount:
            var byteCount: UInt64 = 0
            var size = UInt32(MemoryLayout<UInt64>.size)
            let status = AudioFileStreamGetProperty(audioFileStream, propertyID, &size, &byteCount)
            if status == noErr {
                audioDataByteCount = byteCount
                fileLength = dataOffset + audioDataByteCount
            }
            
        case kAudioFileStreamProperty_DataFormat:
            // Only read if not already set (e.g., from seeking)
            if audioStreamDescription.mSampleRate == 0 {
                var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
                AudioFileStreamGetProperty(audioFileStream, propertyID, &size, &audioStreamDescription)
            }
            
        default:
            break
        }
    }

    
    func handleAudioPackets(
        inputData: UnsafeRawPointer,
        numberBytes: UInt32,
        numberPackets: UInt32,
        packetDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>
    ) {
        guard !isDone else { return }
        
        // Clear discontinuous flag after first successful read
        if isDiscontinuous {
            isDiscontinuous = false
        }
        
        // Create audio queue if needed
        if audioQueue == nil {
            createAudioQueue()
        }
        
        guard audioQueue != nil else { return }
        
        // Process packets
        var i: UInt32 = 0
        while i < numberPackets && !waitingOnBuffer && queuedPackets.isEmpty {
            let desc = packetDescriptions[Int(i)]
            let packetData = inputData.advanced(by: Int(desc.mStartOffset))
            
            let result = handlePacket(data: packetData, description: desc)
            if result < 0 {
                failWithError(.audioQueueEnqueueFailed(status: lastOSStatus))
                return
            }
            if result == 0 {
                break
            }
            i += 1
        }
        
        // Queue remaining packets for later
        while i < numberPackets {
            let desc = packetDescriptions[Int(i)]
            let packetData = Data(bytes: inputData.advanced(by: Int(desc.mStartOffset)), count: Int(desc.mDataByteSize))
            
            var adjustedDesc = desc
            adjustedDesc.mStartOffset = 0
            
            queuedPackets.append(QueuedPacketData(description: adjustedDesc, data: packetData))
            i += 1
        }
    }
    
    func handlePacket(data: UnsafeRawPointer, description: AudioStreamPacketDescription) -> Int {
        guard audioQueue != nil else { return -1 }
        
        let packetSize = description.mDataByteSize
        
        // Check if packet fits in buffer
        if packetSize > packetBufferSize {
            return -1
        }
        
        // If buffer is full, enqueue it
        if packetBufferSize - bytesFilled < packetSize {
            let result = enqueueBuffer()
            if result <= 0 {
                return result
            }
        }
        
        // Update statistics
        processedPacketsSizeTotal += UInt64(packetSize)
        processedPacketsCount += 1
        
        // Post bitrate notification if ready
        if processedPacketsCount > kBitRateEstimationMinPackets && !bitrateNotificationSent {
            bitrateNotificationSent = true
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: ASBitrateReadyNotification, object: self)
            }
        }
        
        // Copy data to buffer
        let buffer = buffers[Int(fillBufferIndex)]!
        memcpy(buffer.pointee.mAudioData.advanced(by: Int(bytesFilled)), data, Int(packetSize))
        
        // Fill packet description
        var desc = description
        desc.mStartOffset = Int64(bytesFilled)
        packetDescriptions[Int(packetsFilled)] = desc
        
        bytesFilled += packetSize
        packetsFilled += 1
        
        // Enqueue if buffer is full of packets
        if packetsFilled >= kAQMaxPacketDescs {
            return enqueueBuffer()
        }
        
        return 1
    }
}


// MARK: - AudioQueue Management

/// C callback for AudioQueue buffer completion
private func audioQueueOutputCallback(
    clientData: UnsafeMutableRawPointer?,
    audioQueue: AudioQueueRef,
    buffer: AudioQueueBufferRef
) {
    guard let clientData = clientData else { return }
    let streamer = Unmanaged<AudioStreamer>.fromOpaque(clientData).takeUnretainedValue()
    streamer.handleBufferComplete(queue: audioQueue, buffer: buffer)
}

/// C callback for AudioQueue property changes
private func audioQueuePropertyCallback(
    clientData: UnsafeMutableRawPointer?,
    audioQueue: AudioQueueRef,
    propertyID: AudioQueuePropertyID
) {
    guard let clientData = clientData else { return }
    let streamer = Unmanaged<AudioStreamer>.fromOpaque(clientData).takeUnretainedValue()
    streamer.handleQueuePropertyChange(queue: audioQueue, propertyID: propertyID)
}

private extension AudioStreamer {
    
    func createAudioQueue() {
        guard audioQueue == nil else { return }
        
        // Create audio queue with NULL run loop (let AudioQueue manage its own threads)
        var queue: AudioQueueRef?
        var status = AudioQueueNewOutput(
            &audioStreamDescription,
            audioQueueOutputCallback,
            Unmanaged.passUnretained(self).toOpaque(),
            nil,
            CFRunLoopMode.commonModes.rawValue,
            0,
            &queue
        )
        
        if status != noErr {
            failWithError(.audioQueueCreationFailed(status: status))
            return
        }
        
        audioQueue = queue
        
        // Set default output device
        setDefaultOutputDevice()
        
        // Add property listener for isRunning
        status = AudioQueueAddPropertyListener(
            queue!,
            kAudioQueueProperty_IsRunning,
            audioQueuePropertyCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        if status != noErr {
            failWithError(.audioQueueAddListenerFailed(status: status))
            return
        }
        
        // Determine packet buffer size
        determinePacketBufferSize()
        
        // Allocate buffers
        allocateBuffers()
        
        // Set magic cookie if available
        setMagicCookie()
    }

    
    func setDefaultOutputDevice() {
        guard let audioQueue = audioQueue else { return }
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var outputDevice: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &outputDevice
        )
        
        if status == noErr && outputDevice != 0 {
            AudioQueueSetProperty(
                audioQueue,
                kAudioQueueProperty_CurrentDevice,
                &outputDevice,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
        }
    }
    
    func determinePacketBufferSize() {
        guard let audioFileStream = audioFileStream else { return }
        
        var size = UInt32(MemoryLayout<UInt32>.size)
        var status = AudioFileStreamGetProperty(
            audioFileStream,
            kAudioFileStreamProperty_PacketSizeUpperBound,
            &size,
            &packetBufferSize
        )
        
        if status != noErr || packetBufferSize == 0 {
            status = AudioFileStreamGetProperty(
                audioFileStream,
                kAudioFileStreamProperty_MaximumPacketSize,
                &size,
                &packetBufferSize
            )
            
            if status != noErr || packetBufferSize == 0 {
                packetBufferSize = bufferSize
            }
        }
    }

    
    func allocateBuffers() {
        guard let audioQueue = audioQueue else { return }
        
        buffers = Array(repeating: nil, count: Int(bufferCount))
        bufferInUse = Array(repeating: false, count: Int(bufferCount))
        
        for i in 0..<Int(bufferCount) {
            var buffer: AudioQueueBufferRef?
            let status = AudioQueueAllocateBuffer(audioQueue, packetBufferSize, &buffer)
            
            if status != noErr {
                failWithError(.audioQueueBufferAllocationFailed(status: status))
                return
            }
            
            buffers[i] = buffer
        }
    }
    
    func setMagicCookie() {
        guard let audioFileStream = audioFileStream, let audioQueue = audioQueue else { return }
        
        var cookieSize: UInt32 = 0
        var writable: DarwinBoolean = false
        
        var status = AudioFileStreamGetPropertyInfo(
            audioFileStream,
            kAudioFileStreamProperty_MagicCookieData,
            &cookieSize,
            &writable
        )
        
        guard status == noErr, cookieSize > 0 else { return }
        
        var cookieData = [UInt8](repeating: 0, count: Int(cookieSize))
        status = AudioFileStreamGetProperty(
            audioFileStream,
            kAudioFileStreamProperty_MagicCookieData,
            &cookieSize,
            &cookieData
        )
        
        guard status == noErr else { return }
        
        AudioQueueSetProperty(
            audioQueue,
            kAudioQueueProperty_MagicCookie,
            cookieData,
            cookieSize
        )
    }

    
    func enqueueBuffer() -> Int {
        guard let stream = stream, let audioQueue = audioQueue else { return -1 }
        
        let index = Int(fillBufferIndex)
        guard !bufferInUse[index] else { return -1 }
        
        bufferInUse[index] = true
        buffersUsed += 1
        
        // Enqueue the buffer
        guard let buffer = buffers[index] else { return -1 }
        buffer.pointee.mAudioDataByteSize = bytesFilled
        
        guard packetsFilled > 0 else { return -1 }
        
        let status = AudioQueueEnqueueBuffer(
            audioQueue,
            buffer,
            packetsFilled,
            packetDescriptions
        )
        
        if status != noErr {
            lastOSStatus = status
            failWithError(.audioQueueEnqueueFailed(status: status))
            return -1
        }
        
        // Start playback if we have enough buffers
        if case .waitingForData = state {
            if bufferCount < 3 || buffersUsed > 2 {
                let startStatus = AudioQueueStart(audioQueue, nil)
                if startStatus != noErr {
                    failWithError(.audioQueueStartFailed(status: startStatus))
                    return -1
                }
                setState(.waitingForQueueToStart)
            }
        }
        
        // Move to next buffer
        fillBufferIndex = (fillBufferIndex + 1) % bufferCount
        bytesFilled = 0
        packetsFilled = 0
        
        // Check if stream ended
        if queuedPackets.isEmpty && CFReadStreamGetStatus(stream) == .atEnd {
            AudioQueueFlush(audioQueue)
        }
        
        // Check if next buffer is available
        if bufferInUse[Int(fillBufferIndex)] {
            if !bufferInfinite {
                CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.commonModes)
                isUnscheduled = true
                isRescheduled = false
            }
            waitingOnBuffer = true
            return 0
        }
        
        return 1
    }

    
    func handleBufferComplete(queue: AudioQueueRef, buffer: AudioQueueBufferRef) {
        // Ignore if queue was disposed
        guard audioQueue != nil, queue == audioQueue else { return }
        
        // Find which buffer was freed
        guard let index = buffers.firstIndex(where: { $0 == buffer }) else { return }
        guard bufferInUse[index] else { return }
        
        // Mark buffer as free
        bufferInUse[index] = false
        buffersUsed -= 1
        
        if case .stopped = state {
            return
        }
        
        // Check if stream ended and no more data
        if buffersUsed == 0 && queuedPackets.isEmpty {
            if let stream = stream, CFReadStreamGetStatus(stream) == .atEnd {
                // Use true for asynchronous stop - this allows remaining buffers to finish
                // and triggers the property change callback
                AudioQueueStop(audioQueue!, true)
                return
            }
        }
        
        // If we were waiting for a buffer, process cached data
        if waitingOnBuffer {
            waitingOnBuffer = false
            DispatchQueue.main.async { [weak self] in
                self?.enqueueCachedData()
            }
        }
    }
    
    func enqueueCachedData() {
        guard !isDone, !waitingOnBuffer, !bufferInUse[Int(fillBufferIndex)], stream != nil else { return }
        
        // Process queued packets
        while !queuedPackets.isEmpty {
            let packet = queuedPackets[0]
            
            let result = packet.data.withUnsafeBytes { ptr -> Int in
                handlePacket(data: ptr.baseAddress!, description: packet.description)
            }
            
            if result < 0 {
                failWithError(.audioQueueEnqueueFailed(status: lastOSStatus))
                return
            }
            
            if result == 0 {
                break
            }
            
            queuedPackets.removeFirst()
        }
        
        // Re-schedule stream if all packets processed
        if queuedPackets.isEmpty, let stream = stream {
            isRescheduled = true
            if !bufferInfinite {
                CFReadStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.commonModes)
            }
        }
    }
    
    func handleQueuePropertyChange(queue: AudioQueueRef, propertyID: AudioQueuePropertyID) {
        guard propertyID == kAudioQueueProperty_IsRunning else { return }
        guard let audioQueue = audioQueue, queue == audioQueue else { return }
        
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioQueueGetProperty(audioQueue, kAudioQueueProperty_IsRunning, &isRunning, &size)
        
        if case .waitingForQueueToStart = state {
            if status == noErr && isRunning != 0 {
                setState(.playing)
            }
        } else if status == noErr && isRunning == 0 && !isSeeking {
            setState(.done(reason: .endOfFile))
        }
    }
}
