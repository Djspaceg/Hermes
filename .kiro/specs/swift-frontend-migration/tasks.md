# Implementation Plan: Swift Frontend Migration

## Overview

This plan properly migrates Hermes to a 100% Swift/SwiftUI frontend with Objective-C business logic. The migration removes all XIB dependencies and uses SwiftUI's native lifecycle.

## Tasks

- [x] 1. Create MinimalAppDelegate in Swift
  - [x] 1.1 Create MinimalAppDelegate.swift file
    - Create `Sources/Swift/MinimalAppDelegate.swift`
    - Implement NSApplicationDelegate protocol
    - Add applicationDidFinishLaunching method
    - NO UI-related code - only notifications and setup
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 1.2 Move notification setup from HermesAppDelegate
    - Add setupNotificationObservers() method
    - Observe PandoraDidErrorNotification
    - Observe ASStreamError
    - Observe PandoraDidLogOutNotification
    - Observe StationDidPlaySongNotification
    - Observe ASStatusChangedNotification
    - Observe NSWorkspaceWillSleepNotification
    - _Requirements: 3.2, 3.3_

  - [x] 1.3 Add UserDefaults registration
    - Add registerDefaults() method
    - Register all app defaults (quality, scrobbling, etc.)
    - _Requirements: 3.3_

  - [x] 1.4 Add media key setup
    - Add setupMediaKeys() method
    - Initialize SPMediaKeyTap if enabled in preferences
    - _Requirements: 3.3_

- [x] 2. Update SwiftUI App Entry Point
  - [ ] 2.1 Add @main to HermesSwiftUIApp
    - Add @main attribute to struct
    - Add @NSApplicationDelegateAdaptor(MinimalAppDelegate.self)
    - Verify WindowGroup creates window
    - _Requirements: 2.1, 2.2, 2.3, 2.5_

  - [ ] 2.2 Remove main.m from build
    - Remove main.m from Compile Sources build phase in project.pbxproj
    - Remove PBXBuildFile entry for main.m
    - _Requirements: 2.4_

  - [ ] 2.3 Update Info.plist
    - Remove NSMainNibFile key
    - Remove NSPrincipalClass key
    - Verify CFBundleExecutable is correct
    - _Requirements: 1.2_

- [ ] 3. Remove XIB Dependencies
  - [ ] 3.1 Remove MainMenu.xib from Resources
    - Remove from Resources build phase in project.pbxproj
    - Keep file for reference but don't load it
    - _Requirements: 1.1_

  - [ ] 3.2 Update HermesAppDelegate to be XIB-independent
    - Remove all IBOutlet properties
    - Make window property optional and unused
    - Remove all UI controller properties (auth, stations, history, etc.)
    - Keep only Pandora and business logic properties
    - _Requirements: 1.3, 1.5_

  - [ ] 3.3 Disable setCurrentView method
    - Make setCurrentView do nothing (just return)
    - Add comment explaining SwiftUI handles views
    - _Requirements: 5.2, 5.3_

  - [ ] 3.4 Disable drawer management methods
    - Disable handleDrawer()
    - Disable historyShow() and stationsShow()
    - Disable toggleDrawerVisible()
    - _Requirements: 5.2_

- [ ] 4. Create Proper Sidebar Structure
  - [ ] 4.1 Create SidebarView with structured layout
    - Create `Sources/Swift/Views/SidebarView.swift`
    - Add fixed navigation header (Stations/History buttons)
    - Add conditional sort controls (Name/Date)
    - Add scrollable content area
    - Add conditional footer (different for Stations/History)
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [ ] 4.2 Create custom button styles
    - Create NavigationHeaderButtonStyle
    - Create SortButtonStyle
    - Highlight selected state
    - _Requirements: 6.1, 6.2_

  - [ ] 4.3 Create StationsListView
    - Create `Sources/Swift/Views/StationsListView.swift`
    - Display list of stations
    - Show playing indicator
    - Handle selection and double-click to play
    - Add context menu for rename/delete
    - _Requirements: 6.3_

  - [ ] 4.4 Create HistoryListView
    - Create `Sources/Swift/Views/HistoryListView.swift`
    - Display list of history items
    - Show album art thumbnails (40x40pt)
    - Handle selection
    - _Requirements: 6.3_

  - [ ] 4.5 Update ContentView to use SidebarView
    - Replace old sidebar with new SidebarView
    - Use NavigationSplitView (2 columns)
    - Sidebar column: SidebarView
    - Detail column: PlayerView
    - Add sidebar toggle button
    - _Requirements: 6.5_

- [ ] 5. Fix Album Art Scaling
  - [ ] 5.1 Add GeometryReader to PlayerView
    - Wrap body in GeometryReader
    - Calculate optimal album art size
    - Use min(availableWidth, availableHeight * 0.5, 600)
    - _Requirements: 7.1, 7.2, 7.4_

  - [ ] 5.2 Update album art AsyncImage
    - Use calculated size for frame
    - Maintain aspect ratio with .fit
    - Handle loading/success/failure states
    - _Requirements: 7.3_

  - [ ] 5.3 Remove minimum window size constraints
    - Ensure window can be resized small
    - Album art should scale down appropriately
    - _Requirements: 7.5_

- [ ] 6. Update ViewModels
  - [ ] 6.1 Update StationsViewModel
    - Add sortedStations(by:) method
    - Add showAddStation() method
    - Add renameStation(_ station:) overload
    - _Requirements: 6.2_

  - [ ] 6.2 Update HistoryViewModel
    - Add selectedItem property
    - Add openSongOnPandora() method
    - Add openArtistOnPandora() method
    - Add openAlbumOnPandora() method
    - Add showLyrics() method
    - Add likeSelected() method
    - Add dislikeSelected() method
    - _Requirements: 6.4_

  - [ ] 6.3 Update AppState
    - Remove sidebarContent property (not needed)
    - Keep only isSidebarVisible and toggleSidebar()
    - Add checkSavedCredentials() on init
    - Auto-authenticate if credentials exist
    - _Requirements: 4.2, 4.3, 5.1, 5.4, 5.5_

- [ ] 7. Test and Verify
  - Build and run the app
  - Verify SwiftUI window appears (not XIB)
  - Test login flow
  - Test sidebar navigation (Stations/History)
  - Test sort controls
  - Test footer buttons (both Stations and History)
  - Test sidebar toggle
  - Test album art scaling at different window sizes
  - Test playback controls
  - Test keyboard shortcuts
  - Verify Dark Mode
  - Verify no XIB loading errors

- [ ] 8. Clean Up Legacy Code
  - [ ] 8.1 Remove old HermesAppDelegate file
    - Delete Sources/HermesAppDelegate.h
    - Delete Sources/HermesAppDelegate.m
    - Update project.pbxproj to remove references
    - _Requirements: 1.3, 1.5_

  - [ ] 8.2 Remove old UI controller files
    - Delete Sources/Controllers/AuthController.h/m
    - Delete Sources/Controllers/StationsController.h/m (if not needed)
    - Delete Sources/Controllers/HistoryController.h/m (if not needed)
    - Update project.pbxproj
    - _Requirements: 1.5_

  - [ ] 8.3 Remove XIB files
    - Delete Resources/English.lproj/MainMenu.xib
    - Remove from project.pbxproj
    - _Requirements: 1.1_

  - [ ] 8.4 Remove old SwiftUI files from failed migration
    - Delete old StationsView.swift and HistoryView.swift
    - Delete HermesAppDelegate+SwiftUI.swift extension
    - Keep only new SidebarView, StationsListView, HistoryListView
    - _Requirements: Clean architecture_

- [ ] 9. Final Testing and Verification
  - Clean build from scratch
  - Verify no XIB loading
  - Verify no IBOutlet warnings
  - Test all user flows
  - Test at various window sizes
  - Verify performance
  - Check for memory leaks
  - Verify Dark Mode
  - Test keyboard shortcuts
  - Test media keys

## Notes

- This migration removes ALL XIB dependencies
- SwiftUI manages the complete UI lifecycle
- Objective-C code only handles business logic
- Clean architecture with clear boundaries
- Proper sidebar structure following macOS patterns
- Responsive album art that scales correctly
- No hacky workarounds - done the RIGHT way
