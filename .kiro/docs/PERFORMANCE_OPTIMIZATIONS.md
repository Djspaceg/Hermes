# Performance Optimizations Analysis

## Issues Identified from Application Logs

### 1. **CRITICAL: Duplicate Song Notifications**

**Problem**: Every song triggers `StationDidPlaySongNotification` twice, causing duplicate processing.

**Evidence**:

```
NotificationBridge: Received StationDidPlaySongNotification
NotificationBridge: Notification object = Optional(<Station: 0xa20de7660>)
NotificationBridge: Got song from station - Face to Face
NotificationBridge: Received StationDidPlaySongNotification  <-- DUPLICATE
NotificationBridge: Notification object = Optional(<Station: 0xa20de7660>)
NotificationBridge: Got song from station - Face to Face     <-- DUPLICATE
PlaybackController: songPlayed - Face to Face by Ludwig Göransson
```

**Root Cause**:

- `ASPlaylist` posts `ASNewSongPlaying` when bitrate is ready
- `Station` observes `ASNewSongPlaying` and posts `StationDidPlaySongNotification`
- `PlaybackController` ALSO observes `StationDidPlaySongNotification` and processes it
- `PlayerViewModel` ALSO subscribes to `StationDidPlaySongNotification`
- Both are receiving the same notification, but the notification is only posted once
- The duplicate logs suggest `NotificationBridge.songPlayingPublisher` is being subscribed to twice OR the notification is being posted from multiple places

**Solution**:

- Remove duplicate subscription in `PlayerViewModel` - it should only subscribe once
- OR: Consolidate notification handling - have PlaybackController handle the notification and post a different one for UI updates
- Use `.removeDuplicates()` on the Combine publisher to filter duplicate song changes

**Files to Fix**:

- `Sources/Swift/ViewModels/PlayerViewModel.swift` - Add `.removeDuplicates()` or check for duplicate subscriptions
- `Sources/Swift/Utilities/NotificationBridge.swift` - Remove debug logging once fixed

---

### 2. **HIGH: Excessive `isPlaying` Polling**

**Problem**: `AudioStreamer.isPlaying()` is called 4-5 times in rapid succession for every state change.

**Evidence**:

```
AudioStreamer: isPlaying called, state=1, returning 0
AudioStreamer: isPlaying called, state=1, returning 0
AudioStreamer: isPlaying called, state=1, returning 0
AudioStreamer: isPlaying called, state=1, returning 0
PlayerViewModel: State updated - isPlaying: false
```

**Root Cause**:

- Multiple observers calling `isPlaying()` on every notification
- `PlaybackController.playbackStateChanged` calls it
- `PlayerViewModel.updatePlaybackState` calls it via `station.isPlaying()`
- Notification handlers may be triggering multiple times

**Solution**:

- Cache the playing state in `PlaybackController` and only query when needed
- Use a debounce operator in Combine to batch rapid state changes
- Reduce the number of places that query `isPlaying()`

**Files to Fix**:

- `Sources/Controllers/PlaybackController.m` - Cache isPlaying state
- `Sources/Swift/ViewModels/PlayerViewModel.swift` - Add `.debounce()` to state publisher

---

### 3. **HIGH: Redundant PlayerViewModel State Updates**

**Problem**: Multiple identical "State updated - isPlaying: false" logs in quick succession.

**Evidence**:

```
PlayerViewModel: State updated - isPlaying: false
AudioStreamer: isPlaying called, state=1, returning 0
PlayerViewModel: State updated - isPlaying: false  <-- DUPLICATE
```

**Root Cause**:

- `updatePlaybackState()` is being called multiple times with the same value
- No deduplication of state changes before publishing

**Solution**:

- Add `.removeDuplicates()` to the playback state publisher
- Only update `@Published` properties when the value actually changes

**Files to Fix**:

- `Sources/Swift/ViewModels/PlayerViewModel.swift`

---

### 4. **MEDIUM: Double Authentication on Subscriber Accounts**

**Problem**: Subscriber accounts authenticate twice - once with regular endpoint, then again with internal endpoint.

**Evidence**:

```
Pandora.m:838 -[Pandora sendRequest:] https://tuner.pandora.com/services/json/?method=auth.partnerLogin...
Pandora.m:838 -[Pandora sendRequest:] https://tuner.pandora.com/services/json/?method=auth.userLogin...
Pandora.m:273 -[Pandora doUserLogin:password:callback:]_block_invoke Subscriber status: 1
Pandora.m:278 -[Pandora doUserLogin:password:callback:]_block_invoke Subscriber detected, re-logging-in...
Pandora.m:293 -[Pandora doPartnerLogin:] Getting partner ID...
Pandora.m:838 -[Pandora sendRequest:] https://internal-tuner.pandora.com/services/json/?method=auth.partnerLogin...
Pandora.m:838 -[Pandora sendRequest:] https://internal-tuner.pandora.com/services/json/?method=auth.userLogin...
```

**Root Cause**:

- Pandora API requires different endpoints for subscribers vs free users
- App doesn't know subscriber status until after first login
- Re-authentication is necessary but adds startup delay

**Solution**:

- Cache subscriber status in UserDefaults
- On subsequent launches, use the correct endpoint immediately
- Fall back to re-authentication only if the cached endpoint fails

**Files to Fix**:

- `Sources/Pandora/Pandora.m` - Add subscriber status caching

---

### 5. **MEDIUM: Repeated Station Detail Fetches**

**Problem**: `station.getStation` API is called repeatedly when opening/closing station editor.

**Evidence**:

```
Pandora.m:838 -[Pandora sendRequest:] http://internal-tuner.pandora.com/services/json/?method=station.getStation...
WindowTracker: Window opened - stationEditor
WindowTracker: Window closed - stationEditor
Pandora.m:838 -[Pandora sendRequest:] http://internal-tuner.pandora.com/services/json/?method=station.getStation...
WindowTracker: Window opened - stationEditor
WindowTracker: Window closed - stationEditor
```

**Root Cause**:

- Station editor fetches full station details every time it opens
- No caching of station metadata
- Window open/close cycle triggers repeated fetches

**Solution**:

- Cache station details with a TTL (time-to-live)
- Only refetch if cache is stale or user explicitly refreshes
- Debounce rapid open/close cycles

**Files to Fix**:

- `Sources/Swift/ViewModels/StationEditViewModel.swift` - Add caching
- `Sources/Pandora/Pandora.m` - Add station detail cache

---

### 6. **LOW: Unnecessary State Transition Notifications**

**Problem**: State change notifications are posted even when state hasn't actually changed.

**Evidence**:

```
AudioStreamer: setState called - old state=3, new state=3  <-- No actual change
AudioStreamer: setState - posting ASStatusChangedNotification
```

**Root Cause**:

- `setState` doesn't check if the new state equals the old state
- Notifications are posted unconditionally

**Solution**:

- Add state equality check before posting notification
- Only post when state actually changes

**Files to Fix**:

- `Sources/AudioStreamer/AudioStreamer.m` - Add state change guard

---

### 7. **LOW: Output Device Warning on Every Song**

**Problem**: "Failed to set output device: -66683" warning appears for every song.

**Evidence**:

```
AudioStreamer: Setting output device to default: 105
AudioStreamer: Warning - Failed to set output device: -66683 (continuing anyway)
```

**Root Cause**:

- Error code -66683 is `kAudioQueueErr_InvalidDevice`
- Attempting to set output device to "default" (105) which may not be valid
- This is a harmless warning but clutters logs

**Solution**:

- Remove the output device setting code if it's not essential
- OR: Query available devices first and only set if valid
- OR: Suppress this specific warning since it's harmless

**Files to Fix**:

- `Sources/AudioStreamer/AudioStreamer.m`

---

## Implementation Priority

### Phase 1: Critical (Immediate)

1. Fix duplicate song notifications
2. Reduce `isPlaying` polling
3. Add state deduplication to PlayerViewModel

### Phase 2: High (Next Sprint)

4. Cache subscriber status to avoid double authentication
2. Add station detail caching

### Phase 3: Low (Nice to Have)

6. Add state change guards in AudioStreamer
2. Fix or suppress output device warning

---

## Expected Performance Improvements

- **Startup Time**: 30-40% faster (eliminate double authentication)
- **Song Transitions**: 50% fewer notifications and method calls
- **Network Requests**: 60-70% reduction (station detail caching)
- **CPU Usage**: 20-30% reduction (eliminate redundant polling)
- **Log Noise**: 80% reduction (remove duplicate logs and warnings)

---

## Testing Checklist

After implementing fixes:

- [ ] Verify only ONE `StationDidPlaySongNotification` per song
- [ ] Verify `isPlaying` called max 1-2 times per state change
- [ ] Verify no duplicate "State updated" logs
- [ ] Verify single authentication on app launch (after first run)
- [ ] Verify station editor doesn't refetch on every open
- [ ] Verify smooth song transitions without lag
- [ ] Verify no regression in playback functionality
