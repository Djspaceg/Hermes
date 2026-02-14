# Requirements Document

## Introduction

This document specifies the requirements for overhauling the audio streaming resilience system in the Hermes macOS Pandora client. The current implementation suffers from disabled stall detection, narrow error classification (only POSIX error 54), destructive failure handling that tears down the AudioQueue, flat retry delays, and thread-unsafe buffer accounting. The overhaul aims to make streaming recover gracefully from network interruptions by reconnecting the HTTP stream in-place (preserving the AudioQueue and its buffered audio), detecting stalls proactively, classifying a broad range of network errors as retriable, and ensuring thread-safe buffer state management.

## Glossary

- **AudioStreamer**: The core streaming class that implements the CFReadStream → AudioFileStream → AudioQueue pipeline for audio playback
- **Playlist**: The queue manager that wraps AudioStreamer, handles song advancement, and performs higher-level retry logic
- **AudioQueue**: CoreAudio's AudioQueueRef-based playback system that manages audio buffers and output
- **CFReadStream**: CoreFoundation's HTTP read stream used for downloading audio data from Pandora servers
- **AudioFileStream**: CoreAudio's parser that extracts audio packets from raw HTTP data
- **Buffer_Accounting**: The set of variables (`buffersUsed`, `bufferInUse`, `fillBufferIndex`) that track which AudioQueue buffers are in use
- **Stall_Detection**: The mechanism that monitors buffer fill levels during playback to detect when the network stream has stopped delivering data while buffers are draining
- **In_Place_Reconnect**: The process of closing and reopening the CFReadStream without destroying the AudioQueue, so buffered audio continues playing during reconnection
- **Rebuffering_State**: A new AudioStreamerState indicating the streamer is reconnecting the HTTP stream while the AudioQueue continues playing from existing buffers
- **Backoff_Strategy**: An exponential backoff algorithm with random jitter used to space out retry attempts after network failures
- **Error_Classifier**: A component that categorizes network errors into retriable (transient) and non-retriable (permanent) categories
- **Hysteresis**: A two-threshold approach (high mark and low mark) for stall detection that prevents false triggers during initial buffering

## Requirements

### Requirement 1: In-Place Stream Reconnection

**User Story:** As a listener, I want audio playback to continue from existing buffers while the app reconnects the HTTP stream, so that brief network interruptions do not cause audible gaps or silence.

#### Acceptance Criteria

1. WHEN the AudioStreamer detects a retriable network error, THE AudioStreamer SHALL close the CFReadStream and reopen a new CFReadStream with an HTTP Range header calculated from the current byte offset, without destroying the AudioQueue or its allocated buffers
2. WHILE an In_Place_Reconnect is in progress, THE AudioQueue SHALL continue playing audio from previously enqueued buffers
3. WHEN the new CFReadStream delivers data after an In_Place_Reconnect, THE AudioStreamer SHALL mark the AudioFileStream parse as discontinuous and resume enqueuing buffers into the existing AudioQueue
4. IF an In_Place_Reconnect fails after exhausting the Backoff_Strategy retries, THEN THE AudioStreamer SHALL transition to the done state with an error reason

### Requirement 2: Rebuffering State

**User Story:** As a listener, I want to see a "Rebuffering..." indicator when the app is reconnecting, so that I understand why playback may momentarily pause instead of experiencing unexplained silence.

#### Acceptance Criteria

1. THE AudioStreamerState enum SHALL include a `rebuffering` case
2. WHEN the AudioStreamer initiates an In_Place_Reconnect, THE AudioStreamer SHALL transition to the rebuffering state
3. WHEN the AudioStreamer successfully receives audio data after reconnecting, THE AudioStreamer SHALL transition from the rebuffering state back to the playing state
4. WHILE in the rebuffering state, THE AudioStreamer SHALL continue to allow the AudioQueue to play from existing buffers

### Requirement 3: Proactive Stall Detection

**User Story:** As a listener, I want the app to detect when audio buffers are draining due to a stalled network stream and proactively reconnect, so that playback does not silently stop.

#### Acceptance Criteria

1. WHEN the AudioQueue completes a buffer during playback, THE Stall_Detection SHALL evaluate the current buffer fill ratio
2. THE Stall_Detection SHALL use Hysteresis with a high mark of 75% and a low mark of 25% to determine when buffers are draining
3. WHEN the buffer fill ratio drops below the low mark after previously reaching the high mark, and no queued packets are pending, THE Stall_Detection SHALL trigger an In_Place_Reconnect
4. WHILE an In_Place_Reconnect or retry is already in progress, THE Stall_Detection SHALL not trigger additional reconnect attempts

### Requirement 4: Network Error Classification

**User Story:** As a listener, I want the app to recognize a broad range of transient network errors and retry automatically, so that only truly permanent failures stop playback.

#### Acceptance Criteria

1. THE Error_Classifier SHALL categorize the following errors as retriable: POSIX connection reset (error 54), POSIX connection refused (error 61), POSIX host unreachable (error 65), POSIX network down (error 50), DNS lookup failures, TLS/SSL handshake failures, HTTP 5xx server errors, and CFNetwork timeout errors
2. THE Error_Classifier SHALL categorize the following errors as non-retriable: HTTP 4xx client errors (except 408 Request Timeout and 429 Too Many Requests), AudioQueue creation failures, AudioFileStream parse failures, and audio data format errors
3. WHEN a retriable error occurs, THE AudioStreamer SHALL attempt an In_Place_Reconnect using the Backoff_Strategy
4. WHEN a non-retriable error occurs, THE AudioStreamer SHALL transition to the done state with an error reason without retrying

### Requirement 5: Exponential Backoff with Jitter

**User Story:** As a listener, I want retry attempts to be spaced out with increasing delays and randomness, so that the app does not overwhelm a recovering server or waste resources on rapid retries.

#### Acceptance Criteria

1. THE Backoff_Strategy SHALL compute delay as: `min(baseDelay * 2^attempt, maxDelay) + random jitter in [0, jitterRange)`
2. THE AudioStreamer Backoff_Strategy SHALL use a base delay of 0.5 seconds, a maximum delay of 16 seconds, and a jitter range of 0.5 seconds
3. THE Playlist Backoff_Strategy SHALL use a base delay of 1.0 second, a maximum delay of 30 seconds, and a jitter range of 1.0 second
4. WHEN a reconnect succeeds, THE Backoff_Strategy SHALL reset the attempt counter to zero
5. THE AudioStreamer SHALL allow a maximum of 5 In_Place_Reconnect attempts before escalating to the Playlist level
6. THE Playlist SHALL allow a maximum of 4 retry attempts (creating a fresh AudioStreamer) before posting an ASStreamError notification

### Requirement 6: Smart Timeout Logic

**User Story:** As a listener, I want the timeout mechanism to consider buffer health rather than just byte arrival, so that a trickle of data does not prevent the app from detecting a functionally stalled connection.

#### Acceptance Criteria

1. WHEN the timeout timer fires, THE AudioStreamer SHALL evaluate both the event count and the buffer fill ratio
2. IF data has arrived but the buffer fill ratio has decreased by more than 20 percentage points since the last timeout check, THEN THE AudioStreamer SHALL treat the connection as stalled and trigger an In_Place_Reconnect
3. IF no data has arrived within the timeout interval, THE AudioStreamer SHALL trigger an In_Place_Reconnect instead of immediately failing with a terminal error
4. WHILE in the paused state, THE AudioStreamer SHALL not evaluate timeout conditions

### Requirement 7: Thread-Safe Buffer Accounting

**User Story:** As a developer, I want buffer state mutations to be thread-safe, so that concurrent access from the AudioQueue callback thread and the main thread does not cause arithmetic overflow crashes or data corruption.

#### Acceptance Criteria

1. THE AudioStreamer SHALL perform all mutations to Buffer_Accounting variables (`buffersUsed`, `bufferInUse`, `fillBufferIndex`, `bytesFilled`, `packetsFilled`) within a dedicated serial DispatchQueue
2. WHEN the AudioQueue output callback fires on its internal thread, THE AudioStreamer SHALL dispatch buffer release operations to the serial buffer queue
3. WHEN enqueuing a buffer from the main thread, THE AudioStreamer SHALL dispatch buffer allocation tracking to the serial buffer queue
4. THE `buffersUsed` counter SHALL use checked arithmetic or be replaced with a mechanism that cannot underflow below zero

### Requirement 8: Playlist-Level Retry Improvements

**User Story:** As a listener, I want the Playlist to use smarter retry logic with backoff when creating fresh streams, so that recovery from prolonged outages is more reliable.

#### Acceptance Criteria

1. WHEN the AudioStreamer escalates a failure to the Playlist, THE Playlist SHALL create a new AudioStreamer and attempt to resume from the last known playback position
2. THE Playlist SHALL use the Playlist Backoff_Strategy (exponential backoff with jitter) between retry attempts
3. WHEN a Playlist retry succeeds, THE Playlist SHALL reset the retry counter to zero
4. WHEN the Playlist exhausts all retry attempts, THE Playlist SHALL post an ASStreamError notification and clear the retry state
