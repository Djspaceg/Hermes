# Design Document: Swift Frontend Migration

## Overview

This design describes the proper migration to a 100% Swift/SwiftUI frontend while keeping the Objective-C business logic layer. The key principle is **clean separation**: Swift owns ALL UI concerns, Objective-C owns ALL business logic. Communication flows through a bridging header and notifications.

The migration removes all XIB dependencies and uses SwiftUI's native lifecycle with `@main` and `WindowGroup`.

## Architecture

### Target Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Swift Frontend Layer                      │
├─────────────────────────────────────────────────────────────┤
│  @main HermesSwiftUIApp                                     │
│    ├── WindowGroup (creates window)                         │
│    ├── Commands (menu bar)                                  │
│    └── Settings (preferences window)                        │
│                                                              │
│  ContentView (root view)                                    │
│    ├── LoginView                                            │
│    ├── LoadingView                                          │
│    ├── PlayerView + SidebarView                            │
│    └── ErrorView                                            │
│                                                              │
│  AppState (central state manager)                           │
│    ├── @Published currentView                               │
│    ├── @Published isSidebarVisible                          │
│    ├── LoginViewModel                                       │
│    ├── PlayerViewModel                                      │
│    ├── StationsViewModel                                    │
│    └── HistoryViewModel                                     │
└─────────────────────────────────────────────────────────────┘
                            ↕ (Bridging Header + Notifications)
┌─────────────────────────────────────────────────────────────┐
│              Objective-C Business Logic Layer                │
├─────────────────────────────────────────────────────────────┤
│  MinimalAppDelegate (via @NSApplicationDelegateAdaptor)     │
│    └── Notification observers only                          │
│                                                              │
│  Pandora API                                                │
│    ├── authenticate()                                       │
│    ├── fetchStations()                                      │
│    └── API communication                                    │
│                                                              │
│  AudioStreamer                                              │
│    ├── Audio playback                                       │
│    └── Stream management                                    │
│                                                              │
│  PlaybackController                                         │
│    ├── playStation()                                        │
│    ├── playpause()                                          │
│    └── Playback control                                     │
│                                                              │
│  Networking, Crypto, Keychain                               │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### HermesSwiftUIApp (Main Entry Point)

```swift
@main
struct HermesSwiftUIApp: App {
    @StateObject private var appState = AppState.shared
    @NSApplicationDelegateAdaptor(MinimalAppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            // Pandora menu commands
            // Keyboard shortcuts
        }
        
        Settings {
            PreferencesView()
        }
    }
}
```

### MinimalAppDelegate (New)

```swift
/// Minimal AppDelegate for Objective-C integration only
/// Does NOT manage UI - only handles notifications and business logic callbacks
class MinimalAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up notification observers for Pandora API callbacks
        setupNotificationObservers()
        
        // Register default preferences
        registerDefaults()
        
        // Initialize media key handler if needed
        setupMediaKeys()
    }
    
    private func setupNotificationObservers() {
        // Observe Pandora API notifications
        // These will be forwarded to Swift via NotificationCenter publishers
    }
    
    private func registerDefaults() {
        // Register UserDefaults
    }
    
    private func setupMediaKeys() {
        // Initialize SPMediaKeyTap if enabled
    }
}
```

### SidebarView (Proper Structure)

```swift
struct SidebarView: View {
    @ObservedObject var stationsViewModel: StationsViewModel
    @ObservedObject var historyViewModel: HistoryViewModel
    
    @State private var selectedView: SidebarSelection = .stations
    @State private var selectedStation: StationModel?
    @State private var sortOrder: StationsViewModel.SortOrder = .dateCreated
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Header: Stations/History navigation
            navigationHeader
            
            // Conditional Sort Controls (Stations only)
            if selectedView == .stations {
                sortControls
            }
            
            // Scrollable Content
            contentArea
            
            // Conditional Footer
            if selectedView == .stations {
                stationsFooter
            } else {
                historyFooter
            }
        }
    }
    
    private var navigationHeader: some View {
        HStack(spacing: 0) {
            Button("Stations") { selectedView = .stations }
                .buttonStyle(NavigationHeaderButtonStyle(isSelected: selectedView == .stations))
            Button("History") { selectedView = .history }
                .buttonStyle(NavigationHeaderButtonStyle(isSelected: selectedView == .history))
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
    
    private var sortControls: some View {
        HStack(spacing: 0) {
            Button("Name") { sortOrder = .name }
                .buttonStyle(SortButtonStyle(isSelected: sortOrder == .name))
            Button("Date") { sortOrder = .dateCreated }
                .buttonStyle(SortButtonStyle(isSelected: sortOrder == .dateCreated))
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }
    
    @ViewBuilder
    private var contentArea: some View {
        switch selectedView {
        case .stations:
            StationsListView(
                viewModel: stationsViewModel,
                selectedStation: $selectedStation,
                sortOrder: $sortOrder
            )
        case .history:
            HistoryListView(
                viewModel: historyViewModel,
                selectedItem: $historyViewModel.selectedItem
            )
        }
    }
    
    private var stationsFooter: some View {
        HStack(spacing: 12) {
            Button("Play") {
                if let station = selectedStation {
                    stationsViewModel.playStation(station)
                }
            }
            .disabled(selectedStation == nil)
            
            Button("Add") {
                stationsViewModel.showAddStation()
            }
            
            Button("Edit") {
                if let station = selectedStation {
                    stationsViewModel.renameStation(station)
                }
            }
            .disabled(selectedStation == nil)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var historyFooter: some View {
        HStack(spacing: 4) {
            Button(action: { historyViewModel.openSongOnPandora() }) {
                Image(systemName: "music.note").frame(width: 32, height: 28)
            }
            .disabled(historyViewModel.selectedItem == nil)
            .help("Song on Pandora")
            
            Button(action: { historyViewModel.openArtistOnPandora() }) {
                Image(systemName: "person").frame(width: 32, height: 28)
            }
            .disabled(historyViewModel.selectedItem == nil)
            .help("Artist on Pandora")
            
            Button(action: { historyViewModel.openAlbumOnPandora() }) {
                Image(systemName: "square.stack").frame(width: 32, height: 28)
            }
            .disabled(historyViewModel.selectedItem == nil)
            .help("Album on Pandora")
            
            Button(action: { historyViewModel.showLyrics() }) {
                Image(systemName: "text.quote").frame(width: 32, height: 28)
            }
            .disabled(historyViewModel.selectedItem == nil)
            .help("Lyrics")
            
            Spacer()
            
            Button(action: { historyViewModel.likeSelected() }) {
                Image(systemName: "hand.thumbsup").frame(width: 32, height: 28)
            }
            .disabled(historyViewModel.selectedItem == nil)
            .help("Like")
            
            Button(action: { historyViewModel.dislikeSelected() }) {
                Image(systemName: "hand.thumbsdown").frame(width: 32, height: 28)
            }
            .disabled(historyViewModel.selectedItem == nil)
            .help("Dislike")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

enum SidebarSelection {
    case stations
    case history
}
```

### PlayerView (Responsive)

```swift
struct PlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                if let song = viewModel.currentSong {
                    // Album art with responsive sizing
                    albumArtView(song: song, geometry: geometry)
                    
                    // Song info
                    songInfoView(song: song)
                    
                    // Playback controls
                    playbackControlsView
                    
                    // Progress slider
                    progressSliderView
                    
                    // Volume control
                    volumeControlView
                } else {
                    emptyStateView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func albumArtView(song: SongModel, geometry: GeometryProxy) -> some View {
        let availableWidth = geometry.size.width - 80
        let availableHeight = geometry.size.height * 0.5
        let size = min(availableWidth, availableHeight, 600)
        
        return AsyncImage(url: song.artworkURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure, .empty:
                placeholderArtwork
            @unknown default:
                placeholderArtwork
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}
```

## Data Models

All existing Swift models (StationModel, SongModel) remain unchanged.

## Migration Strategy

### Phase 1: Create Minimal AppDelegate

- Create new MinimalAppDelegate in Swift
- Move only notification setup from HermesAppDelegate
- No UI-related code

### Phase 2: Update SwiftUI App Entry Point

- Add @main to HermesSwiftUIApp
- Add @NSApplicationDelegateAdaptor(MinimalAppDelegate.self)
- Remove main.m from build
- Remove NSMainNibFile and NSPrincipalClass from Info.plist

### Phase 3: Remove XIB Dependencies

- Remove MainMenu.xib from Resources build phase
- Remove all IBOutlet properties from old HermesAppDelegate
- Disable all setCurrentView calls
- Disable all drawer/window management code

### Phase 4: Implement Proper Sidebar

- Create SidebarView with structured layout
- Create StationsListView and HistoryListView
- Update ContentView to use new SidebarView
- Remove old drawer-based views

### Phase 5: Fix Album Art Scaling

- Add GeometryReader to PlayerView
- Implement responsive sizing logic
- Test at various window sizes

### Phase 6: Clean Up

- Remove old HermesAppDelegate file
- Remove old UI controller files (AuthController, etc.)
- Remove XIB files
- Remove legacy code

## Testing Strategy

### Manual Testing

1. App launches and shows SwiftUI window
2. Login flow works
3. Sidebar navigation works
4. Album art scales properly
5. All playback controls work
6. Preferences persist
7. Keyboard shortcuts work
8. Media keys work

### Verification

1. No XIB files loaded
2. No IBOutlet warnings
3. Clean build with no errors
4. App works at various window sizes
5. Dark mode works correctly

## Error Handling

Existing error handling remains the same - errors are displayed via SwiftUI ErrorView.

## Correctness Properties

### Property 1: SwiftUI Manages All Windows

*For any* app launch, SwiftUI WindowGroup SHALL create the window, and no XIB SHALL be loaded.

**Validates: Requirements 1.1, 1.4, 2.3**

### Property 2: AppDelegate Has No UI State

*For any* AppDelegate method call, it SHALL NOT modify UI state or manage windows.

**Validates: Requirements 3.1, 3.2, 3.4, 5.2**

### Property 3: Album Art Scales Responsively

*For any* window size, album art SHALL scale proportionally within constraints.

**Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5**

### Property 4: Sidebar Structure Always Consistent

*For any* sidebar state, the header SHALL always be visible, and footer SHALL match the selected view.

**Validates: Requirements 6.1, 6.2, 6.3, 6.4**
