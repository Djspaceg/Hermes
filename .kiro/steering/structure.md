# Project Structure

## Top-Level Organization

```
Hermes/
├── Sources/              # Application source (Swift)
├── HermesTests/          # XCTest target, mocks, and test utilities
├── Resources/            # Assets, plists, icons, and AppleScript definition
├── ImportedSources/      # Historical third-party licensing material
├── Scripts/              # Build and release automation
├── Documentation/        # Project documentation
├── screenshots/          # README screenshots
├── .kiro/                # Steering, historical plans, and task specifications
├── Hermes.xcodeproj/     # Xcode project
└── Makefile              # Build wrapper
```

**Top-level correction (verified 2026-09-17):** The repository has no `Frameworks/` directory, and `ImportedSources/` no longer contains compilable third-party code.

## Source Code Structure

### Swift Code (`Sources/Swift/`)

Representative current application source:

```
Sources/Swift/
├── HermesApp.swift                    # @main entry point (SwiftUI App)
├── MinimalAppDelegate.swift           # AppKit lifecycle and application integration
├── Models/                            # Data models
│   ├── Song.swift
│   ├── Station.swift
│   ├── PandoraProtocol.swift
│   └── PandoraDevice.swift
├── ViewModels/                        # State management
│   ├── AppState.swift                 # Central state manager
│   ├── LoginViewModel.swift
│   ├── PlayerViewModel.swift
│   ├── StationsViewModel.swift
│   ├── HistoryViewModel.swift
│   ├── StationAddViewModel.swift
│   └── StationEditViewModel.swift
├── Views/                             # SwiftUI views
│   ├── ContentView.swift              # Root view (state router)
│   ├── LoginView.swift
│   ├── PlayerView.swift               # Main playback interface
│   ├── SidebarView.swift              # Stations/History sidebar
│   ├── StationsListView.swift
│   ├── HistoryListView.swift
│   ├── PreferencesView.swift
│   ├── MenuBarView.swift
│   └── Components/                    # Reusable playback components
├── Services/                          # Application and integration services
│   ├── Pandora/                       # Pandora API, auth, networking, and crypto
│   ├── Audio/                         # Audio streaming, decoding, buffering, and retry logic
│   ├── PlaybackController.swift
│   ├── LastFMService.swift
│   ├── AppleScriptSupport.swift
│   └── UpdateChecker.swift
└── Utilities/                         # Shared infrastructure
    ├── KeychainManager.swift
    ├── NotificationNames.swift
    ├── NotificationBridge.swift       # Combine notification publisher helpers
    ├── HTTPClient.swift
    └── NetworkMonitor.swift
```

### Historical Objective-C Layout (Removed)

The former Objective-C application source was replaced by Swift:

- `Sources/Pandora/` → `Sources/Swift/Services/Pandora/`
- `Sources/AudioStreamer/` → `Sources/Swift/Services/Audio/`
- Objective-C controllers → Swift view models and `PlaybackController.swift`
- `Notifications.{h,m}` → `Sources/Swift/Utilities/NotificationNames.swift`
- Objective-C keychain and networking helpers → `KeychainManager.swift`, `HTTPClient.swift`, and `NetworkMonitor.swift`
- Vendored Blowfish C → CryptoSwift used by `PandoraCrypto.swift`
- FMEngine Objective-C → `LastFMService.swift`

**Migration correction (verified 2026-09-17):** No tracked `.m`, `.mm`, `.h`, or `.c` files exist in the repository, and the Hermes Sources build phase contains Swift files only. The current project has no `SWIFT_OBJC_BRIDGING_HEADER` setting. `Hermes.xcodeproj/project.pbxproj.bak` preserves historical Objective-C references but is not the active project file and is not compiled.

## Resources (`Resources/`)

```
Resources/
├── Hermes-Info.plist                  # App metadata
├── Hermes.sdef                        # AppleScript dictionary
├── dsa_pub.pem                        # Legacy release-signing public key
├── pandora.icns                       # App icon
├── Credits.rtf                        # About box credits
├── English.lproj/                     # Localized resources
│   └── InfoPlist.strings
└── Icons/                             # UI icons (PNG/PDF)
```

The active project retains a stale file reference to `MainMenu.xib`, but the file is absent and it is not in the Resources build phase.

## Imported Sources (`ImportedSources/`)

Historical third-party material:

- `FMEngine/LICENSE` - retained license text only
- No ImportedSources files are in the Hermes Sources build phase
- The `ImportedSources` header search path remains configured, but there are no headers or source files there
- Current third-party code is supplied by Swift Package Manager (`CryptoSwift`)

## Key Files

- **Makefile** - Build command wrapper
- **CHANGELOG.md** - Release history
- **RELEASING.md** - Release process documentation
- **.travis.yml** - CI configuration
- **Scripts/xcode_add_file.py** - Script to add files to the Xcode project

## Architecture Patterns

### Communication Flow

```
SwiftUI Views
    ↕ (@State / @Bindable)
View Models
    ↕ (Direct dependencies + NotificationCenter/Combine)
Swift Services
    ↕
Pandora API / Playback / Audio Streamer
```

### State Management

- **AppState**: Single source of truth for app-wide state
- **View Models**: `@Observable` per-feature state and business logic coordination
- **Services**: Swift implementations for Pandora, playback, audio, integrations, and persistence

### Notification Events

Key notifications (defined in `Sources/Swift/Utilities/NotificationNames.swift`):

- `.pandoraDidAuthenticate` - User logged in
- `.pandoraDidLoadStations` - Stations loaded
- `.stationDidPlaySong` - New song playing
- `.pandoraDidRateSong` - Song rated
- `.pandoraDidCreateStation` - Station created
- `.pandoraDidDeleteStation` - Station deleted
- `.pandoraDidError` - Pandora error occurred

## Migration Status

The Objective-C/XIB-to-Swift migration is complete for application source:

- ✅ **Complete**: SwiftUI lifecycle, views, view models, models, and services
- ✅ **Complete**: Swift Pandora client, audio streamer, networking, crypto, keychain, and Last.fm service
- ✅ **Complete**: Removal of project Objective-C/C source and the bridging header
- 🧹 **Remaining historical artifacts**: Legacy comments/docs, `project.pbxproj.bak`, an absent `MainMenu.xib` project reference, release-signing assets, search paths for the absent `Frameworks/` directory, and `GCC_PRECOMPILE_PREFIX_HEADER = YES` without a prefix-header path

## Modernization Guidelines

When encountering legacy code:

1. **Identify the purpose** - What is this code trying to accomplish?
2. **Find the modern equivalent** - What's the current Apple-recommended approach?
3. **Replace, don't patch** - Rewrite using modern patterns, don't add workarounds
4. **Remove dead code** - If it's not needed, delete it
5. **Document decisions** - Note why you chose a particular modern approach

### Legacy Patterns to Replace

- **XIB/NIB files** → SwiftUI views
- **NSViewController** → SwiftUI View structs
- **Delegates and callbacks** → Combine publishers and async/await
- **Manual layout** → SwiftUI's declarative layout
- **KVO** → Observation for view state, or Combine where a publisher stream is required
- **Target-action** → SwiftUI button actions and closures
- **NSNotificationCenter (for UI)** → SwiftUI state management
- **Storyboard segues** → SwiftUI navigation

### Current Core Services

The former Objective-C responsibilities now live in these Swift implementations:

- Pandora API: `Sources/Swift/Services/Pandora/`
- Audio streaming: `Sources/Swift/Services/Audio/`
- Cryptography: `PandoraCrypto.swift` with CryptoSwift
- Keychain: `Sources/Swift/Utilities/KeychainManager.swift`
- Last.fm: `Sources/Swift/Services/LastFMService.swift`

**Current-service correction (verified 2026-09-17):** Preserve behavior through these Swift services; do not look for a retained Objective-C foundation layer.
