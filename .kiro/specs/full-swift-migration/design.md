# Design Document: Full Swift Migration

## Overview

This design outlines the architecture and implementation approach for migrating all remaining Objective-C code in Hermes to modern Swift. The migration achieves a 100% Swift codebase with zero Objective-C or C dependencies, using CryptoSwift for Blowfish encryption.

The migration follows a phased approach across 5 phases:

1. **Foundation**: Crypt migration to CryptoSwift, DI integration
2. **Audio Layer**: AudioStreamer and ASPlaylist migration
3. **API Layer**: Pandora and Station migration
4. **Controllers**: PlaybackController migration
5. **Cleanup**: FMEngine completion, bridging header removal

## Architecture

### Current State

```
Hermes Codebase
├── Swift (UI Layer + Utilities)
│   ├── SwiftUI Views
│   ├── View Models (AppState, LoginVM, PlayerVM, StationsVM, HistoryVM)
│   ├── Models (SongModel, StationModel, PandoraProtocol)
│   ├── Services (LastFMService, AppleScriptSupport, StationArtworkLoader)
│   └── Utilities (HTTPClient, ImageCache, KeychainManager, NetworkMonitor, etc.)
├── Objective-C (Business Logic)
│   ├── Pandora/ (Pandora.m, Station.m, Crypt.m, PandoraDevice.m)
│   ├── AudioStreamer/ (AudioStreamer.m, ASPlaylist.m)
│   └── Controllers/ (PlaybackController.m)
├── ImportedSources
│   ├── blowfish/ (blowfish.c, blowfish.h) - TO BE REMOVED
│   ├── FMEngine/ (FMEngine.m, NSString+FMEngine.m) - TO BE REMOVED
│   └── SPMediaKeyTap/ - ALREADY UNUSED
└── Bridge
    └── Hermes-Bridging-Header.h - TO BE REMOVED
```

### Target State

```
Hermes Codebase (100% Swift)
├── Swift
│   ├── Views/ (SwiftUI views)
│   ├── ViewModels/ (AppState, LoginVM, PlayerVM, StationsVM, HistoryVM)
│   ├── Models/ (Song, Station, SongModel, StationModel)
│   ├── Services/
│   │   ├── Pandora/ (PandoraClient, PandoraProtocol, PandoraCrypto)
│   │   ├── Audio/ (AudioStreamer, Playlist)
│   │   ├── LastFMService
│   │   └── AppleScriptSupport
│   └── Utilities/ (HTTPClient, ImageCache, KeychainManager, etc.)
└── Dependencies (SPM)
    ├── Sparkle (existing)
    └── CryptoSwift (new)
```

## Components and Interfaces

### Phase 1: Foundation

#### Component: PandoraCrypto

Replaces `Crypt.{h,m}` using CryptoSwift for Blowfish encryption.

```swift
import CryptoSwift

/// Pandora API encryption/decryption using Blowfish ECB mode
enum PandoraCrypto {
    
    /// Encrypt data for Pandora API requests
    /// - Parameters:
    ///   - data: The data to encrypt
    ///   - key: The encryption key from device configuration
    /// - Returns: Hex-encoded encrypted string
    static func encrypt(_ data: Data, key: String) throws -> String
    
    /// Decrypt data from Pandora API responses
    /// - Parameters:
    ///   - hexString: The hex-encoded encrypted string
    ///   - key: The decryption key from device configuration
    /// - Returns: Decrypted data
    static func decrypt(_ hexString: String, key: String) throws -> Data
}
```

**Implementation Notes:**

- Uses CryptoSwift's `Blowfish` with `.ecb` mode and `.zeroPadding`
- Hex encoding/decoding via CryptoSwift's built-in extensions
- Error handling via Swift `throws` instead of returning nil

#### Component: DI Integration Updates

Updates to view models to accept dependencies via initializers.

```swift
@MainActor
final class AppState: ObservableObject {
    // MARK: - Factory
    
    /// Factory for creating AppState instances
    /// Allows injection of mock dependencies for testing
    static func create(pandora: PandoraProtocol? = nil) -> AppState {
        AppState(pandora: pandora ?? PandoraClient())
    }
    
    /// Shared instance for production use
    static let shared = AppState.create()
    
    // MARK: - Initialization
    
    init(pandora: PandoraProtocol) {
        self.pandora = pandora
        // ... rest of initialization
    }
}
```

### Phase 2: Audio Layer

#### Component: AudioStreamer

Replaces `AudioStreamer.{h,m}` - a Swift wrapper around CoreAudio's AudioQueue APIs.

```swift
/// Audio streaming states
enum AudioStreamerState: Equatable {
    case initialized
    case waitingForData
    case waitingForQueueToStart
    case playing
    case paused
    case done(reason: DoneReason)
    case stopped
    
    enum DoneReason {
        case stopped
        case error(AudioStreamerError)
        case endOfFile
    }
}

/// Audio streaming errors
enum AudioStreamerError: Error, LocalizedError {
    case networkConnectionFailed(Error?)
    case fileStreamOpenFailed(OSStatus)
    case fileStreamParseFailed(OSStatus)
    case audioQueueCreationFailed(OSStatus)
    case audioQueueStartFailed(OSStatus)
    case audioQueueBufferAllocationFailed(OSStatus)
    case audioDataNotFound
    case timeout
    // ... other error cases
    
    var errorDescription: String? { /* ... */ }
}

/// Protocol for audio streaming operations
protocol AudioStreaming: AnyObject {
    var state: AudioStreamerState { get }
    var url: URL { get }
    var httpHeaders: [String: String]? { get }
    
    func start() -> Bool
    func stop()
    func pause() -> Bool
    func play() -> Bool
    
    func setVolume(_ volume: Double) -> Bool
    func seekToTime(_ time: Double) -> Bool
    func progress() -> Double?
    func duration() -> Double?
    func calculatedBitRate() -> Double?
}

/// Audio streamer using CoreAudio's AudioQueue framework
final class AudioStreamer: AudioStreaming {
    
    // MARK: - Properties
    
    let url: URL
    private(set) var state: AudioStreamerState = .initialized
    private(set) var httpHeaders: [String: String]?
    
    // Configuration
    var bufferCount: UInt32 = 16
    var bufferSize: UInt32 = 2048
    var bufferInfinite: Bool = false
    var timeoutInterval: Int = 10
    var fileType: AudioFileTypeID?
    
    // Proxy configuration
    private var proxyType: ProxyType = .system
    private var proxyHost: String?
    private var proxyPort: Int?
    
    // MARK: - Initialization
    
    init(url: URL) {
        self.url = url
    }
    
    static func stream(with url: URL) -> AudioStreamer {
        AudioStreamer(url: url)
    }
    
    // MARK: - Proxy Configuration
    
    func setHTTPProxy(host: String, port: Int)
    func setSOCKSProxy(host: String, port: Int)
    
    // MARK: - Playback Control
    
    func start() -> Bool
    func stop()
    func pause() -> Bool
    func play() -> Bool
    
    // MARK: - Audio Properties
    
    func setVolume(_ volume: Double) -> Bool
    func seekToTime(_ time: Double) -> Bool
    func progress() -> Double?
    func duration() -> Double?
    func calculatedBitRate() -> Double?
}
```

**Implementation Notes:**

- Uses `CFReadStream` for HTTP streaming with proxy support
- Uses `AudioFileStream` for parsing audio data
- Uses `AudioQueue` for playback
- Thread safety via `DispatchQueue` or Swift actors for buffer management
- Posts `ASStatusChangedNotification` and `ASBitrateReadyNotification`

#### Component: Playlist

Replaces `ASPlaylist.{h,m}` - manages a queue of audio streams.

```swift
/// Playlist notifications
extension Notification.Name {
    static let playlistNewSongPlaying = Notification.Name("ASNewSongPlaying")
    static let playlistNoSongsLeft = Notification.Name("ASNoSongsLeft")
    static let playlistRunningOutOfSongs = Notification.Name("ASRunningOutOfSongs")
    static let playlistCreatedNewStream = Notification.Name("ASCreatedNewStream")
    static let playlistStreamError = Notification.Name("ASStreamError")
    static let playlistAttemptingNewSong = Notification.Name("ASAttemptingNewSong")
}

/// Protocol for playlist operations
protocol PlaylistProtocol: AnyObject {
    var playing: URL? { get }
    var volume: Double { get set }
    
    func play()
    func pause()
    func stop()
    func next()
    
    func isPaused() -> Bool
    func isPlaying() -> Bool
    func isIdle() -> Bool
    func isError() -> Bool
    
    func duration() -> Double?
    func progress() -> Double?
    
    func retry()
    func clearSongList()
    func addSong(_ url: URL, play: Bool)
}

/// Manages a queue of audio streams with automatic advancement
final class Playlist: PlaylistProtocol {
    
    // MARK: - Properties
    
    private(set) var playing: URL?
    var volume: Double = 1.0 {
        didSet { stream?.setVolume(volume) }
    }
    
    private var urls: [URL] = []
    private var stream: AudioStreamer?
    private var retrying = false
    private var nexting = false
    private var stopping = false
    
    // MARK: - Playback Control
    
    func play()
    func pause()
    func stop()
    func next()
    
    // MARK: - State Queries
    
    func isPaused() -> Bool
    func isPlaying() -> Bool
    func isIdle() -> Bool
    func isError() -> Bool
    
    // MARK: - Progress
    
    func duration() -> Double?
    func progress() -> Double?
    
    // MARK: - Queue Management
    
    func retry()
    func clearSongList()
    func addSong(_ url: URL, play: Bool)
}
```

### Phase 3: API Layer

#### Component: PandoraClient

Replaces `Pandora.{h,m}` - the Pandora API client with async/await.

```swift
/// Pandora API request
struct PandoraRequest {
    let method: String
    var authToken: String?
    var partnerId: String?
    var userId: String?
    var parameters: [String: Any]
    var useTLS: Bool = true
    var encrypted: Bool = true
    var callback: ((Result<[String: Any], PandoraError>) -> Void)?
}

/// Pandora API errors
enum PandoraError: Error, LocalizedError {
    case invalidSyncTime
    case invalidAuthToken
    case invalidPartnerLogin
    case invalidUsername
    case invalidPassword
    case noSeedsLeft
    case networkError(Error)
    case apiError(code: Int, message: String)
    
    static func from(code: Int) -> PandoraError? { /* ... */ }
    var errorDescription: String? { /* ... */ }
}

/// Pandora API client implementing PandoraProtocol
final class PandoraClient: PandoraProtocol {
    
    // MARK: - Properties
    
    private(set) var stations: [Station] = []
    var device: NSDictionary?
    var cachedSubscriberStatus: NSNumber?
    
    // Internal state
    private var partnerId: String?
    private var partnerAuthToken: String?
    private var userAuthToken: String?
    private var userId: String?
    private var syncTime: UInt64 = 0
    private var startTime: UInt64 = 0
    private var syncOffset: Int64 = 0
    
    private let httpClient: HTTPClient
    
    // MARK: - Initialization
    
    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }
    
    // MARK: - Authentication
    
    func authenticate(_ user: String, password: String, request: PandoraRequest?) -> Bool
    func isAuthenticated() -> Bool
    func logout()
    func logoutNoNotify()
    
    // MARK: - Station Management
    
    func fetchStations() -> Bool
    func createStation(_ musicId: String) -> Bool
    func removeStation(_ stationToken: String) -> Bool
    func renameStation(_ stationToken: String, to name: String) -> Bool
    func fetchStationInfo(_ station: Station) -> Bool
    func fetchGenreStations() -> Bool
    func sortStations(_ sort: Int)
    
    // MARK: - Playback
    
    func fetchPlaylistForStation(_ station: Station) -> Bool
    
    // MARK: - Song Operations
    
    func rateSong(_ song: Song, as liked: Bool) -> Bool
    func tiredOfSong(_ song: Song) -> Bool
    func deleteRating(_ song: Song) -> Bool
    
    // MARK: - Search
    
    func search(_ search: String) -> Bool
    
    // MARK: - Seed Management
    
    func addSeed(_ token: String, toStation station: Station) -> Bool
    func removeSeed(_ seedId: String) -> Bool
    func deleteFeedback(_ feedbackId: String) -> Bool
    
    // MARK: - Internal
    
    private func sendRequest(_ request: PandoraRequest) async throws -> [String: Any]
    private func encryptData(_ data: Data) -> Data
    private func decryptString(_ string: String) -> Data
}
```

#### Component: Station

Replaces `Station.{h,m}` - station model with playlist integration.

```swift
/// Station model with playlist management
final class Station: Playlist, Codable {
    
    // MARK: - Properties
    
    var name: String
    var token: String
    var stationId: String
    var created: UInt64
    var isShared: Bool
    var allowRename: Bool
    var allowAddMusic: Bool
    var isQuickMix: Bool
    var artUrl: String?
    var genres: [String]
    
    private(set) var playingSong: Song?
    private var songs: [Song] = []
    private weak var radio: PandoraProtocol?
    
    // MARK: - Initialization
    
    init(name: String, token: String, stationId: String) {
        self.name = name
        self.token = token
        self.stationId = stationId
        // ... defaults
        super.init()
    }
    
    // MARK: - Radio Integration
    
    func setRadio(_ radio: PandoraProtocol)
    func streamNetworkError() -> String?
    func applyTrackGain(_ gainString: String)
    
    // MARK: - Static Registry
    
    private static var stationRegistry: [String: Station] = [:]
    
    static func station(forToken token: String) -> Station?
    static func addStation(_ station: Station)
    static func removeStation(_ station: Station)
}
```

#### Component: Song

The existing `Song.swift` model - may need minor updates for full Swift integration.

```swift
/// Song model (already exists, may need updates)
@objc class Song: NSObject {
    @objc var title: String
    @objc var artist: String
    @objc var album: String
    @objc var artUrl: String?
    @objc var audioUrl: String?
    @objc var stationId: String?
    @objc var trackToken: String?
    @objc var feedbackId: String?
    @objc var nrating: NSNumber? // -1 = disliked, 0 = none, 1 = liked
    // ... other properties
}
```

### Phase 4: Controllers

#### Component: PlaybackController

Replaces `PlaybackController.{h,m}` - playback coordination with media keys.

```swift
/// Playback state change notifications
extension Notification.Name {
    static let playbackStateDidChange = Notification.Name("PlaybackStateDidChangeNotification")
    static let playbackSongDidChange = Notification.Name("PlaybackSongDidChangeNotification")
    static let playbackProgressDidChange = Notification.Name("PlaybackProgressDidChangeNotification")
    static let playbackArtDidLoad = Notification.Name("PlaybackArtDidLoadNotification")
}

/// Playback controller managing audio playback and media integration
@MainActor
final class PlaybackController: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = PlaybackController()
    
    // MARK: - Published Properties
    
    @Published private(set) var playing: Station?
    @Published private(set) var currentSong: Song?
    @Published private(set) var artImage: NSImage?
    @Published private(set) var currentProgress: Double = 0
    @Published private(set) var currentDuration: Double = 0
    @Published var volume: Int = 100
    
    // MARK: - Properties
    
    var pausedByScreensaver: Bool = false
    var pausedByScreenLock: Bool = false
    
    private let remoteCommandCenter = MPRemoteCommandCenter.shared()
    private var progressTimer: Timer?
    
    // MARK: - Class Methods
    
    static var playOnStart: Bool {
        get { UserDefaults.standard.bool(forKey: "playOnStart") }
        set { UserDefaults.standard.set(newValue, forKey: "playOnStart") }
    }
    
    // MARK: - Lifecycle
    
    func setup()
    func prepareFirst()
    func setupMediaKeys()
    
    // MARK: - Station Management
    
    func playStation(_ station: Station?)
    func reset()
    func saveState() -> Bool
    
    // MARK: - Playback Controls
    
    func play() -> Bool
    func pause() -> Bool
    func stop()
    func playpause()
    func next()
    
    // MARK: - Song Rating
    
    func rate(_ song: Song, as liked: Bool)
    func likeCurrent()
    func dislikeCurrent()
    func tiredOfCurrent()
    
    // MARK: - Volume Control
    
    func increaseVolume()
    func decreaseVolume()
    
    // MARK: - Private Methods
    
    private func setupRemoteCommands()
    private func updateNowPlayingInfo()
    private func loadArtwork(for song: Song)
}
```

### Phase 5: Cleanup

#### Component: LastFMService Updates

Complete the FMEngine migration by removing dependencies on Objective-C.

```swift
/// Updated LastFMService - remove NSObject dependencies
@MainActor
final class LastFMService: ObservableObject {
    // Update to use Swift Song type directly instead of NSObject
    func scrobble(_ song: Song, state: ScrobbleState) async
    func setPreference(_ song: Song, loved: Bool) async
}
```

#### Component: String+MD5 (Replace CommonCrypto)

Replace CommonCrypto MD5 with CryptoSwift.

```swift
import CryptoSwift

extension String {
    func md5sum() -> String {
        self.md5() // CryptoSwift provides this
    }
}
```

## Data Models

### PandoraDevice Configuration

```swift
/// Device configuration for Pandora API
enum PandoraDevice {
    static let usernameKey = "username"
    static let passwordKey = "password"
    static let deviceIDKey = "deviceId"
    static let encryptKey = "encryptKey"
    static let decryptKey = "decryptKey"
    static let apiHostKey = "apiHost"
    
    static var iPhone: [String: String] {
        [
            usernameKey: "...",
            passwordKey: "...",
            deviceIDKey: "...",
            encryptKey: "...",
            decryptKey: "...",
            apiHostKey: "tuner.pandora.com"
        ]
    }
    
    static var android: [String: String] { /* ... */ }
    static var desktop: [String: String] { /* ... */ }
}
```

### Search Result

```swift
/// Search result from Pandora API
struct PandoraSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let value: String // musicToken for creating stations
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system - essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Encryption Round-Trip

*For any* input data and encryption key, encrypting the data and then decrypting the result should produce the original data.

```swift
// For all valid (data, key) pairs:
let encrypted = PandoraCrypto.encrypt(data, key: key)
let decrypted = PandoraCrypto.decrypt(encrypted, key: key)
assert(decrypted == data)
```

**Validates: Requirements 6.2, 6.3, 6.4**

### Property 2: API Response Parsing Correctness

*For any* valid Pandora API response JSON, parsing should produce correctly typed model objects with all expected fields populated.

```swift
// For all valid API responses:
let response = mockAPIResponse(for: method)
let result = PandoraClient.parse(response, for: method)
assert(result.hasAllRequiredFields)
assert(result.fieldTypes.allMatch(expectedTypes))
```

**Validates: Requirements 4.3, 4.4, 4.5, 4.6, 4.7**

### Property 3: Notification Consistency

*For any* state-changing operation (authentication, station changes, song changes, playback state), the appropriate notification should be posted with correct userInfo.

```swift
// For all state-changing operations:
let notificationExpectation = expectNotification(expectedName)
performOperation()
assert(notificationExpectation.fulfilled)
assert(notificationExpectation.userInfo.contains(expectedKeys))
```

**Validates: Requirements 2.8, 4.8, 7.8**

### Property 4: Playlist Invariants

*For any* playlist with songs:

- Calling `next()` should advance to the next song or post `noSongsLeft` if empty
- Volume setting should propagate to all active streamers
- Progress should always be less than or equal to duration

```swift
// For all playlists with songs:
let initialIndex = playlist.currentIndex
playlist.next()
assert(playlist.currentIndex == initialIndex + 1 || playlist.isEmpty)

// For all volume values:
playlist.volume = newVolume
assert(playlist.stream?.volume == newVolume)

// For all playing states:
if let progress = playlist.progress(), let duration = playlist.duration() {
    assert(progress <= duration)
}
```

**Validates: Requirements 3.2, 3.3, 3.4**

### Property 5: Playback State Machine

*For any* playback controller state and valid command, the state should transition correctly:

- `play()` from paused → playing
- `pause()` from playing → paused
- `stop()` from any state → stopped
- `next()` should advance song and maintain playing state

```swift
// For all valid state transitions:
let initialState = controller.state
controller.performCommand(command)
assert(controller.state == expectedStateAfter(initialState, command))
```

**Validates: Requirements 7.3, 7.4, 7.5**

### Property 6: State Persistence Round-Trip

*For any* playback state (current station, volume, position), saving and then restoring should produce equivalent state.

```swift
// For all playback states:
let originalState = captureState(controller)
controller.saveState()
controller.reset()
controller.restoreState()
let restoredState = captureState(controller)
assert(originalState.isEquivalent(to: restoredState))
```

**Validates: Requirements 7.9**

### Property 7: Station-StationModel Bridging

*For any* Station object, creating a StationModel from it should preserve all user-visible properties.

```swift
// For all Station objects:
let station = Station(...)
let model = StationModel(from: station)
assert(model.name == station.name)
assert(model.token == station.token)
assert(model.artUrl == station.artUrl)
// ... all properties
```

**Validates: Requirements 5.2**

## Error Handling

### Encryption Errors

```swift
enum CryptoError: Error, LocalizedError {
    case invalidKey
    case invalidHexString
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidKey: return "Invalid encryption key"
        case .invalidHexString: return "Invalid hex-encoded string"
        case .encryptionFailed: return "Encryption failed"
        case .decryptionFailed: return "Decryption failed"
        }
    }
}
```

### Audio Streaming Errors

- **Network failures**: Retry with exponential backoff, post `ASStreamError` notification
- **Timeout**: Post timeout error, allow retry via `retry()` method
- **Audio queue failures**: Log OSStatus, transition to error state
- **Buffer underrun**: Request more data, pause if necessary

### Pandora API Errors

- **Authentication failures**: Clear tokens, post error notification, return to login
- **Rate limiting**: Implement backoff, retry after delay
- **Invalid tokens**: Re-authenticate automatically
- **Network errors**: Post error notification with user-friendly message

### Recovery Strategies

1. **Automatic retry**: For transient network errors (3 attempts with backoff)
2. **Re-authentication**: For expired tokens
3. **User notification**: For persistent errors requiring user action
4. **Graceful degradation**: Continue playback if non-critical operations fail

## Testing Strategy

### Unit Testing

**Property-Based Tests** (using swift-testing or XCTest):

1. **Encryption round-trip test** - Generate random data, verify encrypt/decrypt cycle
2. **API parsing tests** - Use mock JSON responses, verify model creation
3. **State machine tests** - Test all valid state transitions
4. **Playlist invariant tests** - Test queue operations maintain invariants

**Example-Based Tests**:

1. **Known encryption vectors** - Test against known Pandora encryption examples
2. **API response fixtures** - Test parsing of real API response samples
3. **Edge cases** - Empty playlists, network timeouts, invalid inputs

### Integration Testing

1. **Audio playback** - Verify streaming works end-to-end
2. **Authentication flow** - Test login/logout cycle
3. **Station operations** - Test create/rename/delete with mock server
4. **Media key handling** - Manual verification of MPRemoteCommandCenter

### Test Configuration

- Minimum 100 iterations for property-based tests
- Use dependency injection for all testable components
- Mock network layer for unit tests
- Tag tests with feature and property references

```swift
// Example test annotation
@Test("Feature: full-swift-migration, Property 1: Encryption round-trip")
func testEncryptionRoundTrip() async throws {
    // Property-based test implementation
}
```

### Migration Verification Checklist

After each phase:

1. ✅ Build succeeds (`make CONFIGURATION=Debug`)
2. ✅ All tests pass
3. ✅ No new warnings introduced
4. ✅ Functionality verified manually
5. ✅ Property tests pass with 100+ iterations
6. ✅ Git commit with clear message

## Dependencies

### New SPM Dependency: CryptoSwift

Add to `Package.swift` or Xcode project:

```swift
dependencies: [
    .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.0")
]
```

### Existing Dependencies

- **Sparkle** - Auto-update framework (unchanged)
- **AudioToolbox.framework** - CoreAudio APIs (system framework)
- **MediaPlayer.framework** - MPRemoteCommandCenter (system framework)
- **Security.framework** - Keychain access (system framework)

## Migration Phases Summary

| Phase | Components | Estimated Effort | Dependencies |
|-------|-----------|------------------|--------------|
| 1. Foundation | PandoraCrypto, DI Integration | 4-6 hours | CryptoSwift |
| 2. Audio Layer | AudioStreamer, Playlist | 15-20 hours | Phase 1 |
| 3. API Layer | PandoraClient, Station | 14-17 hours | Phase 1, 2 |
| 4. Controllers | PlaybackController | 6-8 hours | Phase 2, 3 |
| 5. Cleanup | FMEngine, Bridging Header | 3-4 hours | Phase 1-4 |

**Total Estimated Effort: 42-55 hours over 4-5 weeks**
