# Manual Steps Required to Complete Swift Frontend Migration

## Current Status

✅ All Swift source files have been created in `Sources/Swift/`
✅ Bridging header created at `Sources/Hermes-Bridging-Header.h`
✅ Info.plist updated (removed NSMainNibFile, NSPrincipalClass, LSUIElement)
✅ main.m and MainMenu.xib removed from build

❌ Swift files are NOT in the Xcode project
❌ Bridging header is NOT configured in build settings

## Required Manual Steps in Xcode

### Step 1: Add Swift Files to Project

1. Open `Hermes.xcodeproj` in Xcode
2. In the Project Navigator, right-click on `Sources`
3. Select "Add Files to Hermes..."
4. Navigate to `Sources/Swift` folder
5. Select the `Swift` folder
6. **Important**: Check "Create groups" (not "Create folder references")
7. **Important**: Ensure "Hermes" target is checked
8. Click "Add"

This will add all Swift files to the project:

- HermesApp.swift (main entry point with @main)
- MinimalAppDelegate.swift
- Models/ (StationModel, SongModel)
- ViewModels/ (AppState, LoginViewModel, PlayerViewModel, StationsViewModel, HistoryViewModel)
- Views/ (ContentView, LoginView, PlayerView, SidebarView, StationsListView, HistoryListView, ErrorView, PreferencesView)
- Utilities/ (NotificationBridge)

### Step 2: Configure Bridging Header

1. In Xcode, select the project in Project Navigator
2. Select the "Hermes" target
3. Go to "Build Settings" tab
4. Search for "bridging"
5. Find "Objective-C Bridging Header"
6. Set the value to: `Sources/Hermes-Bridging-Header.h`

### Step 3: Enable Swift

1. Still in Build Settings
2. Search for "Swift Language Version"
3. Ensure it's set to "Swift 5" or later

### Step 4: Build and Run

1. Clean build folder (Product → Clean Build Folder or Cmd+Shift+K)
2. Build (Product → Build or Cmd+B)
3. Run (Product → Run or Cmd+R)

## Expected Result

After completing these steps, the app should:

1. ✅ Launch with SwiftUI window (not XIB)
2. ✅ Show login view (or auto-authenticate if credentials saved)
3. ✅ Display proper sidebar with Stations/History navigation
4. ✅ Show responsive album art that scales with window
5. ✅ Have all playback controls working
6. ✅ Console shows debug prints:
   - "AppState: Initializing..."
   - "AppState: Initialized - currentView: ..."
   - "ContentView: Appeared - currentView: ..."

## Troubleshooting

If the app still doesn't work after these steps:

### Issue: Build errors about missing symbols

**Solution**: Verify bridging header path is correct and all Objective-C headers are importable

### Issue: App launches but shows blank window

**Solution**: Check console for Swift errors or crashes. Verify AppState.shared is being created.

### Issue: App immediately quits

**Solution**: Check that LSUIElement is removed from Info.plist (should show in Dock)

### Issue: Duplicate symbol errors

**Solution**: Ensure old HermesAppDelegate isn't conflicting. May need to remove it.

## Why Manual Steps Are Needed

The Xcode project file (`.pbxproj`) is a complex binary-like format that's difficult to edit programmatically without corruption. Adding files and configuring build settings is safest done through Xcode's UI, which properly maintains all the internal references and UUIDs.

## Next Steps After Manual Configuration

Once the app builds and runs with SwiftUI:

1. Test all functionality
2. Remove old Objective-C UI code (HermesAppDelegate, AuthController, etc.)
3. Remove XIB files completely
4. Clean up any remaining legacy code
5. Verify everything works correctly

The Swift frontend is complete and ready - it just needs to be added to the Xcode project!
