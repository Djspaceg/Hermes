# Objective-C to Swift Migration Tasks

> **RECONCILED - complete before 2026-09-16.** The implementation predates this reconciliation. This document is retained as migration history; it is not an active backlog. See `.kiro/specs/objc-to-swift-migration/` and `.kiro/specs/full-swift-migration/` for the completed successor plans.

**Historical Goal:** Migrate all feasible Objective-C code to modern Swift, keeping only core business logic in Objective-C.<br>
**Outcome:** The application source is now Swift, including the components this plan originally proposed keeping in Objective-C.<br>
**Status:** COMPLETE<br>
**Started:** January 15, 2026<br>
**Reconciled:** September 16, 2026

---

## Phase 3: Quick Wins (Constants & Utilities)

### Task 1: Migrate Notifications.{h,m} ✅

**Status:** COMPLETE<br>
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

### Task 2: Migrate HermesConstants.h ✅

**Status:** COMPLETE<br>
**Priority:** High  
**Effort:** 15 minutes  
**Files:**

- Deleted: `Sources/HermesConstants.h`
- Created: `Sources/Swift/Utilities/Constants.swift`

**Completion note (verified 2026-09-16):** The Objective-C header is absent, and `Constants.swift` is present in the Hermes target's Sources build phase.

**Description:**

- Convert C macros to Swift constants
- Use struct with static properties
- Keep Objective-C compatibility with @objc where needed

**Benefits:**

- No preprocessor macros
- Type safety
- Better organization

---

### Task 3: Delete Keychain.{h,m} ✅

**Status:** COMPLETE<br>
**Priority:** High  
**Effort:** 5 minutes  
**Files:**

- Deleted: `Sources/Integration/Keychain.{h,m}`
- Replaced by: `Sources/Swift/Utilities/KeychainManager.swift`

**Completion note (verified 2026-09-16):** The Objective-C files are absent, `KeychainManager.swift` is in the Sources build phase, and the current project has no bridging-header setting.

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

### Task 4: Migrate ImageLoader.{h,m} ✅

**Status:** COMPLETE<br>
**Priority:** Medium  
**Effort:** 1-2 hours  
**Files:**

- Deleted: `Sources/Models/ImageLoader.{h,m}`
- Created: `Sources/Swift/Utilities/ImageCache.swift`
- Updated: Image-loading consumers

**Completion note (verified 2026-09-16):** The Objective-C files are absent, and `ImageCache.swift` is present in the Sources build phase.

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

### Task 5: Migrate NetworkConnection.{h,m} ✅

**Status:** COMPLETE<br>
**Priority:** Medium  
**Effort:** 30 minutes  
**Files:**

- Deleted: `Sources/NetworkConnection.{h,m}`
- Created: `Sources/Swift/Utilities/NetworkMonitor.swift`

**Completion note (verified 2026-09-16):** The Objective-C files are absent, and `NetworkMonitor.swift` is present in the Sources build phase.

**Description:**

- Replace with NWPathMonitor (Network framework)
- Use Combine publishers for reachability changes
- Modern Swift concurrency

**Benefits:**

- Modern Network framework
- Better API
- Reactive updates

---

### Task 6: Migrate URLConnection.{h,m} ✅

**Status:** COMPLETE<br>
**Priority:** Medium  
**Effort:** 1 hour  
**Files:**

- Deleted: `Sources/URLConnection.{h,m}`
- Created: `Sources/Swift/Utilities/HTTPClient.swift`

**Completion note (verified 2026-09-16):** The Objective-C files are absent, and `HTTPClient.swift` is present in the Sources build phase.

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

### Task 7: Migrate Scrobbler.{h,m} ✅

**Status:** COMPLETE<br>
**Priority:** Low  
**Effort:** 2-3 hours  
**Files:**

- Deleted: `Sources/Integration/Scrobbler.{h,m}`
- Created: `Sources/Swift/Services/LastFMService.swift`

**Completion note (verified 2026-09-16):** The Objective-C files are absent, and `LastFMService.swift` is present in the Sources build phase.

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

### Task 8: Migrate AppleScript.{h,m} ✅

**Status:** COMPLETE<br>
**Priority:** Low  
**Effort:** 2 hours  
**Files:**

- Deleted: `Sources/Integration/AppleScript.{h,m}`
- Created: `Sources/Swift/Services/AppleScriptSupport.swift`

**Completion note (verified 2026-09-16):** The Objective-C files are absent, and `AppleScriptSupport.swift` is present in the Sources build phase.

**Description:**

- Rewrite AppleScript support in Swift
- Use @objc where needed for scripting bridge
- Modern Swift patterns

**Benefits:**

- Swift codebase
- Better maintainability

---

### Task 9: Delete HermesApp.{h,m} ✅

**Status:** COMPLETE<br>
**Priority:** Low  
**Effort:** 30 minutes  
**Files:**

- Deleted: `Sources/HermesApp.{h,m}`
- Replaced by: `Sources/Swift/ViewModels/AppState.swift`

**Completion note (verified 2026-09-16):** The Objective-C files are absent, and `AppState.swift` is present in the Sources build phase.

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

## Formerly Kept in Objective-C (Now Swift)

### ✅ PlaybackController.swift

**Historical reason:** Complex audio state management, working, stable<br>
**Status:** Migrated to `Sources/Swift/Services/PlaybackController.swift` (verified 2026-09-16)

### ✅ Pandora API

**Historical reason:** Complex networking, encryption, API client - working, stable<br>
**Status:** Migrated to `Sources/Swift/Services/Pandora/` (verified 2026-09-16)

### ✅ AudioStreamer.swift

**Historical reason:** CoreAudio wrapper, streaming engine - working, stable<br>
**Status:** Migrated to `Sources/Swift/Services/Audio/AudioStreamer.swift` (verified 2026-09-16)

---

## Progress Tracking

**Total Tasks:** 11<br>
**Completed:** 11 ✅<br>
**In Progress:** 0<br>
**Not Started:** 0

**Completed Tasks:**

- ✅ Task 1: Migrate Notifications.{h,m} to Swift (1 hour)
- ✅ Task 2: Migrate HermesConstants.h
- ✅ Task 3: Delete Keychain.{h,m}
- ✅ Task 4: Migrate ImageLoader.{h,m}
- ✅ Task 5: Migrate NetworkConnection.{h,m}
- ✅ Task 6: Migrate URLConnection.{h,m}
- ✅ Task 7: Migrate Scrobbler.{h,m}
- ✅ Task 8: Migrate AppleScript.{h,m}
- ✅ Task 9: Delete HermesApp.{h,m}
- ✅ Task 10: Delete FileReader.{h,m} (5 minutes)
- ✅ Task 11: Delete NSDrawerWindow Workaround (5 minutes)

**Historical Estimated Total Effort:** 8-10 hours<br>
**Actual Time Spent:** Not recorded<br>
**Remaining Effort:** 0 for this migration checklist<br>
**Completion:** Implementation completed before the September 16, 2026 reconciliation

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
