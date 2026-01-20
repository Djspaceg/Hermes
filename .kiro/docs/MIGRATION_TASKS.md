# Objective-C to Swift Migration Tasks

**Goal:** Migrate all feasible Objective-C code to modern Swift, keeping only core business logic in Objective-C.

**Status:** Phase 3 - Starting migration
**Started:** January 15, 2026

---

## Phase 3: Quick Wins (Constants & Utilities)

### Task 1: Migrate Notifications.{h,m} ✅

**Status:** COMPLETE  
**Priority:** High  
**Effort:** 1 hour (completed)  
**Files:**

- Deleted: `Sources/Notifications.{h,m}` ✅
- Created: `Sources/Swift/Utilities/NotificationNames.swift` ✅
- Updated: All Swift and Objective-C files ✅

**Description:**

- Migrated notification name constants from Objective-C to Swift
- Used inline string literals in both Swift and Objective-C for simplicity
- Removed old Objective-C notification files
- Updated all references across the codebase

**Results:**

- Build succeeds with zero errors ✅
- All 50 unit tests passing ✅
- Type-safe notification usage in Swift
- Clean separation between Swift and Objective-C layers

**Notes:**

- Initially attempted to use Swift extensions with @objc wrapper, but encountered circular dependency issues
- Pragmatic solution: use string literals directly in both languages
- This approach is cleaner and avoids bridging complexity

---

### Task 2: Migrate HermesConstants.h ⏳

**Status:** Not Started  
**Priority:** High  
**Effort:** 15 minutes  
**Files:**

- Delete: `Sources/HermesConstants.h`
- Create: `Sources/Swift/Utilities/Constants.swift`

**Description:**

- Convert C macros to Swift constants
- Use struct with static properties
- Keep Objective-C compatibility with @objc where needed

**Benefits:**

- No preprocessor macros
- Type safety
- Better organization

---

### Task 3: Delete Keychain.{h,m} ⏳

**Status:** Not Started  
**Priority:** High  
**Effort:** 5 minutes  
**Files:**

- Delete: `Sources/Integration/Keychain.{h,m}`
- Already replaced by: `Sources/Swift/Utilities/KeychainManager.swift`

**Description:**

- Remove old Objective-C keychain wrapper
- Verify no remaining references
- Update bridging header

**Benefits:**

- Less code
- Single implementation
- Already using Swift version

---

## Phase 4: Modernization (Networking & Images)

### Task 4: Migrate ImageLoader.{h,m} ⏳

**Status:** Not Started  
**Priority:** Medium  
**Effort:** 1-2 hours  
**Files:**

- Delete: `Sources/Models/ImageLoader.{h,m}`
- Create: `Sources/Swift/Utilities/ImageCache.swift`
- Update: Views using ImageLoader

**Description:**

- Replace with SwiftUI AsyncImage + URLCache
- Implement modern image caching
- Use async/await for loading
- Update PlayerView and other image consumers

**Benefits:**

- Native SwiftUI solution
- Modern async/await
- Better memory management
- Simpler code

---

### Task 5: Migrate NetworkConnection.{h,m} ⏳

**Status:** Not Started  
**Priority:** Medium  
**Effort:** 30 minutes  
**Files:**

- Delete: `Sources/NetworkConnection.{h,m}`
- Create: `Sources/Swift/Utilities/NetworkMonitor.swift`

**Description:**

- Replace with NWPathMonitor (Network framework)
- Use Combine publishers for reachability changes
- Modern Swift concurrency

**Benefits:**

- Modern Network framework
- Better API
- Reactive updates

---

### Task 6: Migrate URLConnection.{h,m} ⏳

**Status:** Not Started  
**Priority:** Medium  
**Effort:** 1 hour  
**Files:**

- Delete: `Sources/URLConnection.{h,m}`
- Create: `Sources/Swift/Utilities/HTTPClient.swift`

**Description:**

- Replace with URLSession + async/await
- Modern error handling
- Cleaner API

**Benefits:**

- Modern URLSession
- async/await
- Better error handling

---

## Phase 5: Advanced Migrations

### Task 7: Migrate Scrobbler.{h,m} ⏳

**Status:** Not Started  
**Priority:** Low  
**Effort:** 2-3 hours  
**Files:**

- Delete: `Sources/Integration/Scrobbler.{h,m}`
- Create: `Sources/Swift/Services/LastFMService.swift`

**Description:**

- Rewrite Last.fm integration in Swift
- Use async/await for API calls
- Modern error handling
- Better testability

**Benefits:**

- Modern Swift
- Testable
- Cleaner code
- async/await

---

### Task 8: Migrate AppleScript.{h,m} ⏳

**Status:** Not Started  
**Priority:** Low  
**Effort:** 2 hours  
**Files:**

- Delete: `Sources/Integration/AppleScript.{h,m}`
- Create: `Sources/Swift/Services/AppleScriptSupport.swift`

**Description:**

- Rewrite AppleScript support in Swift
- Use @objc where needed for scripting bridge
- Modern Swift patterns

**Benefits:**

- Swift codebase
- Better maintainability

---

### Task 9: Delete HermesApp.{h,m} ⏳

**Status:** Not Started  
**Priority:** Low  
**Effort:** 30 minutes  
**Files:**

- Delete: `Sources/HermesApp.{h,m}`
- Already replaced by: `Sources/Swift/AppState.swift`

**Description:**

- Remove legacy app singleton
- Verify no remaining references
- Clean up bridging header

**Benefits:**

- Less legacy code
- Already using AppState

---

### Task 10: Delete FileReader.{h,m} ✅

**Status:** COMPLETE  
**Priority:** Low  
**Effort:** 5 minutes (completed)  
**Files:**

- Deleted: `Sources/FileReader.{h,m}` ✅

**Description:**

- Verified FileReader was not used anywhere in the codebase
- Removed both header and implementation files
- Cleaned up Xcode project references

**Results:**

- Build succeeds with zero errors ✅
- All 50 unit tests passing ✅
- Removed ~60 lines of unused legacy code

---

### Task 11: Delete NSDrawerWindow Workaround ✅

**Status:** COMPLETE  
**Priority:** Low  
**Effort:** 5 minutes (completed)  
**Files:**

- Deleted: `Sources/Views/NSDrawerWindow-HermesFirstResponderWorkaround.m` ✅

**Description:**

- Removed macOS 10.12 workaround for NSDrawer first responder issues
- NSDrawer is an AppKit component not used in SwiftUI
- Verified no references in codebase

**Results:**

- Build succeeds with zero errors ✅
- All 50 unit tests passing ✅
- Removed ~30 lines of obsolete workaround code

---

## Keep in Objective-C (Core Business Logic)

### ✅ PlaybackController.{h,m}

**Reason:** Complex audio state management, working, stable  
**Status:** Keep as-is

### ✅ Pandora API (Pandora/)

**Reason:** Complex networking, encryption, API client - working, stable  
**Status:** Keep as-is

### ✅ AudioStreamer (AudioStreamer/)

**Reason:** CoreAudio wrapper, streaming engine - working, stable  
**Status:** Keep as-is

---

## Progress Tracking

**Total Tasks:** 11  
**Completed:** 3 ✅  
**In Progress:** 0  
**Not Started:** 8  

**Completed Tasks:**

- ✅ Task 1: Migrate Notifications.{h,m} to Swift (1 hour)
- ✅ Task 10: Delete FileReader.{h,m} (5 minutes)
- ✅ Task 11: Delete NSDrawerWindow Workaround (5 minutes)

**Estimated Total Effort:** 8-10 hours  
**Time Spent:** 1 hour 10 minutes  
**Remaining Effort:** 6 hours 50 minutes - 8 hours 50 minutes  
**Expected Completion:** TBD

---

## Migration Guidelines

1. **Test after each task** - Run full test suite
2. **Build after each task** - Ensure no compilation errors
3. **One task at a time** - Don't mix migrations
4. **Update bridging header** - Remove Objective-C imports as we go
5. **Document breaking changes** - Note any API changes
6. **Keep commits atomic** - One task per commit

---

## Success Criteria

- ✅ All tests passing
- ✅ Zero compilation errors
- ✅ Zero warnings
- ✅ App functionality preserved
- ✅ Code is more maintainable
- ✅ Modern Swift patterns used
