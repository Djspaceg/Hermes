# Technology Stack

## Development Workflow

- **Building**: Use `make` or `make CONFIGURATION=Release` to build
- **Testing**: Use `make test`; do not auto-launch the app
- **Debugging**: User will report issues; use debug logging when needed

## Build System

- **Xcode Project**: `Hermes.xcodeproj`
- **Build Tool**: `xcodebuild` (wrapped by Makefile)
- **Target macOS**: Tahoe (26.0) exclusively
- **Version Management**: Apple Generic Versioning (`agvtool`)

## Languages & Frameworks

### Swift Application Source

- SwiftUI for views, scenes, settings, and menu bar UI
- Swift Observation (`@Observable`) for app state, models, and primary view models
- Combine and `NotificationCenter` publishers where event streams are still useful
- `@main` app entry point with SwiftUI scenes
- Swift services for Pandora, playback, audio streaming, networking, Last.fm, crypto, and keychain access

**Current-state correction (verified 2026-09-17):** The former Objective-C business logic layer was replaced by Swift. `Sources/Pandora/`, `Sources/AudioStreamer/`, `Sources/Notifications.h`, and `Sources/Hermes-Bridging-Header.h` no longer exist; their current implementations are under `Sources/Swift/`.

### Objective-C Runtime Interoperability

- The tracked repository contains no `.m`, `.mm`, `.h`, or `.c` source files
- The Hermes Sources build phase contains Swift files only
- The current Xcode build settings do not define `SWIFT_OBJC_BRIDGING_HEADER` or another project-local umbrella header
- Some Swift declarations use `@objc`, `NSObject`, and selectors for Cocoa/AppKit, AppleScript, and Objective-C runtime APIs; this is framework interoperability, not a compiled Objective-C application layer

### Internal Communication

- Swift components communicate through direct references, dependency injection, and `NotificationCenter`
- Type-safe notification names are defined in `Sources/Swift/Utilities/NotificationNames.swift`
- `Sources/Swift/Utilities/NotificationBridge.swift` contains Combine publisher helpers; its name is historical and it does not bridge to project-local Objective-C source

**Bridge correction (verified 2026-09-17):** There is no application-source Swift↔Objective-C bridge or bridging header in the current target.

## Key Dependencies

### System Frameworks

- SwiftUI / AppKit / Cocoa - macOS UI, lifecycle, menus, and scripting integration
- Combine / Observation - state observation and event streams
- `AudioToolbox.framework` and CoreAudio - audio parsing and playback
- `Security.framework` - Keychain access
- Network framework - connectivity monitoring
- `MediaPlayer.framework` - Media controls via MPRemoteCommandCenter
- UserNotifications framework - song notifications

### Third-Party Libraries

- **CryptoSwift** (Swift Package Manager) - Blowfish for Pandora crypto and MD5 for Last.fm request signing
- `ImportedSources/FMEngine/` contains only the historical FMEngine license and contributes no compiled source
- `ImportedSources/blowfish/` is absent; `Sources/Swift/Services/Pandora/PandoraCrypto.swift` uses CryptoSwift instead

**Dependency correction (verified 2026-09-17):** CryptoSwift is the only Swift package product linked by the Hermes target. Sparkle is not linked; `UpdateChecker.swift` checks GitHub Releases directly. Legacy Sparkle DSA assets and signing scripts remain as release tooling.

## Common Commands

### Building

```bash
make                    # Build with Debug configuration
make CONFIGURATION=Release  # Build with Release configuration
make run                # Build and run (logs to stdout; prints PID and run token)
make stop PID=<pid> TOKEN=<token>  # Stop only that make run launch
make dbg                # Build and run in LLDB debugger
```

### Testing & CI

```bash
make travis             # CI build (no code signing)
make test               # Run the Hermes test scheme
```

### Release Management

```bash
make archive            # Create distributable .zip (Release config)
make upload-release GITHUB_ACCESS_TOKEN=<token>  # Upload release to GitHub
make install            # Install to /Applications
```

### Version Management

```bash
agvtool bump -all       # Increment build number
agvtool new-marketing-version X.Y.Z  # Set version string
agvtool mvers -terse1   # Show current marketing version
```

### Cleaning

```bash
make clean              # Remove build artifacts
```

## Build Configuration Notes

- **Media keys**: Handled via MPRemoteCommandCenter (modern macOS API)
- **Release builds**: Require code signing for distribution
- **Code signing**: Uses `CODE_SIGN_IDENTITY` from Xcode settings
- **Update checks**: `UpdateChecker.swift` queries GitHub Releases
- **Legacy release signing**: DSA assets/scripts remain for the existing release workflow, but no Sparkle framework is linked
