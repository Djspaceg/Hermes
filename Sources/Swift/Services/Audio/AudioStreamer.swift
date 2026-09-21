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

// MARK: - AudioStreamer Implementation

/// Audio streamer using CoreAudio's AudioQueue framework
///
/// This class implements a pipeline of three components to stream audio:
/// ```
/// URLSession => AudioFileStream => AudioQueue
/// ```
///
/// - **URLSession**: Reads HTTP data with proxy support
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
    
    /// Key used to detect if we're already executing on the stream queue,
    /// avoiding deadlock when stop() dispatches cleanup synchronously.
    private let streamQueueKey = DispatchSpecificKey<Bool>()
    let streamQueue = DispatchQueue(label: "com.hermes.audiostreamer.stream", qos: .userInteractive)
    
    /// Operation queue wrapping streamQueue, used as the URLSession delegate queue
    /// so network callbacks arrive directly on our audio processing queue.
    private lazy var streamOperationQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.hermes.audiostreamer.stream"
        q.maxConcurrentOperationCount = 1
        q.underlyingQueue = streamQueue
        return q
    }()
    
    /// Synchronization queue for thread-safe buffer management
    let bufferQueue = DispatchQueue(label: "com.hermes.audiostreamer.buffer", qos: .userInteractive)
    
    // Proxy configuration
    private var proxyType: ProxyType = .system
    private var proxyHost: String?
    private var proxyPort: Int?
    
    // URLSession for HTTP streaming
    private var urlSession: URLSession?
    private let dataTaskLock = NSLock()
    private var storedDataTask: URLSessionDataTask?
    var dataTask: URLSessionDataTask? {
        get {
            dataTaskLock.lock()
            defer { dataTaskLock.unlock() }
            return storedDataTask
        }
        set {
            dataTaskLock.lock()
            storedDataTask = newValue
            dataTaskLock.unlock()
        }
    }
    // Alias for compatibility with existing code that checks `stream != nil`
    var stream: URLSessionDataTask? {
        get { dataTask }
        set { dataTask = newValue }
    }
    
    // Timeout management
    private var timeoutSource: DispatchSourceTimer?
    private var eventCount = 0
    
    // AudioFileStream for parsing
    var audioFileStream: AudioFileStreamID?
    
    // File metadata
    var fileLength: UInt64 = 0
    var dataOffset: UInt64 = 0
    var audioDataByteCount: UInt64 = 0
    var audioStreamDescription = AudioStreamBasicDescription()
    
    // AudioQueue for playback
    var audioQueue: AudioQueueRef?
    var packetBufferSize: UInt32 = 0
    
    // Buffer management
    var buffers: [AudioQueueBufferRef?] = []
    var packetDescriptions: [AudioStreamPacketDescription] = []
    var packetsFilled: UInt32 = 0
    var bytesFilled: UInt32 = 0
    var fillBufferIndex: UInt32 = 0
    var bufferInUse: [Bool] = []
    var buffersUsed: UInt32 = 0
    
    // Packet cache (when buffers are full)
    var waitingOnBuffer = false
    var queuedPackets: [QueuedPacketData] = []
    
    // State tracking
    private var errorCode: AudioStreamerError?
    var lastOSStatus: OSStatus = noErr
    
    // Seeking
    var isDiscontinuous = false
    private var seekByteOffset: UInt64 = 0
    private var seekTime: Double = 0
    var isSeeking = false
    private var lastProgress: Double = 0
    private var queueTimeOffset: Double = 0  // Subtracted from queue time after reconnect
    
    // Bitrate calculation
    var processedPacketsCount: UInt64 = 0
    var processedPacketsSizeTotal: UInt64 = 0
    var bitrateNotificationSent = false
    
    // Connection retry management
    private var connectionResetCount: Int = 0
    private var maxConnectionResets: Int = 5
    private var retrySource: DispatchSourceTimer?
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
    var reconnectSource: DispatchSourceTimer?
    
    /// Whether the HTTP stream completed normally (server delivered all data).
    /// When true, draining buffers represent the natural end of the song,
    /// not a network stall — starvation detection should be suppressed.
    var httpStreamCompleted = false
    
    /// Whether we've registered a listener for default output device changes
    var hasDeviceChangeListener = false
    
    /// True while inside AudioFileStreamParseBytes — disposal of the
    /// AudioQueue and AudioFileStream must be deferred until parsing returns,
    /// otherwise the parser dereferences freed internal state (crash).
    private var isParsing = false
    
    /// When failWithError is called mid-parse, the error is stashed here
    /// and cleanup runs after AudioFileStreamParseBytes returns.
    private var deferredError: AudioStreamerError?
    
    // MARK: - Initialization
    
    public init(url: URL) {
        self.url = url
        self.packetDescriptions = Array(repeating: AudioStreamPacketDescription(), count: Int(kAQMaxPacketDescs))
        super.init()
        streamQueue.setSpecific(key: streamQueueKey, value: true)
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
        
        // Schedule timeout timer on the stream queue so it fires
        // independently of main-thread activity.
        let source = DispatchSource.makeTimerSource(queue: streamQueue)
        source.schedule(deadline: .now() + .seconds(timeoutInterval),
                        repeating: .seconds(timeoutInterval))
        source.setEventHandler { [weak self] in
            self?.checkTimeout()
        }
        source.resume()
        timeoutSource = source
        
        return true
    }
    
    public func stop() {
        if !isDone {
            setState(.stopped)
        }
        
        // Cancel dispatch timer sources
        timeoutSource?.cancel()
        timeoutSource = nil
        retrySource?.cancel()
        retrySource = nil
        reconnectSource?.cancel()
        reconnectSource = nil
        
        // Cancel the network task immediately to stop new data arriving.
        // This is safe to call from any thread.
        closeReadStream()
        
        // Dispose AudioQueue and AudioFileStream on the stream queue so we
        // serialize with any in-flight AudioFileStreamParseBytes call.
        // If we're already on the stream queue, run inline.
        let cleanup = { [self] in
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
            
            bufferQueue.sync {
                buffers.removeAll()
                bufferInUse.removeAll()
            }
            
            httpHeaders = nil
            bytesFilled = 0
            packetsFilled = 0
            seekByteOffset = 0
            packetBufferSize = 0
            connectionResetCount = 0
            isRetrying = false
            isParsing = false
            deferredError = nil
            reconnectAttempts = 0
            stallDetector.reset()
            lastFillRatio = 0.0
            httpStreamCompleted = false
        }
        
        // Detect if we're already on the stream queue to avoid deadlock
        if DispatchQueue.getSpecific(key: streamQueueKey) == true {
            cleanup()
        } else {
            streamQueue.sync(execute: cleanup)
        }
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

extension AudioStreamer {
    
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
        
        // If we're inside AudioFileStreamParseBytes, disposing the AudioQueue
        // or AudioFileStream now would free memory the parser is still using,
        // causing a SIGSEGV. Stash the error and let the parse-site run cleanup.
        if isParsing {
            print("⚠️ [\(ts)] mid-parse — deferring cleanup")
            errorCode = error
            deferredError = error
            setState(.done(reason: .error(error)))
            return
        }
        
        // Save last progress
        _ = progress()
        
        errorCode = error
        
        // Set done-with-error state BEFORE cleanup so Playlist sees the error
        setState(.done(reason: .error(error)))
        
        performErrorCleanup()
    }
    
    /// Tears down audio resources. Separated from failWithError so it can
    /// be called after AudioFileStreamParseBytes returns when deferred.
    private func performErrorCleanup() {
        // Clean up resources (but don't change state again)
        timeoutSource?.cancel()
        timeoutSource = nil
        retrySource?.cancel()
        retrySource = nil
        
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
    
    private func checkTimeout() {
        // Ignore if paused or already rebuffering (reconnect in progress)
        // Requirements: 6.4
        if case .paused = state { return }
        if case .rebuffering = state { return }
        
        // HTTP stream already delivered all data — buffers are just draining naturally
        if httpStreamCompleted { return }
        
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
    
    private func handleConnectionReset() {
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
        
        // Schedule retry with exponential backoff on the stream queue
        isRetrying = true
        retrySource?.cancel()
        let source = DispatchSource.makeTimerSource(queue: streamQueue)
        source.schedule(deadline: .now() + delay)
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.retryConnection(fromProgress: currentProgress)
        }
        source.resume()
        retrySource = source
    }
    
    private func retryConnection(fromProgress progress: Double) {
        guard isRetrying else { return }
        
        print("Attempting to reconnect and resume from \(progress)s...")
        
        isRetrying = false
        retrySource?.cancel()
        retrySource = nil
        
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
            reconnectSource?.cancel()
            reconnectSource = nil
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
        
        // Schedule the reconnect after the backoff delay on the stream queue
        reconnectSource?.cancel()
        let source = DispatchSource.makeTimerSource(queue: streamQueue)
        source.schedule(deadline: .now() + delay)
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.reconnectSource = nil
            
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
        source.resume()
        reconnectSource = source
    }
    
    /// Updates `seekByteOffset` and `seekTime` based on current playback progress,
    /// so that `openReadStream()` will send the correct Range header.
    private func updateSeekPositionFromProgress() {
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
        
        // If the HTTP stream completed normally, buffers are draining because
        // the song is ending — not because of a network stall. Don't reconnect.
        guard !httpStreamCompleted else { return }
        
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
    
}

// MARK: - Queued Packet Data

struct QueuedPacketData {
    var description: AudioStreamPacketDescription
    var data: Data
}


// MARK: - HTTP Streaming

private extension AudioStreamer {
    
    /// Opens the HTTP data task using URLSession
    private func openReadStream() -> Bool {
        guard dataTask == nil else { return false }
        
        // New HTTP connection — stream hasn't completed yet
        httpStreamCompleted = false
        
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
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: streamOperationQueue)
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
        
        // Parse the audio data — guard the call with isParsing so that
        // failWithError (called synchronously from parser callbacks) defers
        // AudioQueue/AudioFileStream disposal until after parsing returns.
        let parseFlags: AudioFileStreamParseFlags = isDiscontinuous ? .discontinuity : []
        isParsing = true
        data.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            guard let afs = audioFileStream else { return }
            let status = AudioFileStreamParseBytes(
                afs,
                UInt32(data.count),
                baseAddress,
                parseFlags
            )
            if status != noErr {
                failWithError(.fileStreamParseFailed(status: status))
            }
        }
        isParsing = false
        
        // If failWithError was called during parsing, run the deferred cleanup now
        if deferredError != nil {
            deferredError = nil
            performErrorCleanup()
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard task === self.dataTask else { return }
        
        eventCount += 1
        
        if let error = error {
            // Cancelled tasks are expected during reconnect — not an error
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
            
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
            // Stream completed normally — server delivered all audio data.
            httpStreamCompleted = true
            
            timeoutSource?.cancel()
            timeoutSource = nil
            
            // Flush remaining data
            if bytesFilled > 0 {
                _ = enqueueBuffer()
            }

            // Keep the task alive through the final enqueue: enqueueBuffer()
            // requires stream != nil. Once that flush has finished, this task
            // no longer represents a live input, so a drained AudioQueue can
            // take its existing clean end-of-file path.
            self.dataTask = nil

            // The final AudioQueue callback may already have run before this
            // completion arrives. Re-check on the buffer queue so that order
            // still reaches the same clean terminal path.
            bufferQueue.async { [weak self] in
                guard let self = self else { return }
                _ = self.stopQueueIfDrainedAfterInputCompletion()
            }
            
            // If we're still waiting for data, we can transition immediately.
            // If playing/rebuffering, the AudioQueue will drain remaining buffers
            // and handleBufferComplete will detect buffersUsed == 0 to finish.
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
