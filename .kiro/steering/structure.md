# Project Structure

## Top-Level Organization

```
Hermes/
├── Sources/              # All source code
├── Resources/            # Assets, XIBs, plists, icons
├── ImportedSources/      # Third-party code (vendored)
├── Frameworks/           # Third-party frameworks (empty - Growl removed)
├── Scripts/              # Build and release automation
├── Documentation/        # Project documentation
├── Hermes.xcodeproj/     # Xcode project
└── Makefile              # Build wrapper
```

## Source Code Structure

### Swift Code (`Sources/Swift/`)

Modern SwiftUI-based UI layer:

```
Sources/Swift/
├── HermesApp.swift                    # @main entry point (SwiftUI App)
├── MinimalAppDelegate.swift           # Minimal AppDelegate for Obj-C bridge
├── Models/                            # Data models
│   ├── SongModel.swift
│   └── StationModel.swift
├── ViewModels/                        # State management
│   ├── AppState.swift                 # Central state manager
│   ├── LoginViewModel.swift
│   ├── PlayerViewModel.swift
│   ├── StationsViewModel.swift
│   └── HistoryViewModel.swift
├── Views/                             # SwiftUI views
│   ├── ContentView.swift              # Root view (state router)
│   ├── LoginView.swift
│   ├── PlayerView.swift               # Main playback interface
│   ├── SidebarView.swift              # Stations/History sidebar
│   ├── StationsListView.swift
│   ├── HistoryListView.swift
│   ├── PreferencesView.swift
│   └── ErrorView.swift
└── Utilities/
    └── NotificationBridge.swift       # Obj-C notification helpers
```

### Objective-C Code (`Sources/`)

Legacy business logic layer (being preserved):

```
Sources/
├── main.m                             # Entry point (being phased out)
├── HermesAppDelegate.{h,m}            # Legacy app delegate (being phased out)
├── HermesApp.{h,m}                    # App singleton
├── Hermes-Bridging-Header.h           # Swift bridge
├── Hermes_Prefix.pch                  # Precompiled header
├── Notifications.{h,m}                # Notification name constants
├── NetworkConnection.{h,m}            # Network reachability
├── URLConnection.{h,m}                # HTTP client
├── FileReader.{h,m}                   # File utilities
├── Pandora/                           # Pandora API client
│   ├── Pandora.{h,m}                  # Main API interface
│   ├── PandoraDevice.{h,m}            # Device configuration
│   ├── Crypt.{h,m}                    # Encryption wrapper
│   ├── Station.{h,m}                  # Station model
│   └── Song.{h,m}                     # Song model
├── AudioStreamer/                     # Audio playback
│   ├── AudioStreamer.{h,m}            # Core streaming engine
│   └── ASPlaylist.{h,m}               # Playlist management
├── Controllers/                       # Business logic controllers
│   ├── AuthController.{h,m}           # Authentication flow
│   ├── PlaybackController.{h,m}       # Playback control
│   ├── StationController.{h,m}        # Single station management
│   ├── StationsController.{h,m}       # Station list management
│   ├── HistoryController.{h,m}        # Listening history
│   ├── PreferencesController.{h,m}    # User preferences
│   └── MainSplitViewController.{h,m}  # Split view coordinator
├── Integration/                       # External integrations
│   ├── AppleScript.{h,m}              # AppleScript support
│   ├── Keychain.{h,m}                 # Keychain wrapper
│   └── Scrobbler.{h,m}                # Last.fm scrobbling
├── Models/                            # Data models
│   ├── HistoryItem.{h,m}              # History entry
│   └── ImageLoader.{h,m}              # Async image loading
└── Views/                             # Legacy AppKit views (being phased out)
    ├── HermesMainWindow.{h,m}
    ├── HermesBackgroundView.{h,m}
    ├── HermesVolumeSliderCell.{h,m}
    ├── MusicProgressSliderCell.{h,m}
    ├── StationsSidebarView.{h,m}
    ├── StationsTableView.{h,m}
    ├── HistoryView.{h,m}
    ├── HistoryCollectionView.{h,m}
    ├── LabelHoverShowField.{h,m}
    └── LabelHoverShowFieldCell.{h,m}
```

## Resources (`Resources/`)

```
Resources/
├── Hermes-Info.plist                  # App metadata
├── Hermes.sdef                        # AppleScript dictionary
├── dsa_pub.pem                        # Sparkle public key
├── pandora.icns                       # App icon
├── Credits.rtf                        # About box credits
├── English.lproj/                     # Localized resources
│   ├── InfoPlist.strings
│   └── MainMenu.xib                   # Legacy XIB (being removed)
└── Icons/                             # UI icons (PNG/PDF)
```

## Imported Sources (`ImportedSources/`)

Third-party code vendored into the project:

- `FMEngine/` - Last.fm API client (MIT license)
- `SPMediaKeyTap/` - Media key handling (BSD license)
- `blowfish/` - Blowfish encryption (public domain)

## Key Files

- **Makefile** - Build command wrapper
- **CHANGELOG.md** - Release history
- **RELEASING.md** - Release process documentation
- **.travis.yml** - CI configuration
- **add_swift_files.py** - Script to add Swift files to Xcode project

## Architecture Patterns

### Communication Flow

```
SwiftUI Views
    ↕ (Bindings)
View Models
    ↕ (NotificationCenter)
Objective-C Controllers
    ↕ (Direct calls)
Pandora API / Audio Streamer
```

### State Management

- **AppState**: Single source of truth for app-wide state
- **View Models**: Per-feature state and business logic coordination
- **Objective-C Controllers**: Stateful business logic (being wrapped by VMs)

### Notification Events

Key notifications (defined in `Notifications.h`):

- `hermes.authenticated` - User logged in
- `hermes.stations` - Stations loaded
- `hermes.song` - New song playing
- `hermes.song-rated` - Song rated
- `hermes.station-created` - Station created
- `hermes.station-removed` - Station deleted
- `hermes.error` - Error occurred

## Migration Status

The project is actively migrating from Objective-C/XIB to Swift/SwiftUI:

- ✅ **Complete**: SwiftUI views, view models, models
- 🚧 **In Progress**: Removing XIB dependencies, phasing out legacy controllers
- ⏳ **Planned**: Full SwiftUI lifecycle, remove `main.m` and legacy AppDelegate
- 🔒 **Preserved**: Objective-C business logic (Pandora API, audio streaming, crypto)

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
- **KVO** → `@Published` properties and Combine
- **Target-action** → SwiftUI button actions and closures
- **NSNotificationCenter (for UI)** → SwiftUI state management
- **Storyboard segues** → SwiftUI navigation

### What to Keep (For Now)

The Objective-C business logic layer provides stable, working functionality:

- Pandora API client (complex, working, low UI coupling)
- Audio streaming (CoreAudio wrapper, stable)
- Cryptography (Blowfish, working)
- Keychain integration (Security framework wrapper)

These can be modernized later or wrapped cleanly by Swift view models.
