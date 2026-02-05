# Hermes Codebase Review Report

## Executive Summary

This review evaluates the Hermes codebase for consistency, adherence to macOS Tahoe and Swift best practices, and identifies areas for improvement. The project is in active modernization from Objective-C/XIB to Swift/SwiftUI, and significant progress has been made. However, several inconsistencies and opportunities for improvement remain.

**Overall Assessment: Good foundation with room for refinement**

---

## 1. Architecture & Structure

### Strengths ✅

- **Clear separation of concerns**: Models, ViewModels, Views, Services, and Utilities are well-organized
- **Modern SwiftUI App lifecycle**: Uses `@main` entry point with proper `WindowGroup` and `Scene` management
- **Notification-based bridging**: Clean communication between Swift and Objective-C layers via `NotificationCenter`
- **Protocol-oriented design**: `PandoraProtocol`, `AudioStreaming`, `PlaylistProtocol` enable testability

### Issues & Recommendations 🔧

#### 1.1 Duplicate Protocol Definitions

**Problem**: `PandoraProtocol` is defined in two places with different signatures:

- `Sources/Swift/Services/Pandora/PandoraClient.swift` (lines 28-89) - `@objc protocol`
- `Sources/Swift/Models/PandoraProtocol.swift` (lines 1-200+) - `public protocol`

**Impact**: Confusion, potential runtime issues, maintenance burden

**Recommendation**: Consolidate into a single protocol definition in `PandoraProtocol.swift`. The `@objc` version in `PandoraClient.swift` should be removed or made to extend the canonical protocol.

#### 1.2 Model Duplication Pattern

**Problem**: Each model has two representations:

- `Song.swift` (Objective-C compatible, `@objc` class)
- `SongModel.swift` (SwiftUI wrapper with `@Published`)
- `Station.swift` (Objective-C compatible)
- `StationModel.swift` (SwiftUI wrapper)

**Impact**: Increased complexity, potential state synchronization issues

**Recommendation**: This is acceptable during migration, but document the pattern clearly and plan for eventual consolidation. Consider using `@Observable` (macOS 14+) to eliminate the wrapper pattern entirely.

#### 1.3 Singleton Overuse

**Problem**: Multiple singletons create tight coupling:

- `AppState.shared`
- `PlaybackController.shared`
- `ImageCache.shared`
- `SettingsManager.shared`
- `WindowTracker.shared`
- `StationArtworkLoader.shared`
- `KeychainManager.shared`

**Recommendation**:

- Keep `AppState.shared` as the single source of truth
- Inject dependencies through initializers rather than accessing singletons directly
- `PlaybackController` should be owned by `AppState`, not accessed via `MinimalAppDelegate.shared?.playbackController`

---

## 2. Naming Conventions

### Issues & Recommendations 🔧

#### 2.1 Inconsistent Notification Names

**Problem**: Notification names use multiple conventions:

```swift
// String-based (legacy)
Notification.Name("PandoraDidAuthenticateNotification")
Notification.Name("PlaybackStateDidChangeNotification")

// Extension-based (modern)
static let pandoraDidAuthenticate = Notification.Name("PandoraDidAuthenticateNotification")
static let playbackStateDidChange = Notification.Name("PlaybackStateDidChangeNotification")
```

**Recommendation**: Use the extension-based pattern exclusively. Update all usages to reference the typed constants:

```swift
// Before
NotificationCenter.default.publisher(for: Notification.Name("PandoraDidAuthenticateNotification"))

// After
NotificationCenter.default.publisher(for: .pandoraDidAuthenticate)
```

#### 2.2 Inconsistent Class Naming

**Problem**: Some classes have `Swift` prefix, others don't:

- `SwiftStation` (in `@objc(SwiftStation)`)
- `SwiftPlaylist` (in `@objc(SwiftPlaylist)`)
- `SwiftPandoraClient` (in `@objc(SwiftPandoraClient)`)

But also:

- `Song` (no prefix)
- `Station` (no prefix in Swift, but `@objc(SwiftStation)`)

**Recommendation**: Remove `Swift` prefixes from `@objc` names. Use the same name in both languages:

```swift
// Before
@objc(SwiftStation)
final class Station: Playlist { }

// After
@objc(Station)
final class Station: Playlist { }
```

#### 2.3 UserDefaults Key Inconsistency

**Problem**: Keys use different conventions:

- `"hermes.volume"` (namespaced)
- `"lastStation"` (not namespaced)
- `"pleaseBindMedia"` (legacy naming)
- `"audioQuality"` (simple)

**Recommendation**: Standardize on namespaced keys using `UserDefaultsKeys`:

```swift
struct UserDefaultsKeys {
    static let volume = "hermes.volume"
    static let lastStation = "hermes.lastStation"
    static let bindMediaKeys = "hermes.bindMediaKeys"
    static let audioQuality = "hermes.audioQuality"
}
```

---

## 3. Code Organization

### Issues & Recommendations 🔧

#### 3.1 Large Files Need Splitting

**Problem**: Several files exceed recommended size:

- `AudioStreamer.swift`: 1910 lines
- `PandoraClient.swift`: 1597 lines
- `PlayerView.swift`: 500+ lines
- `PlaybackController.swift`: 600+ lines

**Recommendation**: Split into focused extensions:

```
AudioStreamer/
├── AudioStreamer.swift (core class, ~200 lines)
├── AudioStreamer+Playback.swift
├── AudioStreamer+Network.swift
├── AudioStreamer+State.swift
└── AudioStreamerError.swift

PandoraClient/
├── PandoraClient.swift (core class)
├── PandoraClient+Authentication.swift
├── PandoraClient+Stations.swift
├── PandoraClient+Playback.swift
└── PandoraClient+Search.swift
```

#### 3.2 View File Organization

**Problem**: `PlayerView.swift` contains too many components:

- `PlayerView`
- `PlayerControlsView`
- `AlbumArtView`
- `PlaceholderArtwork`
- `PlayPauseButton`
- `ProgressBarView`
- `VolumeControl`
- `SongInfoView`
- `EmptyPlayerStateView`
- `StreamErrorOverlay`
- `RetryingOverlay`
- `WindowHoverTracker`
- `WindowSizeReader`

**Recommendation**: Extract reusable components:

```
Views/
├── Player/
│   ├── PlayerView.swift
│   ├── PlayerControlsView.swift
│   ├── AlbumArtView.swift
│   └── SongInfoView.swift
├── Components/
│   ├── PlayPauseButton.swift
│   ├── ProgressBarView.swift
│   ├── VolumeControl.swift
│   └── ErrorOverlays.swift
└── Utilities/
    ├── WindowHoverTracker.swift
    └── WindowSizeReader.swift
```

#### 3.3 Missing MARK Comments

**Problem**: Some files lack proper section organization

**Recommendation**: Add consistent MARK comments:

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Notification Handlers
```

---

## 4. SwiftUI Best Practices

### Issues & Recommendations 🔧

#### 4.1 ObservableObject vs @Observable

**Problem**: Using legacy `ObservableObject` pattern throughout:

```swift
@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var currentSong: SongModel?
    @Published var isPlaying: Bool = false
}
```

**Recommendation**: Since targeting macOS Tahoe (26.0), migrate to `@Observable`:

```swift
@MainActor
@Observable
final class PlayerViewModel {
    var currentSong: SongModel?
    var isPlaying: Bool = false
}
```

Benefits:

- Simpler syntax (no `@Published`)
- Better performance (fine-grained observation)
- No need for `@ObservedObject` in views

#### 4.2 Environment Key Pattern

**Problem**: Custom environment key in `SidebarWidthKey` but inconsistent usage

**Recommendation**: Document and standardize environment key usage:

```swift
// In ViewModifiers.swift or a dedicated EnvironmentKeys.swift
private struct SidebarWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 250
}

extension EnvironmentValues {
    var sidebarWidth: CGFloat {
        get { self[SidebarWidthKey.self] }
        set { self[SidebarWidthKey.self] = newValue }
    }
}
```

#### 4.3 Preview Provider Inconsistency

**Problem**: Mix of `#Preview` macro and `PreviewProvider`:

```swift
// Modern (preferred)
#Preview("Player - Playing") {
    PlayerControlsView(viewModel: PreviewPlayerViewModel())
}

// Legacy (should migrate)
struct LoginView_Previews: PreviewProvider {
    static var previews: some View { ... }
}
```

**Recommendation**: Use `#Preview` macro exclusively (available in Xcode 15+)

#### 4.4 Async Image Loading

**Problem**: `AsyncImage` used without proper error handling in some places:

```swift
AsyncImage(url: song.artworkURL) { phase in
    switch phase {
    case .success(let image): ...
    case .empty, .failure: PlaceholderArtwork()
    @unknown default: PlaceholderArtwork()
    }
}
```

**Recommendation**: Consider using the pre-cached `artworkImage` from `PlayerViewModel` consistently, or create a reusable `CachedAsyncImage` component.

---

## 5. State Management

### Issues & Recommendations 🔧

#### 5.1 Scattered State Access

**Problem**: State accessed through multiple paths:

- `AppState.shared.playerViewModel`
- `MinimalAppDelegate.shared?.playbackController`
- Direct `UserDefaults` access

**Recommendation**: Centralize all state access through `AppState`:

```swift
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    
    let playbackController: PlaybackController
    let playerViewModel: PlayerViewModel
    let stationsViewModel: StationsViewModel
    
    // All state flows through here
}
```

#### 5.2 Combine vs Async/Await Inconsistency

**Problem**: Mix of Combine and async/await patterns:

```swift
// Combine
NotificationCenter.default.publisher(for: .pandoraDidAuthenticate)
    .sink { ... }
    .store(in: &cancellables)

// Async/await
func authenticate() async throws {
    try await pandora.authenticate(...)
}
```

**Recommendation**: Prefer async/await for new code. Use Combine only for:

- Notification observation (until AsyncSequence adoption)
- Reactive UI bindings
- Debouncing/throttling

---

## 6. Error Handling

### Issues & Recommendations 🔧

#### 6.1 Inconsistent Error Types

**Problem**: Multiple error types with overlapping concerns:

- `PandoraError`
- `AudioStreamerError`
- `KeychainError`
- `LoginViewModel.LoginError`

**Recommendation**: Create a unified error hierarchy:

```swift
enum HermesError: LocalizedError {
    case pandora(PandoraError)
    case audio(AudioStreamerError)
    case keychain(KeychainError)
    case network(Error)
    
    var errorDescription: String? { ... }
}
```

#### 6.2 Silent Error Handling

**Problem**: Some errors are silently ignored:

```swift
try? KeychainManager.shared.saveCredentials(...)
try? FileManager.default.removeItem(...)
```

**Recommendation**: Log errors even when not propagating:

```swift
do {
    try KeychainManager.shared.saveCredentials(...)
} catch {
    Logger.auth.error("Failed to save credentials: \(error)")
}
```

---

## 7. Testing

### Strengths ✅

- Good test coverage for core functionality
- Use of modern Swift Testing framework (`@Test`, `@Suite`)
- Proper test isolation with separate `UserDefaults` suites

### Issues & Recommendations 🔧

#### 7.1 Mixed Testing Frameworks

**Problem**: Mix of XCTest and Swift Testing:

- `PlaybackControllerTests.swift` uses `@Test`, `@Suite`
- `LoginViewModelTests.swift` uses `XCTestCase`
- `StationsViewModelTests.swift` uses `XCTestCase`

**Recommendation**: Migrate all tests to Swift Testing for consistency:

```swift
// Before (XCTest)
final class LoginViewModelTests: XCTestCase {
    func testEmailValidation_ValidEmail() {
        XCTAssertTrue(sut.isValidEmail)
    }
}

// After (Swift Testing)
@Suite("LoginViewModel")
struct LoginViewModelTests {
    @Test("Valid email passes validation")
    func validEmail() {
        #expect(sut.isValidEmail == true)
    }
}
```

#### 7.2 Disabled Tests

**Problem**: Several tests are disabled with comments:

```swift
func disabled_testInitialState() {
    // DISABLED: Triggers Pandora authentication
}
```

**Recommendation**: Fix the underlying dependency injection issues and re-enable tests. Use mock protocols:

```swift
protocol PandoraProtocol {
    func authenticate(...) async throws
}

class MockPandora: PandoraProtocol {
    var authenticateResult: Result<Void, Error> = .success(())
    func authenticate(...) async throws {
        try authenticateResult.get()
    }
}
```

#### 7.3 Missing Test Coverage

**Problem**: No tests for:

- `AudioStreamer` (complex, critical component)
- `Playlist` (playback queue management)
- `ImageCache` (caching behavior)
- View components (snapshot tests)

**Recommendation**: Add tests for critical paths, especially audio streaming and playlist management.

---

## 8. Performance Considerations

### Issues & Recommendations 🔧

#### 8.1 Main Thread Work

**Problem**: Some heavy operations on main thread:

```swift
@MainActor
func updateDockIconWithAlbumArt() {
    // Image processing on main thread
    let maskedImage = IconMask.createDockIcon(from: sourceImage, ...)
    NSApp.applicationIconImage = maskedImage
}
```

**Recommendation**: Move image processing off main thread:

```swift
func updateDockIconWithAlbumArt() {
    Task.detached(priority: .userInitiated) {
        let maskedImage = IconMask.createDockIcon(from: sourceImage, ...)
        await MainActor.run {
            NSApp.applicationIconImage = maskedImage
        }
    }
}
```

#### 8.2 Notification Debouncing

**Good**: Already implemented in `PlayerViewModel`:

```swift
center.publisher(for: .stationDidPlaySong)
    .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
```

**Recommendation**: Apply consistently across all high-frequency notifications.

---

## 9. Documentation

### Issues & Recommendations 🔧

#### 9.1 Missing API Documentation

**Problem**: Many public APIs lack documentation:

```swift
func playStation(_ station: Station?) {
    // No documentation
}
```

**Recommendation**: Add DocC-compatible documentation:

```swift
/// Plays the specified station, stopping any currently playing station.
///
/// - Parameter station: The station to play, or `nil` to stop playback.
///
/// When a station starts playing, the following notifications are posted:
/// - `.playbackStateDidChange`: Indicates playback has started
/// - `.playbackSongDidChange`: Posted when the first song begins
///
/// The station is saved to UserDefaults for restoration on next launch.
func playStation(_ station: Station?) {
    ...
}
```

#### 9.2 Outdated Comments

**Problem**: Some comments reference removed functionality:

```swift
// Growl notifications (legacy)
static let pleaseGrowl = "pleaseGrowl"
```

**Recommendation**: Update comments to reflect current implementation (macOS notifications).

---

## 10. Security

### Strengths ✅

- Keychain used for credential storage
- Secure coding support (`NSSecureCoding`)
- No hardcoded credentials in source (device configs are public Pandora API keys)

### Issues & Recommendations 🔧

#### 10.1 Keychain Access in Tests

**Problem**: Tests may access real keychain:

```swift
// In KeychainManager
static let shared: KeychainProtocol = {
    if isRunningTests {
        return MockKeychainManager()
    }
    return KeychainManager()
}()
```

**Good**: Already handled, but ensure all test paths use the mock.

---

## 11. Specific File Recommendations

### High Priority

| File | Issue | Recommendation |
|------|-------|----------------|
| `PandoraClient.swift` | Duplicate protocol, 1597 lines | Split into extensions, consolidate protocol |
| `AudioStreamer.swift` | 1910 lines, complex | Split into focused files |
| `PlayerView.swift` | Too many components | Extract to separate files |
| `AppState.swift` | Singleton access patterns | Improve dependency injection |

### Medium Priority

| File | Issue | Recommendation |
|------|-------|----------------|
| `NotificationNames.swift` | Good but underutilized | Use typed names everywhere |
| `Constants.swift` | Good structure | Ensure consistent usage |
| `ViewModifiers.swift` | Minimal content | Add more shared modifiers |
| `MinimalAppDelegate.swift` | Bridge complexity | Document purpose clearly |

### Low Priority

| File | Issue | Recommendation |
|------|-------|----------------|
| `PreferencesView.swift` | Well-structured | Minor cleanup |
| `SidebarView.swift` | Good organization | Extract footer buttons |
| `MenuBarView.swift` | Clean implementation | No changes needed |

---

## 12. Migration Roadmap

### Phase 1: Immediate (1-2 weeks)

1. Consolidate `PandoraProtocol` definitions
2. Standardize notification name usage
3. Split large files into extensions
4. Fix disabled tests

### Phase 2: Short-term (1 month)

1. Migrate to `@Observable` macro
2. Improve dependency injection
3. Add missing test coverage
4. Update documentation

### Phase 3: Medium-term (2-3 months)

1. Complete Objective-C to Swift migration
2. Remove legacy patterns
3. Implement comprehensive error handling
4. Add snapshot tests for views

---

## Conclusion

The Hermes codebase demonstrates solid modernization progress with good SwiftUI patterns and clean architecture. The main areas for improvement are:

1. **Consolidation**: Reduce duplication in protocols and models
2. **Organization**: Split large files, improve structure
3. **Consistency**: Standardize naming, patterns, and testing approaches
4. **Documentation**: Add API documentation and update comments
5. **Testing**: Enable disabled tests, add coverage for critical paths

The foundation is strong, and these improvements will enhance maintainability and developer experience as the modernization continues.
