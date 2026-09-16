//
//  AudioStreamBuffer.swift
//  Hermes
//
//  AudioQueue buffer management extracted from AudioStreamer.
//

import AudioToolbox
import CoreAudio
import Foundation

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
    streamer.handleDefaultOutputDeviceChanged()
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

extension AudioStreamer {

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


    /// Called from the CoreAudio device-change C callback; dispatches to
    /// the stream queue so the AudioQueue property update stays off main.
    func handleDefaultOutputDeviceChanged() {
        streamQueue.async { [weak self] in
            self?.setDefaultOutputDevice()
        }
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

    private func determinePacketBufferSize() {
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


    private func allocateBuffers() {
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

    private func setMagicCookie() {
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
        // enqueueBuffer is called from the stream queue (via URLSession callbacks),
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
                self.streamQueue.async { [weak self] in
                    self?.enqueueCachedData()
                }
            }
        }
    }

    private func enqueueCachedData() {
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
