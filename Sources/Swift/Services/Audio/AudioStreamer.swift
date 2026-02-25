//
//  AudioStreamer.swift
//  Hermes
//
//  Swift implementation of audio streaming using CoreAudio's AudioQueue framework.
//  Based on original implementation by Matt Gallagher, heavily modified for Hermes.
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
public let kDefaultNumAQBufs: UInt32 = 32

/// Default size of each audio queue buffer
public let kDefaultAQDefaultBufSize: UInt32 = 4096

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
public final class AudioStreamer: NSObject, AudioStreaming {
    
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
    
    // URLSession for HTTP streaming
    private var urlSession: URLSession?
    private var dataTask: URLSessionDataTask?
    // Alias for compatibility with existing code that checks `stream != nil`
    private var stream: URLSessionDataTask? {
        get { dataTask }
        set { dataTask = newValue }
    }
    
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
    private var queueTimeOffset: Double = 0  // Subtracted from queue time after reconnect
    
    // Bitrate calculation
    private var processedPacketsCount: UInt64 = 0
    private var processedPacketsSizeTotal: UInt64 = 0
    private var bitrateNotificationSent = false
    
    // Connection retry management
    private var connectionResetCount: Int = 0
    private var maxConnectionResets: Int = 5
    private var retryTimer: Timer?
    private var isRetrying = false
    
    // MARK: - Reconnection State
    
    /// Current count of in-place reconnect attempts (resets on success)
    private(set) var reconnectAttempts: Int = 0
    
    /// Maximum allowed in-place reconnect attempts before escalating
    let maxReconnectAttempts: Int = 5
    
    /// Backoff configuration for stream-level retries
    var streamerBackoff: BackoffStrategy = .streamerDefault
    
    /// Hysteresis-based buffer health monitor for proactive stall detection
    var stallDetector: StallDetector = StallDetector(highMark: 0.75, lowMark: 0.40)
    
    /// Buffer fill ratio at last timeout check
    private(set) var lastFillRatio: Double = 0.0
    
    /// Timer for scheduled reconnect attempts
    var reconnectTimer: Timer?
    
    /// Whether we've registered a listener for default output device changes
    private var hasDeviceChangeListener = false
    
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
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
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
        
        // Remove audio device change listener
        removeDeviceChangeListener()
        
        buffers.removeAll()
        bufferInUse.removeAll()
        
        httpHeaders = nil
        bytesFilled = 0
        packetsFilled = 0
        seekByteOffset = 0
        packetBufferSize = 0
        connectionResetCount = 0
        isRetrying = false
        reconnectAttempts = 0
        stallDetector.reset()
        lastFillRatio = 0.0
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
        case .playing, .paused, .rebuffering:
            break // Allow progress query when playing, paused, or rebuffering
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
        
        var progress = seekTime + (queueTime.mSampleTime / sampleRate) - queueTimeOffset
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
    
    /// Compact timestamp for debug logging (seconds.milliseconds within the current hour)
    var ts: String {
        let t = Date().timeIntervalSince1970
        let seconds = t.truncatingRemainder(dividingBy: 3600)
        return String(format: "%.3f", seconds)
    }
    
    // MARK: - State Management
    
    func setState(_ newState: AudioStreamerState) {
        guard state != newState else {
            return
        }
        
        let oldState = state
        state = newState
        
        print("📡 [\(ts)] \(oldState) → \(newState) | buffers=\(buffersUsed)/\(bufferCount) | reconnectAttempts=\(reconnectAttempts)")
        
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
            print("⚠️ [\(ts)] already failed, ignoring: \(error)")
            return
        }
        
        print("❌ [\(ts)] TERMINAL: \(error) | \(state) | buffers=\(buffersUsed)/\(bufferCount) | reconnect=\(reconnectAttempts)")
        
        // Save last progress
        _ = progress()
        
        errorCode = error
        
        // Set done-with-error state BEFORE cleanup so Playlist sees the error
        setState(.done(reason: .error(error)))
        
        // Clean up resources (but don't change state again)
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        retryTimer?.invalidate()
        retryTimer = nil
        
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
        
        // Remove audio device change listener
        removeDeviceChangeListener()
        
        // Clear buffer arrays through bufferQueue to synchronize with
        // pending handleBufferComplete callbacks on the audio thread
        bufferQueue.sync {
            buffers.removeAll()
            bufferInUse.removeAll()
        }
        httpHeaders = nil
    }
    
    // MARK: - Timeout Handling
    
    func checkTimeout() {
        // Ignore if paused or already rebuffering (reconnect in progress)
        // Requirements: 6.4
        if case .paused = state { return }
        if case .rebuffering = state { return }
        
        let currentFillRatio = bufferCount > 0 ? Double(buffersUsed) / Double(bufferCount) : 0.0
        
        if eventCount > 0 {
            // Data arrived, but check if buffers are still draining fast
            // Requirements: 6.1, 6.2
            if lastFillRatio - currentFillRatio > 0.20 {
                // Trickle of data but buffers draining fast — treat as stalled
                print("Smart timeout: data arrived but fill ratio dropped \(String(format: "%.0f", (lastFillRatio - currentFillRatio) * 100))pp (\(String(format: "%.2f", lastFillRatio)) → \(String(format: "%.2f", currentFillRatio))), treating as stalled")
                attemptInPlaceReconnect()
            }
            eventCount = 0
            lastFillRatio = currentFillRatio
            return
        }
        
        // No data at all — reconnect instead of terminal failure
        // Requirements: 6.3
        print("Smart timeout: no data received, attempting in-place reconnect")
        attemptInPlaceReconnect()
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
        
        // Calculate exponential backoff delay: 1s, 2s, 4s, 8s, 16s
        let delay = min(pow(2.0, Double(connectionResetCount - 1)), 16.0)
        
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
    
    // MARK: - In-Place Reconnection
    
    /// Attempts an in-place reconnect: closes only the CFReadStream (preserving
    /// the AudioQueue and its buffered audio), then reopens the stream with a
    /// Range header so playback can resume seamlessly.
    ///
    /// On success (data arrives in the read-stream callback), the state
    /// transitions back to `.playing` and `reconnectAttempts` resets to zero.
    /// On max retries exceeded, escalates via `failWithError`.
    ///
    /// - Requirements: 1.1, 1.2, 1.3, 1.4, 2.2, 2.3, 5.4, 5.5
    func attemptInPlaceReconnect() {
        // If we're near the end of the song (within 5% of duration or 10s),
        // just let it finish naturally instead of reconnecting endlessly
        if let prog = progress() ?? Optional(lastProgress),
           let dur = duration(),
           dur > 0 && prog > dur * 0.95 {
            print("🔄 [\(ts)] near end of song (\(String(format: "%.1f", prog))s / \(String(format: "%.1f", dur))s), letting it finish")
            setState(.done(reason: .endOfFile))
            return
        }
        
        // Guard against exceeding max attempts
        guard reconnectAttempts < maxReconnectAttempts else {
            print("⚠️ [\(ts)] max reconnect attempts (\(maxReconnectAttempts)) exceeded")
            reconnectTimer?.invalidate()
            reconnectTimer = nil
            failWithError(.networkConnectionFailed(underlyingError: "Max reconnect attempts exceeded"))
            return
        }
        
        let currentState = state
        let currentBuffers = buffersUsed
        let totalBuffers = bufferCount
        
        print("🔄 [\(ts)] reconnect \(reconnectAttempts + 1)/\(maxReconnectAttempts) | \(currentState) | buffers=\(currentBuffers)/\(totalBuffers)")
        
        // Transition to rebuffering — AudioQueue keeps playing from existing buffers
        setState(.rebuffering)
        
        // Close ONLY the CFReadStream, NOT the AudioQueue
        closeReadStream()
        
        // Compute backoff delay for this attempt
        let delay = streamerBackoff.delay(forAttempt: reconnectAttempts)
        reconnectAttempts += 1
        
        print("🔄 [\(ts)] attempt \(reconnectAttempts)/\(maxReconnectAttempts), delay=\(String(format: "%.2f", delay))s")
        
        // Calculate byte offset from current playback position
        updateSeekPositionFromProgress()
        
        // Mark as discontinuous so the AudioFileStream parser handles the gap
        isDiscontinuous = true
        
        // Schedule the reconnect after the backoff delay
        reconnectTimer?.invalidate()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.reconnectTimer = nil
                
                // Bail if we were stopped while waiting
                guard !self.isDone else {
                    print("⚠️ [\(self.ts)] reconnect bailing — done: \(self.state)")
                    return
                }
                
                if !self.openReadStream() {
                    print("⚠️ [\(self.ts)] openReadStream failed, retrying")
                    self.attemptInPlaceReconnect()
                } else {
                    print("🔄 [\(self.ts)] stream reopened | \(self.state)")
                }
            }
        }
    }
    
    /// Updates `seekByteOffset` and `seekTime` based on current playback progress,
    /// so that `openReadStream()` will send the correct Range header.
    func updateSeekPositionFromProgress() {
        let currentProgress = progress() ?? lastProgress
        guard currentProgress > 0,
              let bitrate = calculatedBitRate(),
              let totalDuration = duration(),
              bitrate > 0,
              fileLength > 0 else {
            return
        }
        
        seekByteOffset = dataOffset + UInt64((currentProgress / totalDuration) * Double(fileLength - dataOffset))
        seekTime = currentProgress
        
        // Capture the current AudioQueue time so progress() can compensate
        // after reconnect. The queue keeps its internal clock running, so
        // without this offset, progress = seekTime + fullQueueTime = double-counted.
        if let aq = audioQueue {
            var queueTime = AudioTimeStamp()
            var discontinuity: DarwinBoolean = false
            let sampleRate = audioStreamDescription.mSampleRate
            if sampleRate > 0 {
                let status = AudioQueueGetCurrentTime(aq, nil, &queueTime, &discontinuity)
                if status == noErr {
                    queueTimeOffset = queueTime.mSampleTime / sampleRate
                }
            }
        }
        
        // Don't seek past the end
        if seekByteOffset > fileLength - UInt64(2 * packetBufferSize) {
            seekByteOffset = fileLength - UInt64(2 * packetBufferSize)
        }
        
        print("In-place reconnect: seek to \(String(format: "%.1f", currentProgress))s, byte offset \(seekByteOffset)")
    }
    
    // MARK: - Proactive Reconnect
    
    /// Check buffer health and proactively reconnect if buffers are draining
    /// while the network stream appears stalled. Called from handleBufferComplete.
    ///
    /// Delegates to `StallDetector.evaluate()` which uses hysteresis: buffers
    /// must first reach 75% full (high mark), then drop below 25% (low mark)
    /// with no queued packets and no reconnect in progress to trigger.
    ///
    /// - Requirements: 3.1, 3.2, 3.3, 3.4
    func checkBufferHealth() {
        // Only act during active playback with established audio data
        guard case .playing = state else { return }
        guard bitrateNotificationSent else { return }
        guard bufferCount > 0 else { return }
        
        let fillRatio = Double(buffersUsed) / Double(bufferCount)
        let isReconnecting = state == .rebuffering || isRetrying
        
        // Reset reconnect attempts once buffers are healthy (above high mark)
        if reconnectAttempts > 0 && fillRatio >= stallDetector.highMark {
            print("✅ [\(ts)] stable at \(Int(fillRatio * 100))% — reset reconnect from \(reconnectAttempts)")
            reconnectAttempts = 0
        }
        
        let shouldReconnect = stallDetector.evaluate(
            fillRatio: fillRatio,
            hasQueuedPackets: !queuedPackets.isEmpty,
            isReconnecting: isReconnecting
        )
        
        if shouldReconnect {
            print("🚨 [\(ts)] stall at \(Int(fillRatio * 100))% (\(buffersUsed)/\(bufferCount)) | queued=\(queuedPackets.count)")
            attemptInPlaceReconnect()
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
    
    /// Opens the HTTP data task using URLSession
    func openReadStream() -> Bool {
        guard dataTask == nil else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Hermes/2.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = TimeInterval(timeoutInterval)
        
        // Set Range header for seeking
        if fileLength > 0 && seekByteOffset > 0 {
            request.setValue("bytes=\(seekByteOffset)-\(fileLength - 1)", forHTTPHeaderField: "Range")
            isDiscontinuous = true
            seekByteOffset = 0
        }
        
        // Configure URLSession with proxy if needed
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval(timeoutInterval)
        config.timeoutIntervalForResource = 3600 // 1 hour max for a stream
        
        switch proxyType {
        case .http:
            if let host = proxyHost, let port = proxyPort {
                config.connectionProxyDictionary = [
                    kCFNetworkProxiesHTTPEnable as String: true,
                    kCFNetworkProxiesHTTPProxy as String: host,
                    kCFNetworkProxiesHTTPPort as String: port
                ]
            }
        case .socks:
            if let host = proxyHost, let port = proxyPort {
                config.connectionProxyDictionary = [
                    kCFNetworkProxiesSOCKSEnable as String: true,
                    kCFNetworkProxiesSOCKSProxy as String: host,
                    kCFNetworkProxiesSOCKSPort as String: port
                ]
            }
        case .system:
            break // URLSession uses system proxy by default
        }
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        urlSession = session
        
        let task = session.dataTask(with: request)
        dataTask = task
        
        setState(.waitingForData)
        task.resume()
        
        return true
    }
    
    func closeReadStream() {
        waitingOnBuffer = false
        queuedPackets.removeAll()
        
        dataTask?.cancel()
        dataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }
}


// MARK: - URLSessionDataDelegate

extension AudioStreamer: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard dataTask === self.dataTask else {
            completionHandler(.cancel)
            return
        }
        
        eventCount += 1
        
        if let httpResponse = response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode
            
            if statusCode >= 400 {
                let category = ErrorClassifier.classifyHTTPStatus(statusCode)
                switch category {
                case .retriable:
                    print("🌐 [\(ts)] retriable HTTP \(statusCode), reconnecting")
                    completionHandler(.cancel)
                    attemptInPlaceReconnect()
                    return
                case .nonRetriable:
                    print("❌ [\(ts)] non-retriable HTTP \(statusCode)")
                    completionHandler(.cancel)
                    failWithError(.networkConnectionFailed(underlyingError: "HTTP \(statusCode)"))
                    return
                }
            }
            
            // Store headers
            var headers: [String: String] = [:]
            for (key, value) in httpResponse.allHeaderFields {
                if let k = key as? String, let v = value as? String {
                    headers[k] = v
                }
            }
            httpHeaders = headers
            
            // Read content length if not seeking
            if seekByteOffset == 0, let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
               let length = UInt64(contentLength) {
                fileLength = length
            }
        }
        
        // Open audio file stream if needed
        if audioFileStream == nil {
            if !openAudioFileStream() {
                completionHandler(.cancel)
                return
            }
        }
        
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard dataTask === self.dataTask, !isDone else { return }
        
        eventCount += 1
        
        // Handle reconnect state transitions
        if case .rebuffering = state {
            print("✅ [\(ts)] data in rebuffering | buffers=\(buffersUsed)/\(bufferCount)")
            stallDetector.reset()
            setDefaultOutputDevice()
        } else if case .waitingForData = state, reconnectAttempts > 0 {
            print("✅ [\(ts)] data in waitingForData | buffers=\(buffersUsed)/\(bufferCount) | reconnect=\(reconnectAttempts)")
            stallDetector.reset()
            setDefaultOutputDevice()
        } else if case .waitingForQueueToStart = state, reconnectAttempts > 0 {
            if let aq = audioQueue {
                var isRunning: UInt32 = 0
                var size = UInt32(MemoryLayout<UInt32>.size)
                AudioQueueGetProperty(aq, kAudioQueueProperty_IsRunning, &isRunning, &size)
                if isRunning == 0 && buffersUsed > 0 {
                    print("✅ [\(ts)] restarting stopped queue | buffers=\(buffersUsed)/\(bufferCount)")
                    AudioQueueStart(aq, nil)
                }
            }
        }
        
        // Parse the audio data
        let parseFlags: AudioFileStreamParseFlags = isDiscontinuous ? .discontinuity : []
        data.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            let status = AudioFileStreamParseBytes(
                audioFileStream!,
                UInt32(data.count),
                baseAddress,
                parseFlags
            )
            if status != noErr {
                failWithError(.fileStreamParseFailed(status: status))
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard task === self.dataTask else { return }
        
        eventCount += 1
        
        if let error = error {
            // Cancelled tasks are expected during reconnect — not an error
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
            
            networkError = error
            print("🌐 [\(ts)] stream error | \(state) | reconnect=\(reconnectAttempts)")
            
            let category = ErrorClassifier.classify(error)
            switch category {
            case .retriable:
                print("🌐 [\(ts)] retriable: \(nsError.domain)/\(nsError.code) | \(state) | reconnect=\(reconnectAttempts)")
                attemptInPlaceReconnect()
            case .nonRetriable:
                print("❌ [\(ts)] non-retriable: \(nsError.domain)/\(nsError.code) | \(state)")
                failWithError(.networkConnectionFailed(underlyingError: error.localizedDescription))
            }
        } else {
            // Stream completed normally
            timeoutTimer?.invalidate()
            timeoutTimer = nil
            
            // Flush remaining data
            if bytesFilled > 0 {
                _ = enqueueBuffer()
            }
            
            if case .waitingForData = state {
                setState(.done(reason: .endOfFile))
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Follow redirects automatically
        completionHandler(request)
    }
}

// MARK: - AudioFileStream Setup

private extension AudioStreamer {
    
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


// MARK: - Audio Device Change Handling

/// C callback for default output device changes
private func defaultOutputDeviceChanged(
    objectID: AudioObjectID,
    numberAddresses: UInt32,
    addresses: UnsafePointer<AudioObjectPropertyAddress>,
    clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData = clientData else { return noErr }
    let streamer = Unmanaged<AudioStreamer>.fromOpaque(clientData).takeUnretainedValue()
    DispatchQueue.main.async {
        streamer.setDefaultOutputDevice()
    }
    return noErr
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
        
        // Listen for default output device changes so we can update the AudioQueue
        if !hasDeviceChangeListener {
            let selfPtr = Unmanaged.passUnretained(self).toOpaque()
            let listenerStatus = AudioObjectAddPropertyListener(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                defaultOutputDeviceChanged,
                selfPtr
            )
            if listenerStatus == noErr {
                hasDeviceChangeListener = true
            }
        }
    }
    
    func removeDeviceChangeListener() {
        guard hasDeviceChangeListener else { return }
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            defaultOutputDeviceChanged,
            selfPtr
        )
        hasDeviceChangeListener = false
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
        guard stream != nil, let audioQueue = audioQueue else { return -1 }
        
        // Serialize buffer tracking mutations through bufferQueue.
        // enqueueBuffer is called from the main thread (via stream callbacks),
        // so we use sync to get the result back immediately.
        // Requirements: 7.1, 7.3, 7.4
        let index = bufferQueue.sync { () -> Int? in
            let idx = Int(fillBufferIndex)
            guard !bufferInUse[idx] else { return nil }
            
            bufferInUse[idx] = true
            buffersUsed += 1
            return idx
        }
        
        guard let index = index else { return -1 }
        
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
        let isRecovering = reconnectAttempts > 0
        let needsStart: Bool
        
        switch state {
        case .waitingForData:
            needsStart = bufferCount < 3 || buffersUsed > 2
        case .rebuffering:
            needsStart = buffersUsed > 0
        case .waitingForQueueToStart where isRecovering:
            // Queue stopped during recovery — restart it
            var isRunning: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            AudioQueueGetProperty(audioQueue, kAudioQueueProperty_IsRunning, &isRunning, &size)
            needsStart = isRunning == 0 && buffersUsed > 0
        default:
            needsStart = false
        }
        
        if needsStart {
            let startStatus = AudioQueueStart(audioQueue, nil)
            if startStatus != noErr {
                failWithError(.audioQueueStartFailed(status: startStatus))
                return -1
            }
            
            if isRecovering {
                // During reconnect: go straight to playing.
                // The isRunning property callback is unreliable after stop/start cycles.
                print("🔄 [\(ts)] queue started | \(state) | buffers=\(buffersUsed)/\(bufferCount)")
                setState(.playing)
            } else {
                // Normal startup: wait for isRunning callback
                setState(.waitingForQueueToStart)
            }
        }
        
        // Move to next buffer and reset fill counters — serialized through bufferQueue
        // Requirements: 7.1, 7.3
        let nextBufferInUse = bufferQueue.sync { () -> Bool in
            fillBufferIndex = (fillBufferIndex + 1) % bufferCount
            bytesFilled = 0
            packetsFilled = 0
            let idx = Int(fillBufferIndex)
            guard idx < bufferInUse.count else { return false }
            return bufferInUse[idx]
        }
        
        // Check if stream ended (URLSession completion handled via delegate)
        if queuedPackets.isEmpty && dataTask == nil {
            AudioQueueFlush(audioQueue)
        }
        
        // Check if next buffer is available
        if nextBufferInUse {
            // With URLSession, we can't unschedule the stream — just mark as waiting
            waitingOnBuffer = true
            return 0
        }
        
        return 1
    }

    
    func handleBufferComplete(queue: AudioQueueRef, buffer: AudioQueueBufferRef) {
        // Ignore if queue was disposed
        guard audioQueue != nil, queue == audioQueue else { return }
        
        // Serialize all buffer state mutations through bufferQueue.
        // handleBufferComplete is called from AudioQueue's internal thread,
        // so we dispatch async to avoid blocking the audio callback.
        // The buffer lookup is done inside the block to avoid TOCTOU races
        // with stop() clearing the arrays between the lookup and the async dispatch.
        // Requirements: 7.1, 7.2, 7.4
        bufferQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Find which buffer was freed — inside the serialized block so
            // it's consistent with the bufferInUse array state
            guard let index = self.buffers.firstIndex(where: { $0 == buffer }) else { return }
            
            // Guard against accessing cleared arrays after stop()
            guard index < self.bufferInUse.count else { return }
            
            guard self.bufferInUse[index] else { return }
            
            // Mark buffer as free
            self.bufferInUse[index] = false
            let oldBuffersUsed = self.buffersUsed
            self.buffersUsed = max(0, self.buffersUsed - 1)
            
            if oldBuffersUsed != self.buffersUsed {
                // Only log during reconnect recovery or when buffers are critically low
                #if DEBUG
                if self.reconnectAttempts > 0 || self.buffersUsed <= 3 {
                    let ts = String(format: "%.3f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000))
                    print("🔽 [\(ts)] buffer \(index) freed | \(self.buffersUsed)/\(self.bufferCount) (\(Int(Double(self.buffersUsed)/Double(self.bufferCount)*100))%) | \(self.state)")
                }
                #endif
            }
            
            if case .stopped = self.state {
                return
            }
            
            // Check if stream ended and no more data
            if self.buffersUsed == 0 && self.queuedPackets.isEmpty {
                if self.dataTask == nil {
                    // Stream already completed — stop the queue
                    AudioQueueStop(self.audioQueue!, true)
                    return
                }
            }
            
            // Proactive stall detection: evaluate buffer health and trigger
            // in-place reconnect if buffers are draining with no data incoming.
            // Requirements: 3.1, 3.2, 3.3, 3.4
            self.checkBufferHealth()
            
            // If we were waiting for a buffer, process cached data
            if self.waitingOnBuffer {
                self.waitingOnBuffer = false
                DispatchQueue.main.async { [weak self] in
                    self?.enqueueCachedData()
                }
            }
        }
    }
    
    func enqueueCachedData() {
        // Read buffer state through bufferQueue for thread safety
        let canProceed = bufferQueue.sync { () -> Bool in
            let idx = Int(fillBufferIndex)
            guard idx < bufferInUse.count else { return false }
            return !bufferInUse[idx]
        }
        guard !isDone, !waitingOnBuffer, canProceed, stream != nil else { return }
        
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
        // (URLSession manages its own scheduling — nothing to do here)
        if queuedPackets.isEmpty {
            isRescheduled = true
        }
    }
    
    func handleQueuePropertyChange(queue: AudioQueueRef, propertyID: AudioQueuePropertyID) {
        guard propertyID == kAudioQueueProperty_IsRunning else { return }
        guard let audioQueue = audioQueue, queue == audioQueue else { return }
        
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioQueueGetProperty(audioQueue, kAudioQueueProperty_IsRunning, &isRunning, &size)
        
        print("🔊 [\(ts)] isRunning=\(isRunning) | \(state) | seeking=\(isSeeking) | reconnect=\(reconnectAttempts)")
        
        // During reconnect recovery, ignore isRunning changes entirely.
        // The enqueueBuffer method handles all queue start/restart logic.
        if reconnectAttempts > 0 {
            if status == noErr && isRunning == 0 {
                // Queue stopped during recovery — trigger another reconnect
                print("🔄 [\(ts)] queue stopped during recovery, reconnect \(reconnectAttempts + 1)/\(maxReconnectAttempts)")
                attemptInPlaceReconnect()
            }
            return
        }
        
        if case .waitingForQueueToStart = state {
            if status == noErr && isRunning != 0 {
                setState(.playing)
            }
        } else if status == noErr && isRunning == 0 && !isSeeking {
            if case .rebuffering = state {
                print("🔊 [\(ts)] stopped during rebuffering — waiting")
                return
            }
            print("🔊 [\(ts)] stopped → done(endOfFile) | \(state)")
            setState(.done(reason: .endOfFile))
        }
    }
}
