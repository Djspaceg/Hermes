//
//  AudioStreamDecoder.swift
//  Hermes
//
//  AudioFileStream decoding extracted from AudioStreamer.
//

import AudioToolbox
import Foundation

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

extension AudioStreamer {
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

    // MARK: - File Type Hints

    private static func hintForFileExtension(_ ext: String) -> AudioFileTypeID {
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

    private static func hintForMIMEType(_ mimeType: String) -> AudioFileTypeID {
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
