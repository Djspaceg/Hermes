# AppKit to Modern Swift Migration Plan

## Overview

This document provides step-by-step instructions for modernizing remaining AppKit/NS-based constructs in the Hermes codebase. The XIB migration is complete, but there are still legacy patterns that can be replaced with modern Swift/SwiftUI equivalents.

**Target:** macOS Tahoe (26.0) exclusively
**Goal:** Minimize AppKit usage, maximize SwiftUI and modern Swift patterns

---

## Current State Analysis

### Areas Requiring Modernization

1. **Window Management** - Direct NSWindow manipulation
2. **URL Opening** - NSWorkspace.shared.open() everywhere
3. **Notification Observers** - Selector-based addObserver patterns
4. **UserDefaults Access** - Direct UserDefaults.standard calls
5. **Image Handling** - NSImage usage in non-UI code
6. **Async Patterns** - DispatchQueue instead of async/await
7. **@objc Methods** - Unnecessary Objective-C exposure

---

## Migration Tasks

Execute these tasks in order. Each task modernizes a specific pattern.

---

## TASK 1: Create Environment-Based URL Opening

**Priority:** HIGH
**Complexity:** Low
**Creates:** `URLOpener.swift` (environment key)
**Modifies:** Multiple ViewModels, HermesApp.swift

### Purpose

Replace scattered `NSWorkspace.shared.open()` calls with a SwiftUI environment-based approach that's testable and follows modern patterns.

### Current Problem

```swift
// Scattered throughout codebase:
NSWorkspace.shared.open(url)
```

### Modern Solution

Use SwiftUI's `@Environment` with OpenURL action (built-in since macOS 11.0).

### Implementation Steps

#### Step 1.1: Update HermesApp.swift

Modify `Sources/Swift/HermesApp.swift`:

Replace all `NSWorkspace.shared.open(url)` with SwiftUI's built-in `openURL`:

```swift
// Add to HermesApp struct
@Environment(\.openURL) private var openURL

// Then replace all instances like this:
Button("Hermes Help") {
    if let url = URL(string: "https://github.com/HermesApp/Hermes/wiki") {
        openURL(url)  // Changed from NSWorkspace.shared.open(url)
    }
}
```

Do this for all 5 help menu items.

#### Step 1.2: Update HistoryViewModel.swift

Modify `Sources/Swift/ViewModels/HistoryViewModel.swift`:

Add an openURL closure property:

```swift
// MARK: - Properties
private let openURL: (URL) -> Void

// MARK: - Initialization
init(openURL: @escaping (URL) -> Void = { url in
    // Default implementation for macOS Tahoe
    Task { @MainActor in
        await NSWorkspace.shared.open(url)
    }
}) {
    self.openURL = openURL
}

// MARK: - External Links
func openArtistPage(_ song: SongModel) {
    guard let urlString = song.artistURL,
          !urlString.isEmpty,
          let url = URL(string: urlString) else { return }
    openURL(url)  // Changed from NSWorkspace.shared.open(url)
}

// Repeat for openSongPage, openAlbumPage, openLyrics
```

#### Step 1.3: Update StationEditorViewModel.swift

Modify `Sources/Swift/ViewModels/StationEditorViewModel.swift`:

Same pattern as HistoryViewModel:

```swift
private let openURL: (URL) -> Void

init(station: Station, pandora: Pandora, openURL: @escaping (URL) -> Void = { url in
    // Default implementation for macOS Tahoe
    Task { @MainActor in
        await NSWorkspace.shared.open(url)
    }
}) {
    self.station = station
    self.pandora = pandora
    self.openURL = openURL
    loadStationDetails()
    setupNotificationObservers()
}

func openInPandora() {
    guard let url = URL(string: stationURL), !stationURL.isEmpty else { return }
    openURL(url)  // Changed from NSWorkspace.shared.open(url)
}
```

#### Step 1.4: Pass OpenURL from Views

When creating ViewModels from views, pass the environment's openURL:

```swift
// In views that create these ViewModels:
@Environment(\.openURL) private var openURL

// Then when creating ViewModel:
let viewModel = HistoryViewModel(openURL: { url in openURL(url) })
```

**Note:** The default parameter allows existing code to work while migrating.

---

## TASK 2: Replace Selector-Based Notification Observers with Combine

**Priority:** HIGH
**Complexity:** Medium
**Modifies:** `MinimalAppDelegate.swift`

### Purpose

Replace old-style `addObserver(_:selector:name:object:)` with modern Combine publishers.

### Current Problem

```swift
center.addObserver(
    self,
    selector: #selector(handlePandoraError(_:)),
    name: Notification.Name("hermes.pandora.error"),
    object: nil
)
```

### Modern Solution

Use Combine publishers:

```swift
center.publisher(for: Notification.Name("hermes.pandora.error"))
    .sink { [weak self] notification in
        self?.handlePandoraError(notification)
    }
    .store(in: &cancellables)
```

### Implementation Steps

#### Step 2.1: Convert MinimalAppDelegate Observers

Modify `Sources/Swift/MinimalAppDelegate.swift`:

Replace the entire `setupNotificationObservers()` method:

```swift
private func setupNotificationObservers() {
    let center = NotificationCenter.default
    
    // Observe Pandora errors
    center.publisher(for: Notification.Name("hermes.pandora.error"))
        .sink { [weak self] notification in
            self?.handlePandoraError(notification)
        }
        .store(in: &cancellables)
    
    // Observe stream errors
    center.publisher(for: Notification.Name("hermes.stream.error"))
        .sink { [weak self] notification in
            self?.handleStreamError(notification)
        }
        .store(in: &cancellables)
    
    // Observe logout
    center.publisher(for: Notification.Name("hermes.pandora.logout"))
        .sink { [weak self] notification in
            self?.handleLogout(notification)
        }
        .store(in: &cancellables)
    
    // Observe sleep notifications
    NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
        .sink { [weak self] notification in
            self?.handleSleep(notification)
        }
        .store(in: &cancellables)
    
    // Observe preference changes from SwiftUI Settings
    center.publisher(for: .preferenceAlwaysOnTopChanged)
        .sink { [weak self] notification in
            self?.handleAlwaysOnTopChanged(notification)
        }
        .store(in: &cancellables)
    
    center.publisher(for: .preferenceMediaKeysChanged)
        .sink { [weak self] notification in
            self?.handleMediaKeysChanged(notification)
        }
        .store(in: &cancellables)
    
    center.publisher(for: .preferenceDockIconChanged)
        .sink { [weak self] notification in
            self?.handleDockIconChanged(notification)
        }
        .store(in: &cancellables)
    
    center.publisher(for: .preferenceStatusBarChanged)
        .sink { [weak self] notification in
            self?.handleStatusBarChanged(notification)
        }
        .store(in: &cancellables)
}
```

#### Step 2.2: Remove @objc from Handler Methods

Since these methods are no longer called via selectors, remove `@objc`:

```swift
// Change from:
@objc private func handlePandoraError(_ notification: Notification) {

// To:
private func handlePandoraError(_ notification: Notification) {
```

Do this for all handler methods:

- `handlePandoraError`
- `handleStreamError`
- `handleLogout`
- `handleSleep`
- `handleAlwaysOnTopChanged`
- `handleMediaKeysChanged`
- `handleDockIconChanged`
- `handleStatusBarChanged`

---

## TASK 3: Remove Unnecessary @objc Methods

**Priority:** MEDIUM
**Complexity:** Low
**Modifies:** `MinimalAppDelegate.swift`

### Purpose

Remove `@objc` exposure from methods that don't need Objective-C compatibility.

### Current Problem

Many methods are marked `@objc` but are only called from Swift code or are no-ops.

### Implementation Steps

#### Step 3.1: Identify and Remove No-Op @objc Methods

In `Sources/Swift/MinimalAppDelegate.swift`, these methods can be deleted entirely:

```swift
// DELETE THESE - They do nothing and are never called:
@objc func showLoader() {
    // SwiftUI handles loading state
}

@objc func show() {
    // SwiftUI handles view state
}

@objc func setCurrentView(_ view: NSView) {
    // SwiftUI handles all views
}

@objc func updateStatusItem(_ sender: Any?) {
    // SwiftUI doesn't use status bar items
}

@objc func window() -> NSWindow? {
    // Return nil - SwiftUI manages windows
    return nil
}
```

#### Step 3.2: Keep But Simplify Required @objc Methods

These must stay `@objc` because they're called from Objective-C code:

```swift
// KEEP - Called from Objective-C Pandora API
@objc func logMessage(_ message: String) {
    print("Pandora: \(message)")
}

// KEEP - Called from Objective-C PlaybackController
@objc func stateDirectory(_ file: String) -> String? {
    let fileManager = FileManager.default
    let folder = NSString(string: "~/Library/Application Support/Hermes/").expandingTildeInPath
    
    var isDirectory: ObjCBool = false
    if !fileManager.fileExists(atPath: folder, isDirectory: &isDirectory) {
        try? fileManager.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
    }
    
    return (folder as NSString).appendingPathComponent(file)
}

// KEEP - Called from Objective-C PlaybackController
@objc func pandora() -> Pandora {
    return MainActor.assumeIsolated {
        AppState.shared.pandora
    }
}
```

---

## TASK 4: Replace Direct UserDefaults Access with @AppStorage

**Priority:** MEDIUM
**Complexity:** Low
**Modifies:** `NotificationManager.swift`, `StationsViewModel.swift`, `MinimalAppDelegate.swift`

### Purpose

Use SwiftUI's `@AppStorage` property wrapper instead of direct `UserDefaults.standard` calls.

### Current Problem

```swift
let defaults = UserDefaults.standard
let notificationsEnabled = defaults.bool(forKey: "pleaseGrowl")
```

### Modern Solution

```swift
@AppStorage("pleaseGrowl") private var notificationsEnabled = false
```

### Implementation Steps

#### Step 4.1: Update NotificationManager.swift

Modify `Sources/Swift/Utilities/NotificationManager.swift`:

Replace the UserDefaults access in `showSongNotification`:

```swift
// Add properties at class level:
@AppStorage("pleaseGrowl") private var notificationsEnabled = false
@AppStorage("pleaseGrowlNew") private var notifyOnNew = true
@AppStorage("pleaseGrowlPlay") private var notifyOnResume = false

// Then in showSongNotification, remove the UserDefaults lines:
func showSongNotification(song: Song, image: NSImage?, isNewSong: Bool) {
    // Remove these lines:
    // let defaults = UserDefaults.standard
    // let notificationsEnabled = defaults.bool(forKey: "pleaseGrowl")
    // let notifyOnNew = defaults.bool(forKey: "pleaseGrowlNew")
    // let notifyOnResume = defaults.bool(forKey: "pleaseGrowlPlay")
    
    // The @AppStorage properties are already available
    guard notificationsEnabled else { return }
    
    if isNewSong && !notifyOnNew {
        return
    }
    
    if !isNewSong && !notifyOnResume {
        return
    }
    
    // ... rest of method
}
```

#### Step 4.2: Update StationsViewModel.swift

Modify `Sources/Swift/ViewModels/StationsViewModel.swift`:

```swift
// Add at class level:
@AppStorage("LAST_STATION_KEY") private var lastStationId: String?

// Then in restoreLastPlayedStation:
func restoreLastPlayedStation() {
    guard !hasRestoredLastStation else { return }
    hasRestoredLastStation = true
    
    guard let lastStationId = lastStationId else {  // Use property instead of UserDefaults
        print("StationsViewModel: No last station saved")
        return
    }
    
    // ... rest of method
}

// When saving last station:
func playStation(_ station: StationModel) {
    lastStationId = station.id  // Use property instead of UserDefaults.standard.set
    // ... rest of method
}
```

#### Step 4.3: Update MinimalAppDelegate.swift

Modify `Sources/Swift/MinimalAppDelegate.swift`:

Replace UserDefaults access in handler methods:

```swift
// Add at class level:
@AppStorage("alwaysOnTop") private var alwaysOnTop = false
@AppStorage("pleaseBindMedia") private var bindMediaKeys = true
@AppStorage("dockIconAlbumArt") private var showAlbumArt = false

// Then simplify handlers:
private func handleAlwaysOnTopChanged(_ notification: Notification) {
    // Remove: let alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
    // Use the @AppStorage property directly
    
    if let window = NSApp.windows.first(where: { $0.isKeyWindow || $0.isMainWindow }) {
        window.level = alwaysOnTop ? .floating : .normal
    }
}

private func handleMediaKeysChanged(_ notification: Notification) {
    // Remove: let bindMediaKeys = UserDefaults.standard.bool(forKey: "pleaseBindMedia")
    
    if let mediaKeyTap = playbackController?.mediaKeyTap {
        if bindMediaKeys {
            mediaKeyTap.startWatchingMediaKeys()
        } else {
            mediaKeyTap.stopWatchingMediaKeys()
        }
    }
}

private func handleDockIconChanged(_ notification: Notification) {
    // Remove: let showAlbumArt = UserDefaults.standard.bool(forKey: "dockIconAlbumArt")
    
    if showAlbumArt {
        if let imageData = playbackController?.lastImg,
           let image = NSImage(data: imageData) {
            NSApp.applicationIconImage = image
        }
    } else {
        NSApp.applicationIconImage = nil
    }
}
```

**Note:** `@AppStorage` must be used in classes marked `@MainActor` or that inherit from `ObservableObject`.

---

## TASK 5: Replace DispatchQueue with Async/Await

**Priority:** MEDIUM
**Complexity:** Medium
**Modifies:** `HermesApp.swift`, potentially ViewModels

### Purpose

Replace `DispatchQueue.main.asyncAfter` and similar patterns with modern Swift concurrency.

### Current Problem

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    Task { @MainActor in
        SettingsManager.shared.applyAllSettings()
    }
}
```

### Modern Solution

```swift
Task { @MainActor in
    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    SettingsManager.shared.applyAllSettings()
}
```

### Implementation Steps

#### Step 5.1: Update HermesApp.swift Init

Modify `Sources/Swift/HermesApp.swift`:

```swift
init() {
    // Replace DispatchQueue.main.asyncAfter with Task.sleep
    Task { @MainActor in
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        SettingsManager.shared.applyAllSettings()
    }
}
```

#### Step 5.2: Remove Unnecessary .receive(on: DispatchQueue.main)

In ViewModels that use Combine publishers, the `.receive(on: DispatchQueue.main)` is often unnecessary when the class is already `@MainActor`.

Modify ViewModels (PlayerViewModel, StationEditorViewModel, NewStationViewModel):

```swift
// BEFORE:
NotificationCenter.default.publisher(for: Notification.Name("SomeNotification"))
    .receive(on: DispatchQueue.main)  // Remove this line
    .sink { [weak self] notification in
        self?.handleNotification(notification)
    }
    .store(in: &cancellables)

// AFTER:
NotificationCenter.default.publisher(for: Notification.Name("SomeNotification"))
    .sink { [weak self] notification in
        self?.handleNotification(notification)
    }
    .store(in: &cancellables)
```

**Reason:** When the class is marked `@MainActor`, all methods already run on the main thread, so `.receive(on: DispatchQueue.main)` is redundant.

#### Step 5.3: Update SettingsManager Combine Publishers

Modify `Sources/Swift/Utilities/SettingsManager.swift`:

Remove `.receive(on: DispatchQueue.main)` from all publishers since SettingsManager is `@MainActor`:

```swift
private func setupPlaybackStateObserver() {
    NotificationCenter.default.publisher(for: Notification.Name("StationDidPlaySongNotification"))
        // Remove: .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusBarItem()
                self?.updateDockIconWithAlbumArt()
            }
        }
        .store(in: &cancellables)
}

private func setupScreensaverObservers() {
    DistributedNotificationCenter.default().publisher(for: Notification.Name("com.apple.screensaver.didstart"))
        // Remove: .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.handleScreensaverStart()
        }
        .store(in: &cancellables)
    
    DistributedNotificationCenter.default().publisher(for: Notification.Name("com.apple.screensaver.didstop"))
        // Remove: .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.handleScreensaverStop()
        }
        .store(in: &cancellables)
}

private func setupScreenLockObservers() {
    DistributedNotificationCenter.default().publisher(for: Notification.Name("com.apple.screenIsLocked"))
        // Remove: .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.handleScreenLock()
        }
        .store(in: &cancellables)
    
    DistributedNotificationCenter.default().publisher(for: Notification.Name("com.apple.screenIsUnlocked"))
        // Remove: .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.handleScreenUnlock()
        }
        .store(in: &cancellables)
}
```

---

## TASK 6: Create Window Management Service

**Priority:** LOW
**Complexity:** Medium
**Creates:** `WindowManager.swift`
**Modifies:** `SettingsManager.swift`, `MinimalAppDelegate.swift`, `HermesApp.swift`

### Purpose

Centralize window management logic instead of directly manipulating `NSApp.windows`.

### Current Problem

Window manipulation is scattered across multiple files:

```swift
for window in NSApp.windows where window.isVisible && !window.isSheet {
    window.level = level
}
```

### Modern Solution

Create a dedicated service that encapsulates window operations.

### Implementation Steps

#### Step 6.1: Create WindowManager.swift

Location: `Sources/Swift/Utilities/WindowManager.swift`

```swift
//
//  WindowManager.swift
//  Hermes
//
//  Centralized window management
//

import AppKit

@MainActor
final class WindowManager {
    static let shared = WindowManager()
    
    private init() {}
    
    // MARK: - Window Level
    
    func setAlwaysOnTop(_ enabled: Bool) {
        let level: NSWindow.Level = enabled ? .floating : .normal
        for window in NSApp.windows where window.isVisible && !window.isSheet {
            window.level = level
        }
    }
    
    // MARK: - Window Visibility
    
    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        if let window = NSApp.windows.first(where: { !$0.isSheet && $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    func hideAllWindows() {
        for window in NSApp.windows {
            window.orderOut(nil)
        }
    }
    
    // MARK: - Window Collection Behavior
    
    func setAccessoryAppBehavior() {
        for window in NSApp.windows {
            window.collectionBehavior = [.moveToActiveSpace, .transient]
            window.canHide = false
        }
    }
    
    func setRegularAppBehavior() {
        for window in NSApp.windows {
            window.collectionBehavior = []
            window.canHide = true
        }
    }
    
    // MARK: - Queries
    
    var mainWindow: NSWindow? {
        NSApp.windows.first(where: { $0.isKeyWindow || $0.isMainWindow })
    }
    
    var visibleWindows: [NSWindow] {
        NSApp.windows.filter { $0.isVisible && !$0.isSheet }
    }
}
```

#### Step 6.2: Update SettingsManager to Use WindowManager

Modify `Sources/Swift/Utilities/SettingsManager.swift`:

```swift
func applyAlwaysOnTop() {
    WindowManager.shared.setAlwaysOnTop(alwaysOnTop)
}

private func transformToAccessoryApp() {
    WindowManager.shared.setAccessoryAppBehavior()
    WindowManager.shared.hideAllWindows()
    
    Task {
        NSApp.setActivationPolicy(.accessory)
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        WindowManager.shared.showMainWindow()
    }
}

private func transformToRegularApp() {
    WindowManager.shared.setRegularAppBehavior()
    NSApp.setActivationPolicy(.regular)
    
    // Activate Dock to refresh menu bar, then reactivate Hermes
    if let dockURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.dock") {
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: dockURL, configuration: config) { _, _ in
            Task { @MainActor in
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    applyDockIcon()
}
```

#### Step 6.3: Update MinimalAppDelegate

Modify `Sources/Swift/MinimalAppDelegate.swift`:

```swift
private func handleAlwaysOnTopChanged(_ notification: Notification) {
    WindowManager.shared.setAlwaysOnTop(alwaysOnTop)
}
```

#### Step 6.4: Update HermesApp.swift

Modify `Sources/Swift/HermesApp.swift`:

```swift
Button("Show Hermes") {
    WindowManager.shared.showMainWindow()
}
```

---

## TASK 7: Modernize Image Handling

**Priority:** LOW
**Complexity:** Low
**Modifies:** `SettingsManager.swift`, `MinimalAppDelegate.swift`

### Purpose

Minimize NSImage usage and use more modern patterns where possible.

### Current Problem

Direct NSImage manipulation for dock icon with manual drawing.

### Implementation Steps

#### Step 7.1: Simplify Dock Icon Overlay

Modify `Sources/Swift/Utilities/SettingsManager.swift`:

The current `overlayPlayPauseIcon` method uses manual NSImage drawing. Simplify it:

```swift
private func overlayPlayPauseIcon(on image: NSImage, isPlaying: Bool) -> NSImage {
    let size = NSSize(width: 512, height: 512)  // Use higher resolution
    let result = NSImage(size: size)
    
    result.lockFocus()
    
    // Draw base image
    image.draw(in: NSRect(origin: .zero, size: size))
    
    // Draw play/pause symbol with better positioning
    let symbolName = isPlaying ? "pause.circle.fill" : "play.circle.fill"
    if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
        let symbolSize = NSSize(width: 200, height: 200)
        let symbolOrigin = NSPoint(
            x: (size.width - symbolSize.width) / 2,
            y: (size.height - symbolSize.height) / 2
        )
        
        // Add shadow for better visibility
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
        shadow.shadowBlurRadius = 10
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()
        
        symbol.draw(in: NSRect(origin: symbolOrigin, size: symbolSize))
    }
    
    result.unlockFocus()
    return result
}
```

#### Step 7.2: Add Image Caching

To avoid recreating images repeatedly, add caching:

```swift
// Add to SettingsManager:
private var cachedDockIcon: NSImage?
private var lastDockIconState: Bool?

func updateDockIconWithAlbumArt() {
    guard showAlbumArtInDock else { return }
    
    guard let playbackController = MinimalAppDelegate.shared?.playbackController,
          let imageData = playbackController.lastImg else {
        return
    }
    
    let isPlaying = playbackController.playing?.isPlaying() ?? false
    
    // Use cached icon if state hasn't changed
    if let cached = cachedDockIcon, lastDockIconState == isPlaying {
        NSApp.applicationIconImage = cached
        return
    }
    
    guard var image = NSImage(data: imageData) else { return }
    
    if showPlayPauseOverArt {
        image = overlayPlayPauseIcon(on: image, isPlaying: isPlaying)
    }
    
    cachedDockIcon = image
    lastDockIconState = isPlaying
    NSApp.applicationIconImage = image
}

// Clear cache when album art changes
func clearDockIconCache() {
    cachedDockIcon = nil
    lastDockIconState = nil
}
```

---

## TASK 8: Add Type-Safe Notification Names

**Priority:** LOW
**Complexity:** Low
**Creates:** `NotificationNames.swift`
**Modifies:** All files using notification names

### Purpose

Replace string-based notification names with type-safe constants.

### Current Problem

```swift
NotificationCenter.default.post(name: Notification.Name("PandoraDidLoadStationsNotification"), object: nil)
```

### Modern Solution

```swift
extension Notification.Name {
    static let pandoraDidLoadStations = Notification.Name("PandoraDidLoadStationsNotification")
}

NotificationCenter.default.post(name: .pandoraDidLoadStations, object: nil)
```

### Implementation Steps

#### Step 8.1: Create NotificationNames.swift

Location: `Sources/Swift/Utilities/NotificationNames.swift`

```swift
//
//  NotificationNames.swift
//  Hermes
//
//  Type-safe notification name constants
//

import Foundation

extension Notification.Name {
    // MARK: - Pandora API
    static let pandoraDidAuthenticate = Notification.Name("PandoraDidAuthenticateNotification")
    static let pandoraDidLoadStations = Notification.Name("PandoraDidLoadStationsNotification")
    static let pandoraDidLoadStationInfo = Notification.Name("PandoraDidLoadStationInfoNotification")
    static let pandoraDidSearch = Notification.Name("PandoraDidLoadSearchResultsNotification")
    static let pandoraDidLoadGenreStations = Notification.Name("PandoraDidLoadGenreStationsNotification")
    static let pandoraDidCreateStation = Notification.Name("PandoraDidCreateStationNotification")
    static let pandoraDidRenameStation = Notification.Name("PandoraDidRenameStationNotification")
    static let pandoraDidDeleteStation = Notification.Name("PandoraDidDeleteStationNotification")
    static let pandoraDidAddSeed = Notification.Name("PandoraDidAddSeedNotification")
    static let pandoraDidDeleteSeed = Notification.Name("PandoraDidDeleteSeedNotification")
    static let pandoraDidDeleteFeedback = Notification.Name("PandoraDidDeleteFeedbackNotification")
    static let pandoraDidError = Notification.Name("PandoraDidErrorNotification")
    
    // MARK: - Playback
    static let playbackSongDidChange = Notification.Name("PlaybackSongDidChangeNotification")
    static let playbackStateDidChange = Notification.Name("PlaybackStateDidChangeNotification")
    static let playbackProgressDidChange = Notification.Name("PlaybackProgressDidChangeNotification")
    static let playbackArtDidLoad = Notification.Name("PlaybackArtDidLoadNotification")
    static let playbackControllerReady = Notification.Name("PlaybackControllerReady")
    
    // MARK: - Legacy (from Objective-C)
    static let stationDidPlaySong = Notification.Name("StationDidPlaySongNotification")
    static let audioStreamStatusChanged = Notification.Name("ASStatusChangedNotification")
    
    // MARK: - Preferences
    static let preferenceAlwaysOnTopChanged = Notification.Name("PreferenceAlwaysOnTopChangedNotification")
    static let preferenceMediaKeysChanged = Notification.Name("PreferenceMediaKeysChangedNotification")
    static let preferenceDockIconChanged = Notification.Name("PreferenceDockIconChangedNotification")
    static let preferenceStatusBarChanged = Notification.Name("PreferenceStatusBarChangedNotification")
    
    // MARK: - System
    static let screensaverDidStart = Notification.Name("com.apple.screensaver.didstart")
    static let screensaverDidStop = Notification.Name("com.apple.screensaver.didstop")
    static let screenIsLocked = Notification.Name("com.apple.screenIsLocked")
    static let screenIsUnlocked = Notification.Name("com.apple.screenIsUnlocked")
}
```

#### Step 8.2: Update All Files to Use Type-Safe Names

This is a find-and-replace operation across all Swift files:

**Find:** `Notification.Name("PandoraDidLoadStationsNotification")`
**Replace:** `.pandoraDidLoadStations`

Repeat for all notification names. The compiler will catch any you miss.

**Files to update:**

- All ViewModels (PlayerViewModel, StationsViewModel, etc.)
- SettingsManager.swift
- MinimalAppDelegate.swift
- NotificationManager.swift
- AppState.swift

---

## TASK 9: Remove MinimalAppDelegate Inheritance from NSObject

**Priority:** LOW
**Complexity:** Low
**Modifies:** `MinimalAppDelegate.swift`

### Purpose

MinimalAppDelegate doesn't need to inherit from NSObject if we're not using selectors.

### Current Problem

```swift
class MinimalAppDelegate: NSObject, NSApplicationDelegate {
```

### Modern Solution

After completing Task 2 (removing selector-based observers), we can remove NSObject:

```swift
class MinimalAppDelegate: NSApplicationDelegate {
```

### Implementation Steps

#### Step 9.1: Verify No Selector Usage

Ensure Task 2 is complete and no `@objc` methods are called via selectors.

#### Step 9.2: Remove NSObject Inheritance

Modify `Sources/Swift/MinimalAppDelegate.swift`:

```swift
// Change from:
class MinimalAppDelegate: NSObject, NSApplicationDelegate {

// To:
class MinimalAppDelegate: NSApplicationDelegate {
```

#### Step 9.3: Test

Build and run to ensure everything still works.

---

## TASK 10: Leverage macOS Tahoe-Specific Features

**Priority:** MEDIUM
**Complexity:** Medium
**Creates:** Various enhancements
**Modifies:** Multiple views and view models

### Purpose

Take advantage of macOS Tahoe (26.0) exclusive features that weren't available in older versions.

### Tahoe-Specific Enhancements

#### Enhancement 10.1: Use Swift 6 Strict Concurrency

macOS Tahoe ships with Swift 6, enabling strict concurrency checking.

Add to all Swift files:

```swift
// At the top of each file
import SwiftUI

// Enable strict concurrency
#if swift(>=6.0)
// Already enabled by default in Swift 6
#endif
```

Ensure all `@MainActor` annotations are correct and no data races exist.

#### Enhancement 10.2: Use Modern SwiftUI Navigation

Replace any remaining navigation patterns with SwiftUI's latest navigation APIs.

```swift
// Use NavigationStack instead of NavigationView (deprecated)
NavigationStack {
    // Content
}

// Use navigationDestination for type-safe navigation
.navigationDestination(for: Station.self) { station in
    StationDetailView(station: station)
}
```

#### Enhancement 10.3: Use @Observable Instead of ObservableObject

Swift 5.9+ (included in Tahoe) introduces `@Observable` macro which is more efficient:

```swift
// OLD (ObservableObject):
@MainActor
final class MyViewModel: ObservableObject {
    @Published var value: String = ""
}

// NEW (@Observable):
@MainActor
@Observable
final class MyViewModel {
    var value: String = ""  // No @Published needed
}

// In views:
// OLD:
@ObservedObject var viewModel: MyViewModel

// NEW:
@State var viewModel = MyViewModel()
// Or for passed-in:
var viewModel: MyViewModel  // Just a regular property
```

#### Enhancement 10.4: Use Swift Testing Framework

Replace XCTest with Swift Testing (available in Tahoe):

```swift
import Testing

@Test("Station creation works")
func testStationCreation() async throws {
    let viewModel = NewStationViewModel(pandora: mockPandora)
    await viewModel.createStation(from: mockResult)
    #expect(viewModel.isCreating == false)
}
```

#### Enhancement 10.5: Use Typed Throws

Swift 6 supports typed throws for better error handling:

```swift
// OLD:
func fetchData() throws -> Data {
    // ...
}

// NEW:
enum FetchError: Error {
    case networkError
    case invalidData
}

func fetchData() throws(FetchError) -> Data {
    // ...
}
```

#### Enhancement 10.6: Remove All Availability Checks

Since we target Tahoe exclusively, remove all `@available` checks:

```swift
// DELETE these patterns:
if #available(macOS 13.0, *) {
    // Use modern API
} else {
    // Fallback
}

// Just use the modern API directly
```

#### Enhancement 10.7: Use SwiftUI's Built-in Status Bar Support

macOS Tahoe has improved MenuBarExtra:

```swift
// In HermesApp.swift, add:
MenuBarExtra("Hermes", systemImage: "music.note") {
    Button("Play/Pause") {
        appState.playerViewModel.playPause()
    }
    // ... rest of menu
}
.menuBarExtraStyle(.window)  // Or .menu
```

This can replace the custom NSStatusItem implementation in SettingsManager.

---

## Appendix A: Modernization Checklist

After completing all tasks, verify:

### Code Quality

- [ ] No direct `NSWorkspace.shared.open()` calls (use environment or service)
- [ ] No selector-based `addObserver` calls (use Combine)
- [ ] No unnecessary `@objc` annotations
- [ ] No direct `UserDefaults.standard` access (use `@AppStorage`)
- [ ] No `DispatchQueue.main.asyncAfter` (use `Task.sleep`)
- [ ] No scattered window manipulation (use WindowManager)
- [ ] Type-safe notification names throughout

### Build & Test

- [ ] `make clean && make` succeeds
- [ ] No new warnings
- [ ] All features work as before
- [ ] Settings apply correctly
- [ ] Window management works
- [ ] Notifications work
- [ ] External links open

### Performance

- [ ] No performance regressions
- [ ] Image caching works
- [ ] No memory leaks from Combine subscriptions

---

## Appendix B: Before & After Comparison

### URL Opening

**Before:**

```swift
NSWorkspace.shared.open(url)
```

**After:**

```swift
@Environment(\.openURL) private var openURL
openURL(url)
```

### Notification Observers

**Before:**

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleNotification(_:)),
    name: Notification.Name("SomeNotification"),
    object: nil
)

@objc private func handleNotification(_ notification: Notification) {
    // Handle
}
```

**After:**

```swift
NotificationCenter.default.publisher(for: .someNotification)
    .sink { [weak self] notification in
        self?.handleNotification(notification)
    }
    .store(in: &cancellables)

private func handleNotification(_ notification: Notification) {
    // Handle
}
```

### UserDefaults Access

**Before:**

```swift
let value = UserDefaults.standard.bool(forKey: "someKey")
UserDefaults.standard.set(newValue, forKey: "someKey")
```

**After:**

```swift
@AppStorage("someKey") private var value = false
// Just use value directly, changes are automatic
```

### Async Delays

**Before:**

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    doSomething()
}
```

**After:**

```swift
Task { @MainActor in
    try? await Task.sleep(nanoseconds: 500_000_000)
    doSomething()
}
```

### Window Management

**Before:**

```swift
for window in NSApp.windows where window.isVisible && !window.isSheet {
    window.level = .floating
}
```

**After:**

```swift
WindowManager.shared.setAlwaysOnTop(true)
```

---

## Appendix C: Common Patterns Reference

### Creating a Service/Manager Class

```swift
import Foundation

@MainActor
final class MyManager {
    static let shared = MyManager()
    
    private init() {
        setupObservers()
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: .someNotification)
            .sink { [weak self] _ in
                self?.handleNotification()
            }
            .store(in: &cancellables)
    }
    
    func doSomething() {
        // Implementation
    }
}
```

### Using @AppStorage in Non-ObservableObject Classes

```swift
// @AppStorage requires the class to be @MainActor or ObservableObject
@MainActor
final class MyService {
    @AppStorage("myKey") private var myValue = false
    
    func doSomething() {
        if myValue {
            // Use the value
        }
    }
}
```

### Type-Safe Notification Publishing

```swift
// Define the name
extension Notification.Name {
    static let myCustomEvent = Notification.Name("MyCustomEventNotification")
}

// Post
NotificationCenter.default.post(name: .myCustomEvent, object: nil)

// Observe
NotificationCenter.default.publisher(for: .myCustomEvent)
    .sink { notification in
        // Handle
    }
    .store(in: &cancellables)
```

### Dependency Injection for Testing

```swift
// ViewModel with injected dependencies
@MainActor
final class MyViewModel: ObservableObject {
    private let openURL: (URL) -> Void
    private let pandora: Pandora
    
    init(
        pandora: Pandora,
        openURL: @escaping (URL) -> Void = { url in
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    ) {
        self.pandora = pandora
        self.openURL = openURL
    }
    
    func openExternalLink() {
        if let url = URL(string: "https://example.com") {
            openURL(url)
        }
    }
}

// In tests, inject a mock:
let viewModel = MyViewModel(pandora: mockPandora) { url in
    print("Would open: \(url)")
}
```

---

## Appendix D: Migration Priority Summary

### High Priority (Do First)

1. **Environment-Based URL Opening** - Affects multiple files, foundational
2. **Combine-Based Notification Observers** - Removes @objc requirement
3. **Remove Unnecessary @objc Methods** - Cleanup after Task 2

### Medium Priority (Do Second)

1. **Replace UserDefaults with @AppStorage** - Better SwiftUI integration
2. **Replace DispatchQueue with Async/Await** - Modern concurrency

### Low Priority (Do Last)

1. **Window Management Service** - Nice to have, not critical
2. **Modernize Image Handling** - Performance optimization
3. **Type-Safe Notification Names** - Code quality improvement
4. **Remove NSObject Inheritance** - Final cleanup

---

## Summary

These tasks modernize the remaining AppKit/NS-based constructs in Hermes:

1. **URL Opening** → SwiftUI Environment
2. **Notification Observers** → Combine Publishers
3. **@objc Methods** → Pure Swift
4. **UserDefaults** → @AppStorage
5. **DispatchQueue** → Async/Await
6. **Window Management** → Dedicated Service
7. **Image Handling** → Simplified & Cached
8. **Notification Names** → Type-Safe Constants
9. **NSObject** → Pure Swift Protocol Conformance

After completing these tasks, Hermes will use modern Swift/SwiftUI patterns throughout, with AppKit usage limited to only what's absolutely necessary for the platform.
