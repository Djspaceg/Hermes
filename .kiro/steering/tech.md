# Technology Stack

## Build System

- **Xcode Project**: `Hermes.xcodeproj`
- **Build Tool**: `xcodebuild` (wrapped by Makefile)
- **Target macOS**: Tahoe (26.0) exclusively
- **Version Management**: Apple Generic Versioning (`agvtool`)

## Languages & Frameworks

### Swift/SwiftUI (UI Layer)

- SwiftUI for all views and UI components
- Combine for reactive state management
- `@main` app entry point with `WindowGroup`
- View models using `@ObservableObject` and `@Published`

### Objective-C (Business Logic Layer)

- Pandora API client (`Sources/Pandora/`)
- Audio streaming (`Sources/AudioStreamer/`)
- Networking and URL connections
- Cryptography (Blowfish encryption)
- Keychain integration
- Controllers for business logic

### Bridging

- `Sources/Hermes-Bridging-Header.h` exposes Objective-C to Swift
- `NotificationCenter` for cross-layer communication
- Notification names defined in `Sources/Notifications.h`

## Key Dependencies

### System Frameworks

- `Cocoa.framework` - macOS UI foundation
- `AudioToolbox.framework` - Audio playback
- `Security.framework` - Keychain access
- `SystemConfiguration.framework` - Network reachability
- `MediaPlayer.framework` - Media controls via MPRemoteCommandCenter
- `Quartz.framework` - Graphics

### Third-Party Libraries (Imported)

- **FMEngine** (`ImportedSources/FMEngine/`) - Last.fm API client
- **Blowfish** (`ImportedSources/blowfish/`) - Encryption for Pandora API

### Package Dependencies

- Sparkle (via Swift Package Manager) - Auto-update framework

## Common Commands

### Building

```bash
make                    # Build with Debug configuration
make CONFIGURATION=Release  # Build with Release configuration
make run                # Build and run (logs to stdout)
make dbg                # Build and run in LLDB debugger
```

### Testing & CI

```bash
make travis             # CI build (no code signing)
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
- **Sparkle updates**: Require DSA signature (private key: `hermes.key`)
