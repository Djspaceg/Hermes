# XIB to SwiftUI Migration Plan

## Overview

This document provides step-by-step instructions for migrating Hermes from XIB/AppKit to pure SwiftUI. Each task is self-contained and can be executed independently.

**Target:** macOS Tahoe (26.0) exclusively
**Architecture:** SwiftUI UI layer + Objective-C business logic layer
**Communication:** NotificationCenter for cross-layer messaging

---

## Current State

### Already Migrated (DO NOT MODIFY)

- `Sources/Swift/HermesApp.swift` - Main app entry point
- `Sources/Swift/Views/ContentView.swift` - Root view router
- `Sources/Swift/Views/LoginView.swift` - Authentication UI
- `Sources/Swift/Views/PlayerView.swift` - Playback interface
- `Sources/Swift/Views/SidebarView.swift` - Navigation sidebar
- `Sources/Swift/Views/StationsListView.swift` - Stations list
- `Sources/Swift/Views/HistoryListView.swift` - History list
- `Sources/Swift/Views/PreferencesView.swift` - Settings (3 tabs)
- `Sources/Swift/Views/ErrorView.swift` - Error display
- `Sources/Swift/Utilities/SettingsManager.swift` - Settings + status bar
- `Sources/Swift/MinimalAppDelegate.swift` - Obj-C bridge
- `Sources/Controllers/PlaybackController.h/m` - Playback (XIB-free)

### Objective-C Business Logic (PRESERVE - DO NOT REWRITE)

- `Sources/Pandora/` - Pandora API client
- `Sources/AudioStreamer/` - Audio streaming
- `Sources/Integration/Keychain.h/m` - Keychain access
- `Sources/Integration/Scrobbler.h/m` - Last.fm integration
- `Sources/Integration/AppleScript.h/m` - AppleScript support
- `ImportedSources/blowfish/` - Encryption
- `ImportedSources/FMEngine/` - Last.fm API
- `ImportedSources/SPMediaKeyTap/` - Media keys

---

## Migration Tasks

Execute these tasks in order. Each task creates new SwiftUI files and may modify existing ones.

---

## TASK 1: New Station Creation Sheet

**Priority:** HIGH
**Complexity:** Medium
**Creates:** `NewStationView.swift`, `NewStationViewModel.swift`
**Modifies:** `HermesApp.swift`, `StationsViewModel.swift`

### Purpose

Allow users to create new Pandora stations by searching for artists/songs or browsing genres.

### Reference Files to Read

1. `Sources/Controllers/StationsController.h` - See IBOutlets for search UI elements
2. `Sources/Controllers/StationsController.m` - See `search:`, `createStation:`, `createStationGenre:` methods
3. `Sources/Pandora/Pandora.h` - See `search:` and `createStation:` methods

### Implementation Steps

#### Step 1.1: Create NewStationViewModel.swift

Location: `Sources/Swift/ViewModels/NewStationViewModel.swift`

```swift
import Foundation
import Combine
import Observation

@MainActor
@Observable
final class NewStationViewModel {
    // MARK: - Properties (no @Published needed with @Observable)
    var searchQuery: String = ""
    var searchResults: [SearchResult] = []
    var genres: [GenreCategory] = []
    var isSearching: Bool = false
    var isCreating: Bool = false
    var errorMessage: String?
    var selectedTab: Tab = .search
    
    enum Tab: String, CaseIterable {
        case search = "Search"
        case genres = "Genres"
    }
    
    // MARK: - Dependencies
    private let pandora: Pandora
    private var cancellables = Set<AnyCancellable>()
    
    init(pandora: Pandora) {
        self.pandora = pandora
        setupSearchDebounce()
    }
    
    // MARK: - Search
    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .sink { [weak self] query in
                self?.performSearch(query)
            }
            .store(in: &cancellables)
    }
    
    func performSearch(_ query: String) {
        isSearching = true
        errorMessage = nil
        // Call pandora.search() - see StationsController.m for pattern
        // Post notification or use callback to get results
    }
    
    // MARK: - Station Creation
    func createStation(from result: SearchResult) {
        isCreating = true
        // Call pandora.createStation() with result.musicToken
        // Listen for StationCreatedNotification
    }
    
    func createStation(fromGenre genre: Genre) {
        isCreating = true
        // Call pandora.createStation() with genre.stationToken
    }
    
    // MARK: - Genres
    func loadGenres() {
        // Call pandora.genreStations() if not already loaded
        // Parse into GenreCategory/Genre structure
    }
}

// MARK: - Models
struct SearchResult: Identifiable {
    let id: String
    let musicToken: String
    let name: String
    let artist: String?
    let type: ResultType // artist, song, genre
    
    enum ResultType: String {
        case artist, song, genre
    }
}

struct GenreCategory: Identifiable {
    let id: String
    let name: String
    let genres: [Genre]
}

struct Genre: Identifiable {
    let id: String
    let name: String
    let stationToken: String
}
```

#### Step 1.2: Create NewStationView.swift

Location: `Sources/Swift/Views/NewStationView.swift`

```swift
import SwiftUI

struct NewStationView: View {
    var viewModel: NewStationViewModel  // No @ObservedObject needed with @Observable
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $viewModel.selectedTab) {
                ForEach(NewStationViewModel.Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            // Content based on tab
            switch viewModel.selectedTab {
            case .search:
                searchView
            case .genres:
                genresView
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            viewModel.loadGenres()
        }
    }
    
    private var searchView: some View {
        VStack {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search artists or songs...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding()
            
            // Results list
            List(viewModel.searchResults) { result in
                SearchResultRow(result: result) {
                    viewModel.createStation(from: result)
                }
            }
            .listStyle(.plain)
        }
    }
    
    private var genresView: some View {
        List {
            ForEach(viewModel.genres) { category in
                Section(category.name) {
                    ForEach(category.genres) { genre in
                        Button(genre.name) {
                            viewModel.createStation(fromGenre: genre)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: result.type == .artist ? "person.fill" : "music.note")
                    .foregroundColor(.secondary)
                VStack(alignment: .leading) {
                    Text(result.name)
                    if let artist = result.artist {
                        Text(artist)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .foregroundColor(.accentColor)
            }
        }
        .buttonStyle(.plain)
    }
}
```

#### Step 1.3: Add Sheet Presentation to HermesApp.swift

Modify `Sources/Swift/HermesApp.swift`:

1. Add `@State private var showingNewStation = false` to HermesApp
2. In the `.commands` section, update the "New Station..." button:

```swift
Button("New Station...") {
    showingNewStation = true
}
.keyboardShortcut("n", modifiers: .command)
```

1. Add `.sheet` modifier to ContentView:

```swift
ContentView(appState: appState)
    .sheet(isPresented: $showingNewStation) {
        NewStationView(viewModel: NewStationViewModel(pandora: appState.pandora))
    }
```

#### Step 1.4: Wire Up Pandora API Calls

In `NewStationViewModel.swift`, implement the actual API calls by:

1. Reading `Sources/Pandora/Pandora.h` for method signatures
2. Using NotificationCenter to receive results
3. Key notifications to observe:
   - `PandoraDidSearchNotification` - Search results
   - `PandoraDidLoadGenreStationsNotification` - Genre list
   - `StationCreatedNotification` - Station created successfully

#### Step 1.5: Test

1. Build with `make`
2. Launch app, authenticate
3. Press Cmd+N to open new station sheet
4. Test search functionality
5. Test genre browsing
6. Verify station creation works

---

## TASK 2: Station Editor View

**Priority:** HIGH
**Complexity:** High
**Creates:** `StationEditorView.swift`, `StationEditorViewModel.swift`
**Modifies:** `StationsListView.swift`, `StationsViewModel.swift`

### Purpose

Allow users to edit stations: rename, manage seeds (artists/songs that define the station), and view/delete feedback (likes/dislikes).

### Reference Files to Read

1. `Sources/Controllers/StationController.h` - See all IBOutlets
2. `Sources/Controllers/StationController.m` - See `editStation:`, `renameStation:`, seed methods
3. `Sources/Pandora/Station.h` - Station model with seeds, feedback

### Implementation Steps

#### Step 2.1: Create StationEditorViewModel.swift

Location: `Sources/Swift/ViewModels/StationEditorViewModel.swift`

```swift
import Foundation
import Combine
import Observation

@MainActor
@Observable
final class StationEditorViewModel {
    // MARK: - Properties (no @Published needed with @Observable)
    var stationName: String = ""
    var stationCreated: String = ""
    var stationGenres: String = ""
    var artworkURL: URL?
    
    var seeds: [Seed] = []
    var likes: [FeedbackItem] = []
    var dislikes: [FeedbackItem] = []
    
    var seedSearchQuery: String = ""
    var seedSearchResults: [SeedSearchResult] = []
    var isSearchingSeeds: Bool = false
    
    var isLoading: Bool = false
    var isSaving: Bool = false
    var errorMessage: String?
    
    // MARK: - Private
    private let station: Station
    private let pandora: Pandora
    private var cancellables = Set<AnyCancellable>()
    
    init(station: Station, pandora: Pandora) {
        self.station = station
        self.pandora = pandora
        loadStationDetails()
        setupSeedSearchDebounce()
    }
    
    // MARK: - Load Station Details
    func loadStationDetails() {
        isLoading = true
        stationName = station.name ?? ""
        // Load extended info via pandora.stationInfo()
        // Observe PandoraDidLoadStationInfoNotification
    }
    
    // MARK: - Rename
    func renameStation(to newName: String) {
        isSaving = true
        // Call pandora.renameStation()
        // Observe StationRenamedNotification
    }
    
    // MARK: - Seeds
    private func setupSeedSearchDebounce() {
        $seedSearchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .sink { [weak self] query in
                self?.searchSeeds(query)
            }
            .store(in: &cancellables)
    }
    
    func searchSeeds(_ query: String) {
        isSearchingSeeds = true
        // Call pandora.search() for seed candidates
    }
    
    func addSeed(_ result: SeedSearchResult) {
        // Call pandora.addSeed() with musicToken
        // Observe SeedAddedNotification
    }
    
    func deleteSeed(_ seed: Seed) {
        // Call pandora.deleteSeed()
        // Observe SeedDeletedNotification
    }
    
    // MARK: - Feedback
    func deleteFeedback(_ item: FeedbackItem) {
        // Call pandora.deleteFeedback()
        // Observe FeedbackDeletedNotification
    }
    
    // MARK: - External Links
    func openInPandora() {
        if let url = URL(string: station.url ?? "") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Models
struct Seed: Identifiable {
    let id: String
    let seedId: String
    let name: String
    let artist: String?
    let type: SeedType
    
    enum SeedType: String {
        case artist, song
    }
}

struct SeedSearchResult: Identifiable {
    let id: String
    let musicToken: String
    let name: String
    let artist: String?
    let type: Seed.SeedType
}

struct FeedbackItem: Identifiable {
    let id: String
    let feedbackId: String
    let name: String
    let artist: String
    let isPositive: Bool
}
```

#### Step 2.2: Create StationEditorView.swift

Location: `Sources/Swift/Views/StationEditorView.swift`

```swift
import SwiftUI

struct StationEditorView: View {
    var viewModel: StationEditorViewModel  // No @ObservedObject needed with @Observable
    @Environment(\.dismiss) private var dismiss
    @State private var isEditingName = false
    @State private var editedName = ""
    
    var body: some View {
        HSplitView {
            // Left: Station info and seeds
            VStack(alignment: .leading, spacing: 16) {
                stationInfoSection
                Divider()
                seedsSection
            }
            .frame(minWidth: 300)
            .padding()
            
            // Right: Feedback (likes/dislikes)
            VStack(alignment: .leading, spacing: 16) {
                feedbackSection
            }
            .frame(minWidth: 250)
            .padding()
        }
        .frame(width: 700, height: 500)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
    
    // MARK: - Station Info
    private var stationInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // Artwork
                AsyncImage(url: viewModel.artworkURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 80, height: 80)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Editable name
                    if isEditingName {
                        HStack {
                            TextField("Station Name", text: $editedName)
                                .textFieldStyle(.roundedBorder)
                            Button("Save") {
                                viewModel.renameStation(to: editedName)
                                isEditingName = false
                            }
                            Button("Cancel") {
                                isEditingName = false
                            }
                        }
                    } else {
                        HStack {
                            Text(viewModel.stationName)
                                .font(.title2.bold())
                            Button(action: {
                                editedName = viewModel.stationName
                                isEditingName = true
                            }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Text("Created: \(viewModel.stationCreated)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !viewModel.stationGenres.isEmpty {
                        Text(viewModel.stationGenres)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Button("Open in Pandora") {
                viewModel.openInPandora()
            }
        }
    }
    
    // MARK: - Seeds Section
    private var seedsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Seeds")
                .font(.headline)
            
            // Search to add seeds
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Add artist or song...", text: $viewModel.seedSearchQuery)
                    .textFieldStyle(.plain)
            }
            .padding(6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            
            // Search results (if searching)
            if !viewModel.seedSearchResults.isEmpty {
                List(viewModel.seedSearchResults) { result in
                    HStack {
                        Text(result.name)
                        Spacer()
                        Button(action: { viewModel.addSeed(result) }) {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(height: 100)
            }
            
            // Current seeds
            List {
                ForEach(viewModel.seeds) { seed in
                    HStack {
                        Image(systemName: seed.type == .artist ? "person.fill" : "music.note")
                        VStack(alignment: .leading) {
                            Text(seed.name)
                            if let artist = seed.artist {
                                Text(artist).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button(action: { viewModel.deleteSeed(seed) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Feedback Section
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Feedback")
                .font(.headline)
            
            TabView {
                // Likes tab
                List {
                    ForEach(viewModel.likes) { item in
                        FeedbackRow(item: item) {
                            viewModel.deleteFeedback(item)
                        }
                    }
                }
                .tabItem { Label("Likes", systemImage: "hand.thumbsup") }
                
                // Dislikes tab
                List {
                    ForEach(viewModel.dislikes) { item in
                        FeedbackRow(item: item) {
                            viewModel.deleteFeedback(item)
                        }
                    }
                }
                .tabItem { Label("Dislikes", systemImage: "hand.thumbsdown") }
            }
        }
    }
}

struct FeedbackRow: View {
    let item: FeedbackItem
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.name)
                Text(item.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
    }
}
```

#### Step 2.3: Add Edit Action to StationsListView

Modify `Sources/Swift/Views/StationsListView.swift`:

Add to the context menu:

```swift
.contextMenu {
    Button("Play") {
        viewModel.playStation(station)
    }
    Button("Edit...") {
        viewModel.editStation(station)  // Add this
    }
    Button("Rename") {
        viewModel.renameStation(station)
    }
    Button("Delete", role: .destructive) {
        viewModel.deleteStation(station)
    }
}
```

#### Step 2.4: Add Sheet State to StationsViewModel

Modify `Sources/Swift/ViewModels/StationsViewModel.swift`:

```swift
@Published var stationToEdit: Station?

func editStation(_ station: StationModel) {
    // Get the actual Station object and set stationToEdit
    // This will trigger a sheet presentation
}
```

#### Step 2.5: Present Sheet from SidebarView or ContentView

Add sheet presentation for station editing.

---

## TASK 3: History External Links

**Priority:** MEDIUM
**Complexity:** Low
**Modifies:** `HistoryListView.swift`, `HistoryViewModel.swift`

### Purpose

Add context menu actions to open Pandora pages for artist/song/album and show lyrics.

### Reference Files to Read

1. `Sources/Controllers/HistoryController.h` - See IBActions
2. `Sources/Controllers/HistoryController.m` - See `gotoArtist:`, `gotoSong:`, `gotoAlbum:`, `showLyrics:`
3. `Sources/Pandora/Song.h` - See URL properties

### Implementation Steps

#### Step 3.1: Add URL Methods to HistoryViewModel

Modify `Sources/Swift/ViewModels/HistoryViewModel.swift`:

```swift
// MARK: - External Links

func openArtistPage(_ song: SongModel) {
    guard let urlString = song.artistURL, let url = URL(string: urlString) else { return }
    NSWorkspace.shared.open(url)
}

func openSongPage(_ song: SongModel) {
    guard let urlString = song.songURL, let url = URL(string: urlString) else { return }
    NSWorkspace.shared.open(url)
}

func openAlbumPage(_ song: SongModel) {
    guard let urlString = song.albumURL, let url = URL(string: urlString) else { return }
    NSWorkspace.shared.open(url)
}

func openLyrics(_ song: SongModel) {
    // Search for lyrics using artist + title
    let query = "\(song.artist) \(song.title) lyrics".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    if let url = URL(string: "https://www.google.com/search?q=\(query)") {
        NSWorkspace.shared.open(url)
    }
}
```

#### Step 3.2: Update SongModel

Ensure `Sources/Swift/Models/SongModel.swift` has URL properties:

```swift
struct SongModel: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let artworkURL: URL?
    let rating: Int  // 0 = none, 1 = liked, -1 = disliked
    
    // Add these URL properties
    let artistURL: String?
    let songURL: String?
    let albumURL: String?
}
```

#### Step 3.3: Update HistoryListView Context Menu

Modify `Sources/Swift/Views/HistoryListView.swift`:

```swift
.contextMenu {
    Button("Like") {
        viewModel.likeSong(song)
    }
    Button("Dislike", role: .destructive) {
        viewModel.dislikeSong(song)
    }
    
    Divider()
    
    Button("Open Artist in Pandora") {
        viewModel.openArtistPage(song)
    }
    Button("Open Song in Pandora") {
        viewModel.openSongPage(song)
    }
    Button("Open Album in Pandora") {
        viewModel.openAlbumPage(song)
    }
    
    Divider()
    
    Button("Search Lyrics...") {
        viewModel.openLyrics(song)
    }
}
```

---

## TASK 4: Help Menu Items

**Priority:** MEDIUM
**Complexity:** Low
**Modifies:** `HermesApp.swift`

### Purpose

Add Help menu items for changelog, GitHub, issue reporting, and homepage.

### Reference Files to Read

1. `Sources/HermesAppDelegate.h` - See IBActions for help items
2. `Sources/HermesAppDelegate.m` - See URL implementations

### Implementation Steps

#### Step 4.1: Add Help Commands to HermesApp.swift

Modify `Sources/Swift/HermesApp.swift`, add to `.commands`:

```swift
// Add to HermesApp struct:
@Environment(\.openURL) private var openURL

// Then in commands:
CommandGroup(replacing: .help) {
    Button("Hermes Help") {
        if let url = URL(string: "https://github.com/HermesApp/Hermes/wiki") {
            openURL(url)
        }
    }
    
    Divider()
    
    Button("View Changelog") {
        if let url = URL(string: "https://github.com/HermesApp/Hermes/blob/master/CHANGELOG.md") {
            openURL(url)
        }
    }
    
    Button("Hermes on GitHub") {
        if let url = URL(string: "https://github.com/HermesApp/Hermes") {
            openURL(url)
        }
    }
    
    Button("Report an Issue...") {
        if let url = URL(string: "https://github.com/HermesApp/Hermes/issues/new") {
            openURL(url)
        }
    }
    
    Divider()
    
    Button("Hermes Homepage") {
        if let url = URL(string: "https://hermesapp.org") {
            openURL(url)
        }
    }
}
```

---

## TASK 5: Station Deletion Confirmation

**Priority:** MEDIUM
**Complexity:** Low
**Modifies:** `StationsViewModel.swift`, `StationsListView.swift`

### Purpose

Add confirmation dialog before deleting a station.

### Implementation Steps

#### Step 5.1: Add Confirmation State to StationsViewModel

Modify `Sources/Swift/ViewModels/StationsViewModel.swift`:

```swift
// With @Observable, no @Published needed:
var stationToDelete: StationModel?
var showDeleteConfirmation = false

func confirmDeleteStation(_ station: StationModel) {
    stationToDelete = station
    showDeleteConfirmation = true
}

func performDeleteStation() {
    guard let station = stationToDelete else { return }
    // Call pandora.deleteStation()
    stationToDelete = nil
}
```

#### Step 5.2: Add Confirmation Dialog to StationsListView

Modify `Sources/Swift/Views/StationsListView.swift`:

```swift
// Update context menu
.contextMenu {
    Button("Delete", role: .destructive) {
        viewModel.confirmDeleteStation(station)  // Changed from deleteStation
    }
}

// Add confirmation dialog
.confirmationDialog(
    "Delete Station",
    isPresented: $viewModel.showDeleteConfirmation,
    presenting: viewModel.stationToDelete
) { station in
    Button("Delete \"\(station.name)\"", role: .destructive) {
        viewModel.performDeleteStation()
    }
    Button("Cancel", role: .cancel) {}
} message: { station in
    Text("Are you sure you want to delete \"\(station.name)\"? This cannot be undone.")
}
```

---

## TASK 6: Station Rename Dialog

**Priority:** MEDIUM
**Complexity:** Low
**Modifies:** `StationsViewModel.swift`, `StationsListView.swift` or `SidebarView.swift`

### Purpose

Add inline rename or dialog for renaming stations.

### Implementation Steps

#### Step 6.1: Add Rename State to StationsViewModel

```swift
// With @Observable, no @Published needed:
var stationToRename: StationModel?
var showRenameDialog = false
var newStationName = ""

func startRenameStation(_ station: StationModel) {
    stationToRename = station
    newStationName = station.name
    showRenameDialog = true
}

func performRenameStation() {
    guard let station = stationToRename, !newStationName.isEmpty else { return }
    // Call pandora.renameStation()
    stationToRename = nil
    newStationName = ""
}
```

#### Step 6.2: Add Rename Sheet

Use `.sheet` or `.alert` with TextField:

```swift
.sheet(isPresented: $viewModel.showRenameDialog) {
    VStack(spacing: 16) {
        Text("Rename Station")
            .font(.headline)
        
        TextField("Station Name", text: $viewModel.newStationName)
            .textFieldStyle(.roundedBorder)
            .frame(width: 250)
        
        HStack {
            Button("Cancel") {
                viewModel.showRenameDialog = false
            }
            Button("Rename") {
                viewModel.performRenameStation()
                viewModel.showRenameDialog = false
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.newStationName.isEmpty)
        }
    }
    .padding()
    .frame(width: 300)
}
```

---

## TASK 7: Refresh Stations

**Priority:** LOW
**Complexity:** Low
**Modifies:** `StationsViewModel.swift`, `SidebarView.swift`

### Purpose

Add ability to manually refresh the stations list.

### Implementation Steps

#### Step 7.1: Add Refresh Method (if not exists)

In `Sources/Swift/ViewModels/StationsViewModel.swift`:

```swift
// With @Observable, no @Published needed:
var isRefreshing = false

func refreshStations() async {
    isRefreshing = true
    // Call pandora.fetchStations()
    // Listen for PandoraDidLoadStationsNotification
    isRefreshing = false
}
```

#### Step 7.2: Add Refresh Button to SidebarView

Modify `Sources/Swift/Views/SidebarView.swift`:

Add a toolbar button or context menu item:

```swift
.toolbar {
    ToolbarItem {
        Button(action: {
            Task { await stationsViewModel.refreshStations() }
        }) {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        .disabled(stationsViewModel.isRefreshing)
    }
}
```

Or use `.refreshable` modifier on the List (macOS 12+, fully optimized in Tahoe):

```swift
List { ... }
    .refreshable {
        await stationsViewModel.refreshStations()
    }
```

---

## TASK 8: Clean Up Legacy Files

**Priority:** LOW (Do LAST after all features work)
**Complexity:** Low

### Purpose

Remove all legacy XIB-dependent files after migration is complete.

### Prerequisites

- ALL previous tasks completed
- App fully tested with all features working
- No remaining references to deleted files

### Files to Delete

#### Controllers (after their functionality is migrated)

```
Sources/HermesAppDelegate.h
Sources/HermesAppDelegate.m
Sources/Controllers/AuthController.h
Sources/Controllers/AuthController.m
Sources/Controllers/PreferencesController.h
Sources/Controllers/PreferencesController.m
Sources/Controllers/StationsController.h
Sources/Controllers/StationsController.m
Sources/Controllers/HistoryController.h
Sources/Controllers/HistoryController.m
Sources/Controllers/StationController.h
Sources/Controllers/StationController.m
Sources/Controllers/MainSplitViewController.h
Sources/Controllers/MainSplitViewController.m
```

#### Legacy Views

```
Sources/Views/HermesMainWindow.h
Sources/Views/HermesMainWindow.m
Sources/Views/HermesBackgroundView.h
Sources/Views/HermesBackgroundView.m
Sources/Views/HermesVolumeSliderCell.h
Sources/Views/HermesVolumeSliderCell.m
Sources/Views/MusicProgressSliderCell.h
Sources/Views/MusicProgressSliderCell.m
Sources/Views/StationsSidebarView.h
Sources/Views/StationsSidebarView.m
Sources/Views/StationsTableView.h
Sources/Views/StationsTableView.m
Sources/Views/HistoryView.h
Sources/Views/HistoryView.m
Sources/Views/HistoryCollectionView.h
Sources/Views/HistoryCollectionView.m
Sources/Views/LabelHoverShowField.h
Sources/Views/LabelHoverShowField.m
Sources/Views/LabelHoverShowFieldCell.h
Sources/Views/LabelHoverShowFieldCell.m
```

#### XIB Files

```
Resources/English.lproj/MainMenu.xib
```

### Steps

1. **Verify all features work** - Test every feature manually
2. **Remove files from Xcode project** - Open Hermes.xcodeproj, select files, delete (move to trash)
3. **Update bridging header** - Remove any imports of deleted headers from `Sources/Hermes-Bridging-Header.h`
4. **Clean and rebuild** - Run `make clean && make`
5. **Test again** - Verify app still works

---

## Appendix A: Notification Reference

These are the key notifications used for Objective-C ↔ Swift communication.

### Pandora API Notifications (defined in Sources/Notifications.h)

| Notification | Purpose | UserInfo |
|-------------|---------|----------|
| `PandoraDidAuthenticateNotification` | Login successful | None |
| `PandoraDidLoadStationsNotification` | Stations list loaded | `stations` array |
| `PandoraDidLoadStationInfoNotification` | Station details loaded | Station object |
| `PandoraDidSearchNotification` | Search results ready | Results dictionary |
| `PandoraDidLoadGenreStationsNotification` | Genre list loaded | Genres array |
| `StationCreatedNotification` | New station created | Station object |
| `StationRenamedNotification` | Station renamed | Station object |
| `StationDeletedNotification` | Station deleted | Station ID |
| `SeedAddedNotification` | Seed added to station | Seed info |
| `SeedDeletedNotification` | Seed removed | Seed ID |
| `FeedbackDeletedNotification` | Feedback removed | Feedback ID |
| `hermes.pandora.error` | API error occurred | Error message |

### Playback Notifications

| Notification | Purpose | UserInfo |
|-------------|---------|----------|
| `StationDidPlaySongNotification` | New song started | Song object |
| `ASStatusChangedNotification` | Playback state changed | Status info |
| `hermes.song-rated` | Song was rated | Song + rating |

### How to Observe in Swift

```swift
// In ViewModel init or setupNotifications method:
NotificationCenter.default.addObserver(
    forName: Notification.Name("PandoraDidSearchNotification"),
    object: nil,
    queue: .main
) { [weak self] notification in
    guard let results = notification.userInfo?["results"] as? NSDictionary else { return }
    // Process results
}
```

### How to Post from Swift

```swift
NotificationCenter.default.post(
    name: Notification.Name("SomeNotification"),
    object: nil,
    userInfo: ["key": value]
)
```

---

## Appendix B: Pandora API Method Reference

Key methods in `Sources/Pandora/Pandora.h` that SwiftUI view models need to call:

### Authentication

- `authenticate` - Login with credentials
- `logout` - Clear session

### Stations

- `fetchStations` - Load station list
- `createStation:` - Create from music token
- `deleteStation:` - Delete station
- `renameStation:to:` - Rename station
- `stationInfo:` - Get station details (seeds, feedback)

### Search

- `search:` - Search for artists/songs
- `genreStations` - Get genre categories

### Seeds

- `addSeed:toStation:` - Add seed to station
- `deleteSeed:fromStation:` - Remove seed

### Feedback

- `deleteFeedback:fromStation:` - Remove like/dislike

### Playback (handled by PlaybackController)

- `rateSong:as:` - Like/dislike song
- `tiredOfSong:` - Mark song as tired

---

## Appendix C: File Creation Checklist

When creating new Swift files:

### 1. Create the file

```bash
touch Sources/Swift/Views/MyNewView.swift
```

### 2. Add to Xcode project

- Open Hermes.xcodeproj in Xcode
- Right-click on the appropriate group (Views, ViewModels, etc.)
- Select "Add Files to Hermes..."
- Navigate to and select the new file
- Ensure "Copy items if needed" is UNCHECKED
- Ensure target "Hermes" is CHECKED
- Click Add

### 3. Verify in project

- File should appear in the project navigator
- Build should succeed: `make`

### 4. File templates

**View Template:**

```swift
//
//  MyView.swift
//  Hermes
//

import SwiftUI

struct MyView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: MyViewModel
    
    // MARK: - Body
    var body: some View {
        Text("Hello")
    }
}
```

**ViewModel Template:**

```swift
//
//  MyViewModel.swift
//  Hermes
//

import Foundation
import Combine

@MainActor
final class MyViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var someState: String = ""
    
    // MARK: - Dependencies
    private let pandora: Pandora
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(pandora: Pandora) {
        self.pandora = pandora
        setupNotificationObservers()
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        // Add observers here
    }
    
    // MARK: - Public Methods
    func doSomething() {
        // Implementation
    }
}
```

---

## Appendix D: Testing Checklist

After each task, verify:

### Build

- [ ] `make clean && make` succeeds with no errors
- [ ] No new warnings introduced

### Functionality

- [ ] Feature works as expected
- [ ] No regressions in existing features
- [ ] Error states handled gracefully

### UI

- [ ] Looks correct in light mode
- [ ] Looks correct in dark mode
- [ ] Responds to window resizing
- [ ] Keyboard shortcuts work (if applicable)

### Integration

- [ ] Notifications received correctly
- [ ] Pandora API calls succeed
- [ ] State updates propagate to UI

---

## Appendix E: Common Patterns

### Calling Pandora API from ViewModel

```swift
func fetchSomething() {
    isLoading = true
    
    // Set up observer BEFORE making the call
    NotificationCenter.default.addObserver(
        forName: Notification.Name("PandoraDidFetchSomethingNotification"),
        object: nil,
        queue: .main
    ) { [weak self] notification in
        self?.isLoading = false
        // Process notification.userInfo
    }
    
    // Make the API call
    pandora.fetchSomething()
}
```

### Presenting Sheets

```swift
// In parent view
@State private var showingSheet = false
@State private var itemForSheet: SomeModel?

var body: some View {
    List { ... }
        .sheet(item: $itemForSheet) { item in
            SheetView(item: item)
        }
}

// Or with boolean
var body: some View {
    List { ... }
        .sheet(isPresented: $showingSheet) {
            SheetView()
        }
}
```

### Context Menus

```swift
ForEach(items) { item in
    ItemRow(item: item)
        .contextMenu {
            Button("Action 1") { doAction1(item) }
            Button("Action 2") { doAction2(item) }
            Divider()
            Button("Delete", role: .destructive) { delete(item) }
        }
}
```

### Confirmation Dialogs

```swift
.confirmationDialog("Title", isPresented: $showConfirmation) {
    Button("Destructive Action", role: .destructive) {
        performAction()
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("Are you sure?")
}
```

---

## Summary

Execute tasks 1-7 in order, then task 8 last. Each task is independent but builds on the existing SwiftUI infrastructure. The key principles are:

1. **Use SwiftUI native components** - No AppKit unless absolutely necessary
2. **Communicate via NotificationCenter** - Bridge to Objective-C business logic
3. **Keep ViewModels @MainActor** - Safe UI updates
4. **Test after each task** - Don't accumulate broken code
5. **Delete legacy code last** - Only after everything works

---

## macOS Tahoe (26.0) Modernization Guidelines

### Use @Observable Instead of ObservableObject

**Old Pattern (pre-Tahoe):**

```swift
@MainActor
final class MyViewModel: ObservableObject {
    @Published var value: String = ""
}

// In view:
@ObservedObject var viewModel: MyViewModel
```

**New Pattern (Tahoe with Swift 5.9+):**

```swift
import Observation

@MainActor
@Observable
final class MyViewModel {
    var value: String = ""  // No @Published needed
}

// In view:
var viewModel: MyViewModel  // Just a regular property
```

### Use Environment for URL Opening

**Old Pattern:**

```swift
NSWorkspace.shared.open(url)
```

**New Pattern:**

```swift
@Environment(\.openURL) private var openURL

// Then:
openURL(url)
```

### Use NavigationStack

**Old Pattern:**

```swift
NavigationView {
    // Content
}
```

**New Pattern:**

```swift
NavigationStack {
    // Content
}
.navigationDestination(for: Station.self) { station in
    StationDetailView(station: station)
}
```

### Use Modern Async/Await

**Old Pattern:**

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    doSomething()
}
```

**New Pattern:**

```swift
Task { @MainActor in
    try? await Task.sleep(for: .seconds(0.5))
    doSomething()
}
```

### Use MenuBarExtra for Status Bar

**Old Pattern:**

```swift
let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
statusItem.button?.image = icon
statusItem.menu = menu
```

**New Pattern:**

```swift
// In HermesApp.swift:
MenuBarExtra("Hermes", systemImage: "music.note") {
    Button("Play/Pause") { /* action */ }
    Button("Next") { /* action */ }
    // ... rest of menu
}
.menuBarExtraStyle(.window)
```

### Remove All Availability Checks

Since we target Tahoe exclusively, remove all `@available` and `if #available` checks:

```swift
// DELETE:
if #available(macOS 13.0, *) {
    // Modern API
} else {
    // Fallback
}

// JUST USE:
// Modern API directly
```

### Use Swift 6 Typed Throws

**Old Pattern:**

```swift
func fetchData() throws -> Data {
    // ...
}
```

**New Pattern:**

```swift
enum FetchError: Error {
    case networkError
    case invalidData
}

func fetchData() throws(FetchError) -> Data {
    // ...
}
```

### File Template Updates

**View Template (Tahoe):**

```swift
//
//  MyView.swift
//  Hermes
//

import SwiftUI

struct MyView: View {
    // MARK: - Properties
    var viewModel: MyViewModel  // No @ObservedObject with @Observable
    @State private var localState: String = ""
    
    // MARK: - Body
    var body: some View {
        // Keep this minimal and readable
    }
    
    // MARK: - Subviews
    private var headerView: some View {
        // Extract complex sections
    }
}
```

**ViewModel Template (Tahoe):**

```swift
//
//  MyViewModel.swift
//  Hermes
//

import Foundation
import Combine
import Observation

@MainActor
@Observable
final class MyViewModel {
    // MARK: - Properties (no @Published needed)
    var someState: String = ""
    
    // MARK: - Dependencies
    private let pandora: Pandora
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(pandora: Pandora) {
        self.pandora = pandora
        setupNotificationObservers()
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .someNotification)
            .sink { [weak self] notification in
                self?.handleNotification(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func doSomething() async {
        // Use async/await for asynchronous operations
    }
}
```
