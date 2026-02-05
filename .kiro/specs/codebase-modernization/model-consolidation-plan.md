# Model Consolidation Plan

## Overview

This document outlines the strategy for consolidating duplicate model types in the Hermes codebase. The current architecture has two Swift model representations for each domain entity:

- **Song** + **SongModel** → Consolidate to single **Song** with `@Observable`
- **Station** + **StationModel** → Consolidate to single **Station** with `@Observable`

The wrapper pattern (`SongModel`, `StationModel`) was originally needed for Objective-C bridging. Since the codebase is now 100% Swift, this pattern is no longer necessary and creates maintenance overhead.

---

## Part 1: Song and SongModel Audit

### Song.swift Properties

**Location**: `Sources/Swift/Models/Song.swift`

| Property | Type | Description |
|----------|------|-------------|
| `artist` | `String` | Artist name |
| `title` | `String` | Song title |
| `album` | `String` | Album name |
| `art` | `String?` | Artwork URL string |
| `stationId` | `String?` | Associated station ID |
| `nrating` | `NSNumber?` | Rating value (0=none, 1=liked, -1=disliked) |
| `albumUrl` | `String?` | Pandora album page URL |
| `artistUrl` | `String?` | Pandora artist page URL |
| `titleUrl` | `String?` | Pandora song page URL |
| `token` | `String?` | Unique song identifier |
| `highUrl` | `String?` | High quality audio URL |
| `medUrl` | `String?` | Medium quality audio URL |
| `lowUrl` | `String?` | Low quality audio URL |
| `trackGain` | `String?` | Audio normalization value |
| `allowFeedback` | `Bool` | Whether rating is allowed |
| `playDate` | `Date?` | When song was played |

**Computed Properties**:

- `id: String` - Returns token or UUID
- `playDateString: String?` - Formatted play date

**Unique Functionality in Song.swift**:

1. `@objc(Song)` and `@objcMembers` annotations (legacy, can be removed)
2. `NSSecureCoding` conformance for history persistence
3. `toDictionary()` method for serialization
4. `station()` method to get associated Station
5. `objectSpecifier` for AppleScript support
6. Custom `isEqual(_:)` and `hash` implementations

### SongModel.swift Properties

**Location**: `Sources/Swift/Models/SongModel.swift`

| Property | Type | Description |
|----------|------|-------------|
| `song` | `Song` | Wrapped Song instance |
| `rating` | `Int` (Published) | Current rating value |

**Computed Properties** (delegating to `song`):

- `id: String`
- `title: String`
- `artist: String`
- `album: String`
- `artworkURL: URL?` - Converts `art` string to URL
- `titleUrl: String?`
- `artistUrl: String?`
- `albumUrl: String?`
- `trackGain: String?`
- `allowFeedback: Bool`

**Unique Functionality in SongModel.swift**:

1. `ObservableObject` conformance with `@Published rating`
2. Notification observer for `.pandoraDidRateSong` to update rating
3. `Hashable` conformance based on object identity
4. `mock()` static method for previews/testing

### Files Referencing SongModel

| File | Usage |
|------|-------|
| `Sources/Swift/ViewModels/PlayerViewModel.swift` | `@Published var currentSong: SongModel?` |
| `Sources/Swift/ViewModels/HistoryViewModel.swift` | `@Published var historyItems: [SongModel]`, `selectedItem: SongModel?` |
| `Sources/Swift/ViewModels/PreviewMocks.swift` | `PreviewHistoryViewModel` uses `[SongModel]` |
| `Sources/Swift/Views/PlayerView.swift` | `PlayerViewModelProtocol.currentSong: SongModel?`, `AlbumArtView`, `SongInfoView` |
| `Sources/Swift/Views/HistoryListView.swift` | `@Binding var selectedItem: SongModel?`, `HistoryRow` |
| `Sources/Swift/Views/AlbumArtPreviewView.swift` | `let song: SongModel?` |
| `Sources/Swift/Views/MenuBarView.swift` | `nowPlayingSection(song: SongModel)` |
| `HermesTests/Tests/HistoryViewModelTests.swift` | Test helper creates `SongModel` |

### Song/SongModel Consolidation Approach

**Recommendation**: Migrate to unified `Song` class with `@Observable` macro.

**Rationale**:

1. `Song.swift` has more complete functionality (NSCoding, AppleScript, serialization)
2. `SongModel` is purely a wrapper adding `ObservableObject` behavior
3. `@Observable` macro provides automatic change tracking without `@Published`
4. Rating notification observer can be moved to `Song` directly

**Migration Steps**:

1. Add `import Observation` and `@Observable` macro to `Song`
2. Convert `nrating: NSNumber?` to `rating: Int` with proper getter/setter
3. Add rating notification observer directly to `Song`
4. Add `artworkURL: URL?` computed property
5. Remove `@objc` annotations (no longer needed)
6. Keep `NSSecureCoding` for history persistence
7. Update all views/view models to use `Song` directly
8. Delete `SongModel.swift`

---

## Part 2: Station and StationModel Audit

### Station.swift Properties

**Location**: `Sources/Swift/Models/Station.swift`

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Station name |
| `token` | `String` | Station token for API calls |
| `stationId` | `String` | Station ID |
| `created` | `UInt64` | Creation timestamp (ms since epoch) |
| `shared` | `Bool` | Whether station is shared |
| `allowRename` | `Bool` | Whether renaming is allowed |
| `allowAddMusic` | `Bool` | Whether adding music is allowed |
| `isQuickMix` | `Bool` | Whether this is QuickMix/Shuffle |
| `artUrl` | `String?` | Station artwork URL |
| `genres` | `[String]?` | Station genres |
| `playingSong` | `Song?` (private set) | Currently playing song |

**Private Properties**:

- `songs: [Song]` - Queue of songs to play
- `radio: PandoraProtocol?` - Pandora client reference
- `fragmentObserver: NSObjectProtocol?` - Notification observer

**Unique Functionality in Station.swift**:

1. Extends `Playlist` for audio playback integration
2. `@objc(SwiftStation)` and `@objcMembers` annotations
3. `NSSecureCoding` conformance
4. Static registry (`stationRegistry`) for lookup by token
5. Song queue management (`addSong`, `clearSongList`)
6. Audio URL selection based on quality preference
7. Notification handlers for playback events
8. `setRadio(_:)` for Pandora client integration

### StationModel.swift Properties

**Location**: `Sources/Swift/Models/StationModel.swift`

| Property | Type | Description |
|----------|------|-------------|
| `station` | `Station` | Wrapped Station instance |
| `name` | `String` (Published) | Station name |
| `isPlaying` | `Bool` (Published) | Playback state |
| `artworkURL` | `URL?` (Published) | Artwork URL |

**Computed Properties** (delegating to `station`):

- `id: String` - Returns `stationId`
- `token: String`
- `stationId: String`
- `created: Date` - Converts timestamp to Date
- `shared: Bool`
- `allowRename: Bool`
- `allowAddMusic: Bool`
- `isQuickMix: Bool`
- `playingSong: Song?`
- `genres: [String]`

**Unique Functionality in StationModel.swift**:

1. `ObservableObject` conformance with `@Published` properties
2. Notification observer for `.pandoraDidLoadStationInfo` to update artwork
3. `Hashable` conformance based on `stationId`
4. `mock()` static method for previews/testing

### Files Referencing StationModel

| File | Usage |
|------|-------|
| `Sources/Swift/ViewModels/StationsViewModel.swift` | `@Published var stations: [StationModel]` |
| `Sources/Swift/Views/StationsListView.swift` | Uses `StationModel` for list items |
| `Sources/Swift/Views/SidebarView.swift` | Uses `StationModel` for station selection |
| `Sources/Swift/Services/StationArtworkLoader.swift` | Posts notification for `StationModel` updates |
| `HermesTests/Tests/StationsViewModelTests.swift` | Creates `StationModel` instances |
| `HermesTests/Tests/StationBridgingTests.swift` | Property tests for Station-StationModel bridging |

### Station/StationModel Consolidation Approach

**Recommendation**: Migrate to unified `Station` class with `@Observable` macro.

**Rationale**:

1. `Station.swift` has extensive functionality (Playlist integration, song queue, playback)
2. `StationModel` is purely a wrapper adding `ObservableObject` behavior
3. `@Observable` macro provides automatic change tracking
4. Artwork notification observer can be moved to `Station` directly

**Migration Steps**:

1. Add `import Observation` and `@Observable` macro to `Station`
2. Add `artworkURL: URL?` computed property (from `artUrl`)
3. Add `createdDate: Date` computed property
4. Add artwork notification observer directly to `Station`
5. Remove `@objc` annotations (no longer needed)
6. Keep `NSSecureCoding` for persistence
7. Keep `Playlist` inheritance for playback functionality
8. Update all views/view models to use `Station` directly
9. Delete `StationModel.swift`

---

## Part 3: Consolidated Migration Plan

### Phase 1: Prepare Song for @Observable (Task 6.1)

```swift
// Before
@objc(Song)
@objcMembers
final class Song: NSObject, Identifiable { ... }

// After
import Observation

@Observable
final class Song: NSObject, Identifiable, NSSecureCoding {
    // Properties become automatically observable
    var artist: String
    var title: String
    var album: String
    var rating: Int = 0  // Replace nrating: NSNumber?
    // ... rest of properties
    
    // Add computed property
    var artworkURL: URL? {
        guard let art = art else { return nil }
        return URL(string: art)
    }
    
    // Move rating observer from SongModel
    private func setupRatingObserver() {
        NotificationCenter.default.addObserver(
            forName: .pandoraDidRateSong,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Update rating when notification received
        }
    }
}
```

### Phase 2: Migrate Views from SongModel to Song (Task 6.2)

**PlayerView.swift changes**:

```swift
// Before
var currentSong: SongModel? { get }

// After  
var currentSong: Song? { get }
```

**HistoryListView.swift changes**:

```swift
// Before
@Binding var selectedItem: SongModel?

// After
@Binding var selectedItem: Song?
```

### Phase 3: Migrate View Models from SongModel to Song (Task 6.3)

**PlayerViewModel.swift changes**:

```swift
// Before
@Published var currentSong: SongModel?
currentSong = SongModel(song: song)

// After
var currentSong: Song?  // @Observable handles change tracking
currentSong = song
```

**HistoryViewModel.swift changes**:

```swift
// Before
@Published var historyItems: [SongModel] = []
historyItems = songs.map { SongModel(song: $0) }

// After
var historyItems: [Song] = []
historyItems = songs
```

### Phase 4: Delete SongModel.swift (Task 6.4)

1. Verify no remaining references with: `grep -r "SongModel" Sources/`
2. Delete `Sources/Swift/Models/SongModel.swift`
3. Remove from Xcode project
4. Run tests to verify functionality

### Phase 5: Prepare Station for @Observable (Task 7.1)

```swift
// Before
@objc(SwiftStation)
@objcMembers
final class Station: Playlist, NSSecureCoding { ... }

// After
import Observation

@Observable
final class Station: Playlist, NSSecureCoding {
    // Properties become automatically observable
    var name: String = ""
    var artworkURL: URL?  // Add computed or stored property
    // ... rest of properties
    
    // Add computed property for Date
    var createdDate: Date {
        Date(timeIntervalSince1970: TimeInterval(created) / 1000.0)
    }
    
    // Move artwork observer from StationModel
    private func setupArtworkObserver() {
        NotificationCenter.default.addObserver(
            forName: .pandoraDidLoadStationInfo,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Update artworkURL when notification received
        }
    }
}
```

### Phase 6: Migrate Views from StationModel to Station (Task 7.2)

**StationsListView.swift changes**:

```swift
// Before
ForEach(viewModel.stations) { station: StationModel in

// After
ForEach(viewModel.stations) { station: Station in
```

### Phase 7: Migrate View Models from StationModel to Station (Task 7.3)

**StationsViewModel.swift changes**:

```swift
// Before
@Published var stations: [StationModel] = []
stations = rawStations.map { StationModel(station: $0) }

// After
var stations: [Station] = []  // @Observable handles change tracking
stations = rawStations
```

### Phase 8: Delete StationModel.swift (Task 7.4)

1. Verify no remaining references with: `grep -r "StationModel" Sources/`
2. Delete `Sources/Swift/Models/StationModel.swift`
3. Remove from Xcode project
4. Run tests to verify functionality

---

## Testing Strategy

### Unit Tests to Update

1. **HistoryViewModelTests.swift** - Update `createMockSong()` to return `Song` directly
2. **StationsViewModelTests.swift** - Update to use `Station` directly
3. **StationBridgingTests.swift** - Remove or repurpose (bridging no longer needed)

### Property Tests to Verify

1. **Model State Consistency** (Property 1) - Verify `@Observable` provides consistent state
2. **Song equality** - Verify `Song` equality based on token
3. **Station equality** - Verify `Station` equality based on stationId

### Manual Testing Checklist

- [ ] Song rating updates reflect in PlayerView
- [ ] Song rating updates reflect in HistoryListView
- [ ] Station artwork loads and displays correctly
- [ ] Station selection works in sidebar
- [ ] History persistence works (NSCoding)
- [ ] AppleScript support works (Song.objectSpecifier)

---

## Risk Assessment

### Low Risk

- Adding `@Observable` macro to existing classes
- Adding computed properties (`artworkURL`, `createdDate`)
- Moving notification observers

### Medium Risk

- Removing `@objc` annotations - verify no remaining Objective-C dependencies
- Changing `nrating: NSNumber?` to `rating: Int` - verify NSCoding compatibility

### Mitigation

- Run full test suite after each step
- Test history persistence with existing saved data
- Verify AppleScript functionality if used

---

## Success Criteria

1. ✅ Single `Song` class with `@Observable` macro
2. ✅ Single `Station` class with `@Observable` macro
3. ✅ No `SongModel.swift` or `StationModel.swift` files
4. ✅ All views use unified models directly
5. ✅ All tests pass
6. ✅ History persistence works
7. ✅ Rating updates propagate correctly
8. ✅ Station artwork loads correctly

---

## Timeline

| Task | Estimated Time |
|------|----------------|
| 6.1 Add @Observable to Song | 2 hours |
| 6.2 Migrate views from SongModel | 1 hour |
| 6.3 Migrate view models from SongModel | 1 hour |
| 6.4 Delete SongModel.swift | 30 minutes |
| 7.1 Add @Observable to Station | 2 hours |
| 7.2 Migrate views from StationModel | 1 hour |
| 7.3 Migrate view models from StationModel | 1 hour |
| 7.4 Delete StationModel.swift | 30 minutes |
| **Total** | **~9 hours** |
