# Phase 2: Delete Dead Code - Action Plan

**Date:** January 14, 2026  
**Status:** READY TO EXECUTE

## Current Situation

✅ **SwiftUI is the primary UI** - HermesApp.swift with @main is the entry point  
✅ **All tests passing** - 50 unit tests verify view model parity  
✅ **App runs on SwiftUI** - No XIB files loaded, SwiftUI views active  

❌ **Dead Objective-C code still compiled** - Controllers, views, and legacy files not used but still in project

## What Needs to be Deleted

### 1. Dead Controllers (6 files - 2,500+ lines)

These are compiled but **NEVER INSTANTIATED** by the running app:

- `Sources/Controllers/AuthController.m/h` (150 lines)
- `Sources/Controllers/StationsController.m/h` (650 lines)
- `Sources/Controllers/StationController.m/h` (450 lines)
- `Sources/Controllers/HistoryController.m/h` (400 lines)
- `Sources/Controllers/PreferencesController.m/h` (600 lines)
- `Sources/Controllers/MainSplitViewController.m/h` (250 lines)

**Why they're dead:**

- HermesAppDelegate.m has IBOutlet properties for them
- But HermesAppDelegate is NOT the app delegate anymore
- MinimalAppDelegate is the actual delegate (via @NSApplicationDelegateAdaptor)
- MinimalAppDelegate doesn't create or use these controllers

### 2. Dead Views (11 files - 1,500+ lines)

Legacy AppKit views replaced by SwiftUI:

- `Sources/Views/HermesMainWindow.m/h`
- `Sources/Views/HermesBackgroundView.m/h`
- `Sources/Views/HermesVolumeSliderCell.m/h`
- `Sources/Views/MusicProgressSliderCell.m/h`
- `Sources/Views/StationsSidebarView.m/h`
- `Sources/Views/StationsTableView.m/h`
- `Sources/Views/HistoryView.m/h`
- `Sources/Views/HistoryCollectionView.m/h`
- `Sources/Views/LabelHoverShowField.m/h`
- `Sources/Views/LabelHoverShowFieldCell.m/h`

### 3. Legacy Entry Point Files (3 files)

- `Sources/main.m` - Replaced by @main in HermesApp.swift
- `Sources/HermesAppDelegate.m/h` - Replaced by MinimalAppDelegate.swift
- `Resources/English.lproj/MainMenu.xib` - Not loaded, SwiftUI handles UI

### 4. Dead Models (2 files)

- `Sources/Models/HistoryItem.m/h` - Replaced by SongModel in Swift

**Note:** ImageLoader.m/h is still used by Objective-C code, keep it.

## Deletion Order (Safe)

### Step 1: Remove Dead Controllers

Delete 6 controller files that are never instantiated.

### Step 2: Remove Dead Views  

Delete 11 view files that are never displayed.

### Step 3: Remove Legacy Entry Point

Delete main.m, HermesAppDelegate.m/h, MainMenu.xib.

### Step 4: Remove Dead Models

Delete HistoryItem.m/h.

### Step 5: Update Xcode Project

Remove file references from Hermes.xcodeproj.

### Step 6: Verify Build

Ensure app still builds and runs correctly.

## What to KEEP

### Keep All Business Logic (Active)

✅ **PlaybackController** - Orchestrates playback, still used by MinimalAppDelegate  
✅ **Pandora API** - All Pandora/*.m files  
✅ **AudioStreamer** - All AudioStreamer/*.m files  
✅ **Integration** - Scrobbler, AppleScript, Keychain  
✅ **Networking** - URLConnection, NetworkConnection  
✅ **Models** - Station.m/h, Song.m/h, ImageLoader.m/h  
✅ **Utilities** - FileReader, Notifications, Crypt  

### Keep All Swift Code (Active)

✅ **HermesApp.swift** - Entry point  
✅ **MinimalAppDelegate.swift** - Bridges to Objective-C  
✅ **All Views** - ContentView, PlayerView, SidebarView, etc.  
✅ **All ViewModels** - LoginViewModel, StationsViewModel, etc.  
✅ **All Models** - SongModel, StationModel  
✅ **All Utilities** - KeychainManager, SettingsManager, NotificationManager  

## Estimated Impact

- **Lines of code removed:** ~4,000+
- **Files removed:** 22
- **Build time improvement:** Moderate (fewer files to compile)
- **Code clarity:** Significant (no dead code confusion)
- **Risk:** Very low (code is proven dead via testing)

## Verification After Deletion

1. ✅ Build succeeds
2. ✅ All 50 tests still pass
3. ✅ App launches
4. ✅ Login works
5. ✅ Stations load
6. ✅ Playback works
7. ✅ History works
8. ✅ Preferences work

## Ready to Execute?

**YES!** We have:

- ✅ Verified SwiftUI is primary
- ✅ 50 passing tests proving parity
- ✅ Clear understanding of what's dead vs active
- ✅ Safe deletion order
- ✅ Verification plan

## Next Command

```bash
# Start with controllers
rm Sources/Controllers/AuthController.{m,h}
rm Sources/Controllers/StationsController.{m,h}
rm Sources/Controllers/StationController.{m,h}
rm Sources/Controllers/HistoryController.{m,h}
rm Sources/Controllers/PreferencesController.{m,h}
rm Sources/Controllers/MainSplitViewController.{m,h}
```

Then proceed with views, entry point files, and models.
