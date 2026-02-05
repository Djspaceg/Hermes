# Design Document: Codebase Modernization

## Overview

This design document outlines the technical approach for refining and modernizing the Hermes macOS Pandora client codebase. The codebase has **already been fully migrated to Swift/SwiftUI** with zero Objective-C code remaining. This modernization focuses on adopting Swift 5.9+ features (@Observable, #Preview, Swift Testing), improving code organization, and enhancing testability.

The modernization refines the existing Swift/SwiftUI codebase by:

- Consolidating duplicate model definitions (Song/SongModel, Station/StationModel)
- Adopting Swift 5.9+ features (@Observable macro, #Preview macro, Swift Testing)
- Improving code organization by splitting large files
- Enhancing testing infrastructure and coverage
- Optimizing performance and threading
- Adding comprehensive documentation

The design is structured around three implementation phases:

- **Phase 1 (1-2 weeks)**: Foundation - Critical consolidations and standardizations
- **Phase 2 (1 month)**: Modern Patterns - Swift 5.9+ adoption and testing infrastructure
- **Phase 3 (2-3 months)**: Complete Refinement - Code organization and optimization

The modernization targets macOS Tahoe (26.0) exclusively, allowing us to leverage the latest Apple technologies without backward compatibility constraints.

### Design Principles

1. **Built-in First**: Prefer platform-provided solutions over custom implementations
2. **Incremental Migration**: Each phase delivers working, tested improvements
3. **Maintain Functionality**: All existing features continue to work throughout migration
4. **Modern Patterns**: Adopt Swift 5.9+ features (@Observable, #Preview, Swift Testing)
5. **Testability**: Improve test coverage and enable property-based testing

## Architecture

### Current Architecture

The codebase is 100% Swift/SwiftUI with modern patterns already in place:

```
┌─────────────────────────────────────────────────────────┐
│                    SwiftUI Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Views        │  │ View Models  │  │ AppState     │ │
│  │ (SwiftUI)    │  │(ObservableObj)│  │ (Singleton)  │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
                          ↕ Typed Notifications
┌─────────────────────────────────────────────────────────┐
│                 Business Logic Layer                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Services     │  │ Pandora API  │  │ Audio        │ │
│  │ (Swift)      │  │ (Swift)      │  │ Streamer     │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Current State**:

- ✅ 100% Swift/SwiftUI (no Objective-C)
- ✅ Typed notification names (NotificationNames.swift)
- ✅ Modern async/await patterns in use
- ✅ URLSession-based image caching (ImageCache.swift)
- ✅ Dependency injection patterns (PandoraProtocol)
- ⚠️ Duplicate models (Song/SongModel, Station/StationModel)
- ⚠️ Duplicate protocol definition (PandoraProtocol in two files)
- ⚠️ Large files (AudioStreamer: 1910 lines, PandoraClient: 1597 lines)
- ⚠️ ObservableObject instead of @Observable macro
- ⚠️ Mix of PreviewProvider and #Preview
- ⚠️ Scattered UserDefaults keys

### Target Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    SwiftUI Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Views        │  │ View Models  │  │ AppState     │ │
│  │ (SwiftUI)    │  │ (@Observable)│  │ (@Observable)│ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│         ↕                  ↕                  ↕         │
│  ┌──────────────────────────────────────────────────┐  │
│  │         Unified Models (@Observable)             │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐      │  │
│  │  │ Song     │  │ Station  │  │ History  │      │  │
│  │  └──────────┘  └──────────┘  └──────────┘      │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                          ↕ Typed Notifications
┌─────────────────────────────────────────────────────────┐
│            Business Logic Layer (Modular)               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Services     │  │ Pandora API  │  │ Audio        │ │
│  │ (Swift)      │  │ (Modular)    │  │ (Modular)    │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Key Architectural Changes

1. **Unified Model Layer**: Consolidate duplicate models (Song/SongModel → Song, Station/StationModel → Station) using @Observable
2. **Single Protocol Definition**: Remove duplicate PandoraProtocol definition
3. **Modern State Management**: Migrate from ObservableObject to @Observable macro
4. **Modular Code Organization**: Split large files into focused, maintainable components
5. **Consistent Preview Syntax**: Migrate all previews to #Preview macro
6. **Centralized Configuration**: Create UserDefaultsKeys utility for type-safe preferences

## Components and Interfaces

### Phase 1: Foundation Components

#### 1.1 Remove Duplicate PandoraProtocol Definition

**Current State**: PandoraProtocol is defined in two places:

- `Sources/Swift/Models/PandoraProtocol.swift` (standalone protocol file with documentation)
- Inline in `Sources/Swift/Services/Pandora/PandoraClient.swift` (duplicate definition)

**Target State**: Single canonical definition in PandoraProtocol.swift

**Action**: Remove the inline protocol definition from PandoraClient.swift, keeping only the standalone file.

#### 1.2 UserDefaults Keys Centralization

**File**: `Sources/Swift/Utilities/UserDefaultsKeys.swift`

```swift
import Foundation

/// Centralized UserDefaults keys with type-safe access
struct UserDefaultsKeys {
    // MARK: - Authentication
    static let username = "pandora.username"
    static let rememberLogin = "rememberLogin"
    
    // MARK: - Playback
    static let volume = "hermes.volume"
    static let lastStation = "lastStation"
    static let audioQuality = "audioQuality"
    static let playOnStart = "playOnStart"
    
    // MARK: - Preferences
    static let scrobbleEnabled = "PLEASE_SCROBBLE"
    static let onlyScrobbleLiked = "ONLY_SCROBBLE_LIKED"
    static let notificationsEnabled = "PLEASE_GROWL"
    static let notifyOnPlay = "PLEASE_GROWL_PLAY"
    static let notifyOnNewSong = "PLEASE_GROWL_NEW"
    static let mediaKeysEnabled = "pleaseBindMedia"
    static let alwaysOnTop = "alwaysOnTop"
    static let dockIconAlbumArt = "dockIconAlbumArt"
    
    // MARK: - Window State
    static let sidebarWidth = "DRAWER_WIDTH"
    static let historySidebarWidth = "HIST_DRAWER_WIDTH"
    static let openDrawer = "OPEN_DRAWER"
    static let closeDrawer = "PLEASE_CLOSE_DRAWER"
    
    // MARK: - Proxy
    static let proxyEnabled = "ENABLED_PROXY"
    static let proxyAudio = "PROXY_AUDIO"
    
    // MARK: - Screensaver/Lock
    static let pauseOnScreensaverStart = "pauseOnScreensaverStart"
    static let playOnScreensaverStop = "playOnScreensaverStop"
    static let pauseOnScreenLock = "pauseOnScreenLock"
    static let playOnScreenUnlock = "playOnScreenUnlock"
    
    // MARK: - Launch Behavior
    static let playAutomaticallyOnLaunch = "playAutomaticallyOnLaunch"
}
```

**Migration Strategy**:

1. Create UserDefaultsKeys.swift with all existing keys
2. Search codebase for UserDefaults string literals
3. Replace with UserDefaultsKeys constants
4. Verify all functionality works

#### 1.3 Unified Model Layer

**Current State**: Duplicate models exist:

- `Song.swift`: Base model with @objc compatibility, NSCoding support
- `SongModel.swift`: SwiftUI wrapper with @Published properties
- `Station.swift`: Base model extending Playlist
- `StationModel.swift`: SwiftUI wrapper with @Published properties

**Problem**: This creates confusion and maintenance overhead. The wrapper pattern was needed for Objective-C bridging, but since there's no Objective-C code, we can consolidate.

**Target State**: Single @Observable model for each entity

**File**: `Sources/Swift/Models/Song.swift` (consolidated)

```swift
import Foundation
import Observation

/// Unified song model representing a Pandora track
@Observable
final class Song: Identifiable {
    // MARK: - Properties
    
    let id: String
    var artist: String
    var title: String
    var album: String
    var artworkURL: URL?
    var albumUrl: String?
    var artistUrl: String?
    var titleUrl: String?
    var token: String?
    
    var highUrl: String?
    var medUrl: String?
    var lowUrl: String?
    
    var trackGain: String?
    var allowFeedback: Bool = true
    var rating: Int = 0  // 0 = no rating, 1 = thumbs up, -1 = thumbs down
    var isTired: Bool = false
    
    var playDate: Date?
    var stationId: String?
    
    // MARK: - Computed Properties
    
    var playDateString: String? {
        guard let playDate = playDate else { return nil }
        return Self.dateFormatter.string(from: playDate)
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        artist: String = "",
        title: String = "",
        album: String = "",
        artworkURL: URL? = nil,
        rating: Int = 0
    ) {
        self.id = id
        self.artist = artist
        self.title = title
        self.album = album
        self.artworkURL = artworkURL
        self.rating = rating
    }
}

// MARK: - Equatable
extension Song: Equatable {
    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable
extension Song: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

**File**: `Sources/Swift/Models/Station.swift` (consolidated)

```swift
import Foundation
import Observation

/// Unified station model representing a Pandora radio station
@Observable
final class Station: Identifiable {
    // MARK: - Properties
    
    let id: String
    var name: String
    let token: String
    let stationId: String
    let created: Date
    var shared: Bool
    var allowRename: Bool
    var allowAddMusic: Bool
    var isQuickMix: Bool
    var artworkURL: URL?
    var genres: [String]
    
    // Playback state
    var playingSong: Song?
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        name: String,
        token: String,
        stationId: String,
        created: Date = Date(),
        shared: Bool = false,
        allowRename: Bool = true,
        allowAddMusic: Bool = true,
        isQuickMix: Bool = false,
        artworkURL: URL? = nil,
        genres: [String] = []
    ) {
        self.id = id
        self.name = name
        self.token = token
        self.stationId = stationId
        self.created = created
        self.shared = shared
        self.allowRename = allowRename
        self.allowAddMusic = allowAddMusic
        self.isQuickMix = isQuickMix
        self.artworkURL = artworkURL
        self.genres = genres
    }
}

// MARK: - Equatable
extension Station: Equatable {
    static func == (lhs: Station, rhs: Station) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable
extension Station: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

**Migration Strategy**:

1. **Phase 1**: Keep both models, add @Observable to wrapper models
2. **Phase 2**: Gradually migrate views to use base models directly
3. **Phase 3**: Remove wrapper models once all references updated
4. **Verify**: Run all tests after each step

#### 1.5 Error Hierarchy

**File**: `Sources/Swift/Utilities/HermesError.swift`

```swift
import Foundation

/// Unified error hierarchy for Hermes application
enum HermesError: LocalizedError {
    // MARK: - Authentication Errors
    case authenticationFailed(reason: String)
    case invalidCredentials
    case networkUnavailable
    
    // MARK: - API Errors
    case apiError(code: Int, message: String)
    case invalidResponse
    case decodingFailed(Error)
    
    // MARK: - Playback Errors
    case streamingFailed(reason: String)
    case audioDeviceUnavailable
    case playlistEmpty
    
    // MARK: - Station Errors
    case stationNotFound
    case stationCreationFailed(reason: String)
    case stationDeletionFailed(reason: String)
    
    // MARK: - LocalizedError Conformance
    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .invalidCredentials:
            return "Invalid username or password"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .streamingFailed(let reason):
            return "Streaming failed: \(reason)"
        case .audioDeviceUnavailable:
            return "Audio device unavailable"
        case .playlistEmpty:
            return "Playlist is empty"
        case .stationNotFound:
            return "Station not found"
        case .stationCreationFailed(let reason):
            return "Failed to create station: \(reason)"
        case .stationDeletionFailed(let reason):
            return "Failed to delete station: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .authenticationFailed, .invalidCredentials:
            return "Please check your credentials and try again"
        case .networkUnavailable:
            return "Please check your internet connection"
        case .apiError:
            return "Please try again later"
        case .streamingFailed, .audioDeviceUnavailable:
            return "Please check your audio settings"
        case .playlistEmpty:
            return "Please select a different station"
        default:
            return nil
        }
    }
}
```

### Phase 2: Modern Patterns

#### 2.1 AppState Centralization

**File**: `Sources/Swift/ViewModels/AppState.swift`

```swift
import Foundation
import Combine

/// Central state manager for the Hermes application
@MainActor
@Observable
final class AppState {
    // MARK: - Singleton
    static let shared = AppState()
    
    // MARK: - Authentication State
    var isAuthenticated: Bool = false
    var currentUser: String?
    
    // MARK: - Station State
    var stations: [Station] = []
    var currentStation: Station?
    
    // MARK: - Playback State
    var currentSong: Song?
    var isPlaying: Bool = false
    var volume: Double = 0.5
    var playbackProgress: Double = 0.0
    
    // MARK: - History State
    var history: [HistoryItem] = []
    
    // MARK: - Error State
    var currentError: HermesError?
    
    // MARK: - Initialization
    private init() {
        setupNotificationObservers()
        loadPersistedState()
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthenticated),
            name: .hermesAuthenticated,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStationsLoaded),
            name: .hermesStationsLoaded,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSongPlaying),
            name: .hermesSongPlaying,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleError),
            name: .hermesError,
            object: nil
        )
    }
    
    // MARK: - Notification Handlers
    @objc private func handleAuthenticated(_ notification: Notification) {
        isAuthenticated = true
        if let username = notification.userInfo?["username"] as? String {
            currentUser = username
        }
    }
    
    @objc private func handleStationsLoaded(_ notification: Notification) {
        if let objcStations = notification.userInfo?["stations"] as? [ObjCStation] {
            stations = objcStations.map { Station(objcStation: $0) }
        }
    }
    
    @objc private func handleSongPlaying(_ notification: Notification) {
        if let objcSong = notification.userInfo?["song"] as? ObjCSong {
            currentSong = Song(objcSong: objcSong)
            isPlaying = true
        }
    }
    
    @objc private func handleError(_ notification: Notification) {
        if let error = notification.userInfo?["error"] as? HermesError {
            currentError = error
        }
    }
    
    // MARK: - State Persistence
    private func loadPersistedState() {
        volume = UserDefaults.standard.double(forKey: UserDefaults.Keys.volume)
        if volume == 0 { volume = 0.5 } // Default volume
    }
    
    func saveState() {
        UserDefaults.standard.set(volume, forKey: UserDefaults.Keys.volume)
        if let stationID = currentStation?.identifier {
            UserDefaults.standard.set(stationID, forKey: UserDefaults.Keys.lastStationID)
        }
    }
}
```

#### 2.2 View Model Pattern with Dependency Injection

**File**: `Sources/Swift/ViewModels/PlayerViewModel.swift`

```swift
import Foundation
import Combine

/// View model managing player view state and interactions
@MainActor
@Observable
final class PlayerViewModel {
    // MARK: - Dependencies
    private let appState: AppState
    private let playbackController: PlaybackController
    
    // MARK: - Published State
    var currentSong: Song? { appState.currentSong }
    var isPlaying: Bool { appState.isPlaying }
    var volume: Double {
        get { appState.volume }
        set { 
            appState.volume = newValue
            playbackController.setVolume(newValue)
        }
    }
    
    // MARK: - Initialization
    init(
        appState: AppState = .shared,
        playbackController: PlaybackController = .shared
    ) {
        self.appState = appState
        self.playbackController = playbackController
    }
    
    // MARK: - Actions
    func togglePlayPause() {
        if isPlaying {
            playbackController.pause()
        } else {
            playbackController.play()
        }
    }
    
    func skipSong() async {
        do {
            try await playbackController.skip()
        } catch {
            appState.currentError = error as? HermesError
        }
    }
    
    func rateSong(_ rating: Song.Rating) async {
        guard let song = currentSong else { return }
        
        do {
            try await playbackController.rate(song, rating: rating)
            song.rating = rating
        } catch {
            appState.currentError = error as? HermesError
        }
    }
    
    func markTired() async {
        guard let song = currentSong else { return }
        
        do {
            try await playbackController.markTired(song)
            song.isTired = true
            try await playbackController.skip()
        } catch {
            appState.currentError = error as? HermesError
        }
    }
}
```

### Phase 3: Complete Modernization

#### 3.1 File Organization Strategy

Large files will be split following these patterns:

**AudioStreamer.swift (1910 lines) → Multiple files:**

- `AudioStreamer.swift` - Core streaming engine (300 lines)
- `AudioStreamState.swift` - State management (150 lines)
- `AudioStreamBuffer.swift` - Buffer management (200 lines)
- `AudioStreamDecoder.swift` - Audio decoding (200 lines)
- `AudioStreamOutput.swift` - Audio output (150 lines)
- `AudioStreamError.swift` - Error types (100 lines)

**PandoraClient.swift (1597 lines) → Multiple files:**

- `PandoraClient.swift` - Main client interface (200 lines)
- `PandoraAuth.swift` - Authentication (200 lines)
- `PandoraStations.swift` - Station operations (250 lines)
- `PandoraPlayback.swift` - Playback operations (250 lines)
- `PandoraNetwork.swift` - Network layer (250 lines)
- `PandoraCrypto.swift` - Encryption (150 lines)
- `PandoraModels.swift` - Response models (200 lines)

**PlayerView.swift (500+ lines) → Multiple files:**

- `PlayerView.swift` - Main container (100 lines)
- `AlbumArtworkView.swift` - Artwork display (80 lines)
- `PlaybackControlsView.swift` - Play/pause/skip buttons (100 lines)
- `SongInfoView.swift` - Song metadata display (80 lines)
- `RatingControlsView.swift` - Thumbs up/down/tired (80 lines)
- `VolumeControlView.swift` - Volume slider (60 lines)

#### 3.2 Reusable Component Library

**File**: `Sources/Swift/Views/Components/GlassButton.swift`

```swift
import SwiftUI

/// Reusable button with glass morphism effect
struct GlassButton: View {
    // MARK: - Properties
    let icon: String
    let action: () -> Void
    var size: CGFloat = 44
    var isEnabled: Bool = true
    
    // MARK: - Body
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.5))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        }
        .buttonStyle(GlassButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Button Style
private struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview("Enabled") {
    GlassButton(icon: "play.fill", action: {})
        .padding()
        .background(.black)
}

#Preview("Disabled") {
    GlassButton(icon: "play.fill", action: {}, isEnabled: false)
        .padding()
        .background(.black)
}
```

#### 3.3 Environment Key Pattern

**File**: `Sources/Swift/Utilities/EnvironmentKeys.swift`

```swift
import SwiftUI

// MARK: - AppState Environment Key
private struct AppStateKey: EnvironmentKey {
    static let defaultValue: AppState = .shared
}

extension EnvironmentValues {
    var appState: AppState {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}

// MARK: - PlaybackController Environment Key
private struct PlaybackControllerKey: EnvironmentKey {
    static let defaultValue: PlaybackController = .shared
}

extension EnvironmentValues {
    var playbackController: PlaybackController {
        get { self[PlaybackControllerKey.self] }
        set { self[PlaybackControllerKey.self] = newValue }
    }
}

// MARK: - View Extension for Injection
extension View {
    func withAppDependencies(
        appState: AppState = .shared,
        playbackController: PlaybackController = .shared
    ) -> some View {
        self
            .environment(\.appState, appState)
            .environment(\.playbackController, playbackController)
    }
}
```

#### 3.4 Async Image Loading

**File**: `Sources/Swift/Utilities/ImageCache.swift`

```swift
import SwiftUI
import os.log

/// Thread-safe image cache with memory management
actor ImageCache {
    // MARK: - Singleton
    static let shared = ImageCache()
    
    // MARK: - Properties
    private var cache: [URL: NSImage] = [:]
    private let maxCacheSize = 50
    private let logger = Logger(subsystem: "com.hermes", category: "ImageCache")
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Cache Operations
    func image(for url: URL) -> NSImage? {
        cache[url]
    }
    
    func setImage(_ image: NSImage, for url: URL) {
        if cache.count >= maxCacheSize {
            // Remove oldest entry (simple FIFO)
            if let firstKey = cache.keys.first {
                cache.removeValue(forKey: firstKey)
            }
        }
        cache[url] = image
        logger.debug("Cached image for URL: \(url.absoluteString)")
    }
    
    func clear() {
        cache.removeAll()
        logger.info("Image cache cleared")
    }
}

/// Async image view with caching
struct CachedAsyncImage: View {
    // MARK: - Properties
    let url: URL?
    var placeholder: Image = Image(systemName: "music.note")
    
    @State private var image: NSImage?
    @State private var isLoading = false
    
    // MARK: - Body
    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                placeholder
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }
    
    // MARK: - Image Loading
    private func loadImage() async {
        guard let url, !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Check cache first
        if let cachedImage = await ImageCache.shared.image(for: url) {
            image = cachedImage
            return
        }
        
        // Download image
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = NSImage(data: data) {
                await ImageCache.shared.setImage(downloadedImage, for: url)
                image = downloadedImage
            }
        } catch {
            Logger(subsystem: "com.hermes", category: "ImageCache")
                .error("Failed to load image: \(error.localizedDescription)")
        }
    }
}
```

## Data Models

The codebase currently has duplicate Swift models that need consolidation:

### Current Model Duplication

**Problem**: Each domain entity has two Swift model representations:

- `Song.swift`: Base model with @objc compatibility, NSCoding, dictionary conversion
- `SongModel.swift`: SwiftUI wrapper with ObservableObject and @Published properties
- `Station.swift`: Base model extending Playlist with playback capabilities
- `StationModel.swift`: SwiftUI wrapper with ObservableObject and @Published properties

This creates:

- Confusion about which model to use in different contexts
- Potential state synchronization issues between base and wrapper
- Maintenance overhead (changes must be made in two places)
- Unnecessary complexity in the codebase

**Why This Pattern Existed**: The wrapper pattern was originally needed for Objective-C bridging. Since the codebase is now 100% Swift, this pattern is no longer necessary.

### Target Model Structure

```
┌─────────────────────────────────────────────────────────┐
│              Unified Swift Models (@Observable)         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │ Song     │  │ Station  │  │ History  │             │
│  │          │  │          │  │ Item     │             │
│  └──────────┘  └──────────┘  └──────────┘             │
│                                                         │
│  Used by:                                               │
│  - AppState (central state)                             │
│  - View Models (feature state)                          │
│  - Views (display)                                      │
│  - Services (business logic)                            │
└─────────────────────────────────────────────────────────┘
```

### Consolidation Strategy

For each duplicate model pair:

1. **Audit both implementations**: Identify which has more complete functionality
   - Song.swift has: NSCoding, dictionary conversion, AppleScript support, station reference
   - SongModel.swift has: ObservableObject, @Published rating, notification observers

2. **Merge capabilities**: Combine best features from both into single @Observable model
   - Keep all properties from base model
   - Add @Observable macro for automatic change tracking
   - Remove @Published wrappers (not needed with @Observable)
   - Keep essential functionality (NSCoding for history persistence)

3. **Update references**: Find and update all usages throughout codebase
   - Views using SongModel → use Song directly
   - View models using SongModel → use Song directly
   - Services already use Song → no changes needed

4. **Delete duplicate**: Remove the wrapper model file (SongModel.swift, StationModel.swift)

5. **Verify tests**: Ensure all tests pass with consolidated model

### Model Characteristics

All models should:

- Use `@Observable` macro for automatic change tracking (Swift 5.9+)
- Implement `Equatable` and `Hashable` where appropriate
- Have clear, documented properties with DocC comments
- Follow single responsibility principle
- Be immutable where possible (use `let` for properties that don't change)
- Use value types (struct) for simple data, reference types (class) for entities with identity

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

For this modernization project, most correctness properties focus on verifying code organization, patterns, and architectural constraints rather than algorithmic correctness. The properties below ensure that modernization changes maintain functionality and follow established patterns.

### Property 1: Model State Consistency

*For any* sequence of model property updates, all observers should see consistent state without intermediate or stale values.

**Validates: Requirements 2.3, 10.4**

This property ensures that when a model's properties are updated (e.g., Song rating changes), all views observing that model see the updated state consistently. The @Observable macro should provide automatic, consistent state propagation.

### Property 2: Image Cache Bounded Size

*For any* sequence of image cache operations, the cache size should never exceed the configured maximum (50 images by default).

**Validates: Requirements 13.3**

This property ensures proper memory management in the image caching system. No matter how many images are loaded, the cache should evict old entries to maintain the size limit.

### Property 3: Notification Debouncing Reduces Frequency

*For any* rapid sequence of notifications (more than 10 per second), debouncing should reduce the processing frequency to at most one per debounce interval.

**Validates: Requirements 22.1**

This property ensures that debouncing actually reduces notification processing load. When notifications fire rapidly, the debounced handler should be called significantly fewer times than the raw notification count.

### Property 4: Debouncing Processes Latest Value

*For any* debounced notification sequence, the final processed value should match the last notification value in the sequence.

**Validates: Requirements 22.3**

This property ensures debouncing doesn't lose the most recent state. Even though intermediate notifications are skipped, the final state should reflect the latest update.

### Example Tests

The following behaviors should be verified through example-based unit tests:

#### Code Organization Examples

**Single Protocol Definition** (Validates: Requirements 1.2)

- Verify exactly one PandoraProtocol definition exists in the codebase
- Verify it's located in `Sources/Swift/Protocols/PandoraProtocol.swift`

**Typed Notification Constants** (Validates: Requirements 4.1, 4.2)

- Verify all notification posting uses `Notification.Name` constants
- Verify no string literals are used for notification names
- Verify all constants are defined in `NotificationNames.swift`

**UserDefaults Key Conventions** (Validates: Requirements 6.1, 6.4, 6.5)

- Verify all keys follow reverse-DNS notation (`com.hermes.*`)
- Verify all keys are defined in `UserDefaultsKeys.swift`
- Verify reading old preference keys still works (backward compatibility)

#### Dependency Injection Examples

**Mockable Dependencies** (Validates: Requirements 3.5)

- Verify view models accept dependencies via initializer
- Verify tests can inject mock implementations
- Verify no hard-coded singleton references in testable code

#### Component Design Examples

**Configurable Components** (Validates: Requirements 8.3)

- Verify `GlassButton` accepts size, icon, and action parameters
- Verify `CachedAsyncImage` accepts URL and placeholder parameters
- Verify components render correctly with different configurations

#### State Management Examples

**Observable State Updates** (Validates: Requirements 10.4)

- Verify changing `AppState.currentSong` triggers `PlayerView` update
- Verify changing `AppState.isPlaying` updates play/pause button
- Verify state changes propagate to all observing views

**Environment Default Values** (Validates: Requirements 11.2)

- Verify all `EnvironmentKey` implementations provide default values
- Verify views can access environment values without explicit injection

#### Image Loading Examples

**Failed Load Placeholders** (Validates: Requirements 13.4)

- Verify `CachedAsyncImage` shows placeholder when URL is nil
- Verify placeholder appears when network request fails
- Verify placeholder appears when image data is invalid

**AppState Propagation** (Validates: Requirements 14.4)

- Verify updating `AppState.volume` updates all volume controls
- Verify updating `AppState.stations` updates sidebar
- Verify state changes are atomic and consistent

#### Error Handling Examples

**Async Error Propagation** (Validates: Requirements 15.5)

- Verify thrown errors in async methods propagate to callers
- Verify Task cancellation is handled correctly
- Verify error context is preserved through async boundaries

**Error Descriptions** (Validates: Requirements 16.2)

- Verify all `HermesError` cases have non-empty `errorDescription`
- Verify error messages are user-friendly
- Verify recovery suggestions are provided where applicable

**Logging Context** (Validates: Requirements 17.2)

- Verify error logs include file name
- Verify error logs include line number
- Verify error logs include function name

#### Testing Examples

**Test Consistency** (Validates: Requirements 19.3)

- Verify all tests pass 10 consecutive times
- Verify no race conditions in async tests
- Verify tests don't depend on execution order

#### Threading Examples

**Background Operations** (Validates: Requirements 21.1)

- Verify image loading doesn't block main thread
- Verify API requests don't block main thread
- Verify heavy parsing operations run on background threads

**Main Thread UI Updates** (Validates: Requirements 21.3)

- Verify all SwiftUI view updates happen on main thread
- Verify `@MainActor` is applied to view models
- Verify async completion handlers dispatch to main thread for UI updates

## Error Handling

### Error Hierarchy

The unified `HermesError` enum provides comprehensive error handling:

```swift
enum HermesError: LocalizedError {
    case authenticationFailed(reason: String)
    case invalidCredentials
    case networkUnavailable
    case apiError(code: Int, message: String)
    case invalidResponse
    case decodingFailed(Error)
    case streamingFailed(reason: String)
    case audioDeviceUnavailable
    case playlistEmpty
    case stationNotFound
    case stationCreationFailed(reason: String)
    case stationDeletionFailed(reason: String)
}
```

### Error Handling Patterns

**1. Async/Await Error Propagation**

```swift
func fetchStations() async throws -> [Station] {
    do {
        let objcStations = try await pandoraClient.fetchStations()
        return objcStations.map { Station(objcStation: $0) }
    } catch let error as PandoraAPIError {
        throw HermesError.apiError(code: error.code, message: error.message)
    } catch {
        throw HermesError.networkUnavailable
    }
}
```

**2. View Model Error Handling**

```swift
func performAction() async {
    do {
        try await riskyOperation()
    } catch let error as HermesError {
        appState.currentError = error
    } catch {
        appState.currentError = .apiError(code: -1, message: error.localizedDescription)
    }
}
```

**3. Logging with Context**

```swift
import os.log

private let logger = Logger(subsystem: "com.hermes", category: "Playback")

func handleError(_ error: Error) {
    logger.error("Playback failed: \(error.localizedDescription, privacy: .public)")
}
```

### Error Recovery

- **Authentication errors**: Prompt user to re-login
- **Network errors**: Show retry option with exponential backoff
- **Streaming errors**: Attempt to skip to next song
- **API errors**: Display user-friendly message with error code

## Testing Strategy

### Dual Testing Approach

The modernization project requires both unit tests and property-based tests:

**Unit Tests**: Verify specific examples, edge cases, and error conditions

- Code organization verification (single protocol definition, typed constants)
- Dependency injection patterns (mockable dependencies)
- Component configuration (parameters, rendering)
- State management (updates, propagation)
- Error handling (descriptions, logging, propagation)
- Threading (main thread UI, background operations)

**Property-Based Tests**: Verify universal properties across all inputs

- Model conversion round-trips (Obj-C ↔ Swift)
- Image cache size bounds
- Notification debouncing behavior
- State consistency invariants

### Testing Framework

**Swift Testing Framework**: All tests will use the modern Swift Testing framework with `@Test` attributes and `@Suite` organization.

```swift
import Testing

@Suite("Model Conversion")
struct ModelConversionTests {
    @Test("Song round-trip preserves properties")
    func songRoundTrip() async throws {
        // Test implementation
    }
    
    @Test("Station round-trip preserves properties")
    func stationRoundTrip() async throws {
        // Test implementation
    }
}
```

### Property-Based Testing Configuration

**Library**: Use `swift-check` or similar property-based testing library for Swift

**Configuration**:

- Minimum 100 iterations per property test
- Each test tagged with feature name and property number
- Tag format: `// Feature: codebase-modernization, Property N: [property text]`

**Example Property Test**:

```swift
import Testing
import SwiftCheck

@Suite("Model Conversion Properties")
struct ModelConversionPropertyTests {
    // Feature: codebase-modernization, Property 1: Model conversion round-trip
    @Test("Song conversion round-trip", .tags(.property))
    func songConversionRoundTrip() {
        property("Converting Song to ObjC and back preserves all fields") <- forAll { (song: Song) in
            let objcSong = song.toObjC()
            let convertedSong = Song(objcSong: objcSong)
            return song == convertedSong
        }.withIterations(100)
    }
}
```

### Test Coverage Goals

- **Phase 1**: Maintain existing test coverage (no regression)
- **Phase 2**: Achieve 80% coverage for critical components (AudioStreamer, Playlist, ImageCache)
- **Phase 3**: Achieve 90% coverage for all Swift code

### Test Organization

```
Tests/
├── UnitTests/
│   ├── ModelTests/
│   │   ├── SongTests.swift
│   │   └── StationTests.swift
│   ├── ViewModelTests/
│   │   ├── AppStateTests.swift
│   │   ├── PlayerViewModelTests.swift
│   │   └── StationsViewModelTests.swift
│   ├── UtilityTests/
│   │   ├── NotificationTests.swift
│   │   ├── UserDefaultsTests.swift
│   │   └── ImageCacheTests.swift
│   └── ComponentTests/
│       ├── GlassButtonTests.swift
│       └── CachedAsyncImageTests.swift
├── PropertyTests/
│   ├── ModelConversionPropertyTests.swift
│   ├── ImageCachePropertyTests.swift
│   └── NotificationDebouncingPropertyTests.swift
└── IntegrationTests/
    ├── AuthenticationFlowTests.swift
    ├── PlaybackFlowTests.swift
    └── StationManagementTests.swift
```

## Implementation Phases

### Phase 1: Foundation (1-2 weeks)

**Goal**: Establish stable foundation with critical consolidations

**Tasks**:

1. Consolidate duplicate protocol definitions
2. Create unified notification constants (`NotificationNames.swift`)
3. Create unified UserDefaults keys (`UserDefaultsKeys.swift`)
4. Establish model bridge pattern (Song, Station)
5. Create unified error hierarchy (`HermesError`)
6. Verify all existing tests pass

**Deliverables**:

- Single `PandoraProtocol` definition
- Typed notification constants
- Namespaced UserDefaults keys
- Bridge pattern for models
- Unified error types
- All tests passing

### Phase 2: Modern Patterns (1 month)

**Goal**: Adopt modern Swift patterns and improve testing

**Tasks**:

1. Centralize state in `AppState`
2. Refactor view models to use dependency injection
3. Standardize async/await usage
4. Improve error handling and logging
5. Migrate tests to Swift Testing framework
6. Fix and re-enable disabled tests
7. Add missing test coverage (AudioStreamer, Playlist, ImageCache)
8. Implement property-based tests

**Deliverables**:

- Centralized `AppState` singleton
- Dependency-injected view models
- Consistent async/await patterns
- Comprehensive error logging
- All tests migrated to Swift Testing
- 80% code coverage for critical components
- Property-based tests for key behaviors

### Phase 3: Complete Modernization (2-3 months)

**Goal**: Full migration to Swift 5.9+ features

**Tasks**:

1. Migrate all view models to `@Observable` macro
2. Migrate all previews to `#Preview` macro
3. Split large files (AudioStreamer, PandoraClient, PlayerView)
4. Extract reusable view components
5. Standardize environment key usage
6. Improve async image loading with caching
7. Add consistent MARK comments
8. Add DocC documentation
9. Update outdated comments
10. Performance optimization (threading, debouncing)

**Deliverables**:

- All view models using `@Observable`
- All previews using `#Preview`
- No files exceeding 500 lines
- Reusable component library
- Standardized environment keys
- Efficient image caching
- Consistent code organization
- Comprehensive DocC documentation
- Optimized performance

### Success Criteria

**Phase 1 Complete When**:

- Zero duplicate protocol definitions
- All notifications use typed constants
- All UserDefaults keys are namespaced
- Model bridge pattern is established
- All tests pass

**Phase 2 Complete When**:

- AppState is single source of truth
- All view models use dependency injection
- All async code uses async/await
- All tests use Swift Testing framework
- 80% code coverage achieved
- Property-based tests implemented

**Phase 3 Complete When**:

- All view models use `@Observable`
- All previews use `#Preview`
- No files exceed 500 lines
- Reusable components extracted
- DocC documentation complete
- 90% code coverage achieved
- Performance benchmarks met

## Migration Strategy

### Incremental Approach

Each phase delivers working, tested improvements:

1. **Make changes incrementally**: Don't refactor everything at once
2. **Test after each change**: Ensure tests pass before moving forward
3. **Maintain functionality**: All features continue working throughout migration
4. **Document decisions**: Record architectural choices and patterns

### Backward Compatibility

During modernization, maintain compatibility with existing code:

- **Gradual consolidation**: Merge duplicate models one at a time
- **Notification compatibility**: Support both old and new notification names during transition period
- **UserDefaults migration**: Read old keys for backward compatibility, write new keys, eventually deprecate old keys
- **Deprecation warnings**: Mark old patterns as deprecated before removing

### Risk Mitigation

- **Comprehensive testing**: Run full test suite after each change
- **Code review**: Review all modernization changes
- **Incremental deployment**: Deploy phase by phase, not all at once
- **Rollback plan**: Keep git history clean for easy rollback if needed

## Performance Considerations

### Threading Optimization

**Main Thread**:

- All SwiftUI view updates
- All `@MainActor` annotated code
- Notification handling that updates UI

**Background Threads**:

- Image loading and caching
- API requests and response parsing
- Audio streaming and decoding
- File I/O operations

### Notification Debouncing

Apply debouncing to high-frequency notifications:

```swift
NotificationCenter.default.publisher(for: .hermesSongProgress)
    .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
    .sink { notification in
        // Update UI with debounced progress
    }
```

### Memory Management

- **Image cache**: Bounded size with LRU eviction
- **Weak references**: Use weak references for delegates and observers
- **Automatic cleanup**: Leverage Swift's ARC and deinit
- **Cache invalidation**: Clear caches on memory warnings

## Documentation Standards

### DocC Documentation

All public APIs should include DocC-compatible documentation:

```swift
/// Manages playback of Pandora radio stations.
///
/// The `PlaybackController` coordinates between the Pandora API client
/// and the audio streaming engine to provide seamless music playback.
///
/// ## Topics
///
/// ### Playing Music
/// - ``play()``
/// - ``pause()``
/// - ``skip()``
///
/// ### Rating Songs
/// - ``rate(_:rating:)``
/// - ``markTired(_:)``
///
@MainActor
final class PlaybackController {
    /// Starts or resumes playback of the current station.
    ///
    /// - Throws: `HermesError.playlistEmpty` if no songs are available
    /// - Throws: `HermesError.streamingFailed` if audio streaming fails
    func play() async throws {
        // Implementation
    }
}
```

### Code Comments

- **MARK comments**: Organize code sections consistently
- **Inline comments**: Explain complex logic, not obvious code
- **TODO comments**: Only for planned work, include issue number
- **Documentation comments**: Use `///` for public APIs

### Architecture Documentation

Maintain up-to-date architecture documentation:

- **README.md**: Project overview and setup instructions
- **ARCHITECTURE.md**: High-level architecture and design decisions
- **CONTRIBUTING.md**: Development guidelines and conventions
- **CHANGELOG.md**: Track all modernization changes

## Conclusion

This design provides a comprehensive, phased approach to modernizing the Hermes codebase. By following these patterns and principles, we'll transform the legacy Objective-C/XIB codebase into a modern Swift/SwiftUI application that leverages the latest Apple technologies while maintaining all existing functionality.

The three-phase approach ensures incremental progress with clear milestones and success criteria. Each phase builds on the previous one, delivering tangible improvements that can be tested and validated before moving forward.
