# Implementation Plan: Full Swift Migration

## Overview

This plan migrates all remaining Objective-C code to Swift in 5 phases, achieving a 100% Swift codebase with CryptoSwift for encryption. Each phase builds on the previous and includes verification checkpoints.

## Tasks

- [x] 1. Phase 1: Foundation
  - [x] 1.1 Add CryptoSwift dependency via Swift Package Manager
    - Add package dependency to Xcode project
    - Verify package resolves and builds
    - _Requirements: 6.6_

  - [x] 1.2 Implement PandoraCrypto module
    - Create `Sources/Swift/Services/Pandora/PandoraCrypto.swift`
    - Implement `encrypt(_ data: Data, key: String) throws -> String`
    - Implement `decrypt(_ hexString: String, key: String) throws -> Data`
    - Use CryptoSwift's Blowfish with ECB mode and zero padding
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 1.3 Write property test for encryption round-trip
    - **Property 1: Encryption round-trip**
    - Test that encrypt then decrypt returns original data
    - Test with known Pandora encryption vectors
    - Test with random data (100+ iterations)
    - **Validates: Requirements 6.2, 6.3, 6.4**

  - [x] 1.4 Update DI infrastructure in AppState
    - Modify `AppState.init` to accept `PandoraProtocol` parameter
    - Add `AppState.create(pandora:)` factory method
    - Update `AppState.shared` to use factory
    - _Requirements: 8.1, 8.6_

  - [x] 1.5 Update StationsViewModel for DI
    - Ensure `StationsViewModel` accepts `PandoraProtocol` via initializer
    - Verify existing tests still pass with MockPandora
    - _Requirements: 8.2, 8.5_

  - [x] 1.6 Update PlayerViewModel for DI
    - PlayerViewModel uses PlaybackController for Pandora operations
    - No direct Pandora dependency needed (delegated to controller)
    - _Requirements: 8.3_

- [x] 2. Checkpoint - Phase 1 Complete
  - All tests pass
  - CryptoSwift integration verified
  - DI changes don't break existing functionality

- [x] 3. Phase 2: Audio Layer
  - [x] 3.1 Create AudioStreamer Swift implementation
    - Create `Sources/Swift/Services/Audio/AudioStreamer.swift`
    - Define `AudioStreamerState` enum with all states (initialized, waitingForData, waitingForQueueToStart, playing, paused, done, stopped)
    - Define `AudioStreamerError` enum with all error cases
    - Define `AudioStreaming` protocol
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 3.2 Implement AudioStreamer core functionality
    - Implement CFReadStream HTTP streaming with proxy support
    - Implement AudioFileStream parsing callbacks
    - Implement AudioQueue playback management
    - Implement buffer management with thread safety (DispatchQueue or actors)
    - _Requirements: 2.4, 2.5, 2.6, 2.7_

  - [x] 3.3 Implement AudioStreamer timeout handling
    - Implement configurable timeout interval
    - Handle timeout errors appropriately
    - _Requirements: 2.7_

  - [x] 3.4 Implement AudioStreamer notifications
    - Post `ASStatusChangedNotification` on state changes
    - Post `ASBitrateReadyNotification` when bitrate is calculated
    - _Requirements: 2.8_

  - [x] 3.5 Write property test for AudioStreamer state transitions
    - **Property 5: Playback state machine (partial)**
    - Test valid state transitions (initialized → playing → paused → playing → stopped)
    - Test invalid transitions are rejected
    - **Validates: Requirements 2.2**

  - [x] 3.6 Create Playlist Swift implementation
    - Create `Sources/Swift/Services/Audio/Playlist.swift`
    - Define `PlaylistProtocol`
    - Implement song queue management (addSong, clearSongList)
    - Implement automatic advancement on song completion
    - _Requirements: 3.1, 3.2_

  - [x] 3.7 Implement Playlist volume and progress
    - Implement volume propagation to all streamers
    - Implement progress and duration calculations
    - _Requirements: 3.3, 3.4_

  - [x] 3.8 Implement Playlist notifications
    - Post `ASNewSongPlaying` on song advancement
    - Post `ASNoSongsLeft` when queue is empty
    - Post `ASRunningOutOfSongs` when queue is low
    - Post `ASStreamError` on stream errors
    - _Requirements: 3.2_

  - [x] 3.9 Write property test for Playlist invariants
    - **Property 4: Playlist invariants**
    - Test next() advances correctly or posts noSongsLeft
    - Test volume propagation to active streamer
    - Test progress <= duration invariant
    - **Validates: Requirements 3.2, 3.3, 3.4**

  - [x] 3.10 Integrate Swift AudioStreamer with existing code
    - Update bridging header temporarily if needed
    - Ensure existing PlaybackController can use new AudioStreamer
    - _Requirements: 3.5_

  - [x] 3.11 Delete Objective-C AudioStreamer files
    - Remove `Sources/AudioStreamer/AudioStreamer.h`
    - Remove `Sources/AudioStreamer/AudioStreamer.m`
    - Remove `Sources/AudioStreamer/` directory
    - Update Xcode project references
    - _Requirements: 1.1_
    - **COMPLETED**: All AudioStreamer Objective-C files successfully deleted

- [x] 4. Checkpoint - Phase 2 Complete
  - All tests pass
  - Audio streaming works end-to-end
  - Play/pause/stop/seek functionality verified
  - Volume control verified
  - **NOTE**: macOS 26 SDK compatibility issue in Pandora.m resolved (subscript syntax on `id` types)

- [x] 5. Phase 3: API Layer
  - [x] 5.1 Create PandoraClient Swift implementation
    - Create `Sources/Swift/Services/Pandora/PandoraClient.swift`
    - Implement `PandoraProtocol` conformance
    - Implement internal state (partnerId, partnerAuthToken, userAuthToken, userId, syncTime)
    - Use existing HTTPClient for network requests
    - _Requirements: 4.1, 4.10_

  - [x] 5.2 Implement PandoraClient authentication
    - Implement `doPartnerLogin` with sync time handling
    - Implement `authenticate` with user login flow
    - Implement `isAuthenticated`, `logout`, `logoutNoNotify`
    - Use PandoraCrypto for encryption/decryption
    - _Requirements: 4.2_

  - [x] 5.3 Implement PandoraClient station operations
    - Implement `fetchStations`
    - Implement `createStation`, `removeStation`, `renameStation`
    - Implement `fetchStationInfo`, `fetchGenreStations`
    - Implement `sortStations`
    - _Requirements: 4.3_

  - [x] 5.4 Implement PandoraClient song operations
    - Implement `rateSong`, `tiredOfSong`, `deleteRating`
    - Implement `fetchPlaylistForStation`
    - _Requirements: 4.4, 4.5_

  - [x] 5.5 Implement PandoraClient search and seeds
    - Implement `search`
    - Implement `addSeed`, `removeSeed`, `deleteFeedback`
    - _Requirements: 4.6, 4.7_

  - [x] 5.6 Implement PandoraClient notifications
    - Post all existing notifications with correct userInfo
    - Ensure notification names match existing constants in NotificationNames.swift
    - _Requirements: 4.8_

  - [x] 5.7 Implement async/await wrappers
    - Use Swift async/await for all network operations
    - Maintain callback-based API for backward compatibility during migration
    - _Requirements: 4.9_

  - [x] 5.8 Write property test for API response parsing
    - **Property 2: API response parsing correctness**
    - Test parsing of station, song, search responses
    - Use mock JSON fixtures
    - Verify all required fields are populated
    - **Validates: Requirements 4.3, 4.4, 4.5, 4.6, 4.7**

  - [x] 5.9 Write property test for notification consistency
    - **Property 3: Notification consistency**
    - Test that all state-changing operations post correct notifications
    - Verify notification userInfo contains expected keys
    - **Validates: Requirements 4.8**

  - [x] 5.10 Create Station Swift implementation
    - Create `Sources/Swift/Models/Station.swift` (update existing StationModel or create new)
    - Extend Playlist class for audio integration
    - Implement all Station properties (name, token, stationId, created, isShared, allowRename, allowAddMusic, isQuickMix, artUrl, genres)
    - Implement Codable conformance
    - _Requirements: 5.1, 5.3_

  - [x] 5.11 Implement Station radio integration
    - Implement `setRadio`, `streamNetworkError`, `applyTrackGain`
    - Implement static registry methods (station(forToken:), addStation, removeStation)
    - _Requirements: 5.4_

  - [x] 5.12 Write property test for Station-StationModel bridging
    - **Property 7: Station-StationModel bridging**
    - Test that StationModel preserves all Station properties
    - Test round-trip: Station → StationModel → Station
    - **Validates: Requirements 5.2**

  - [x] 5.13 Update PandoraDevice to pure Swift
    - Update `Sources/Swift/Models/PandoraDevice.swift`
    - Remove any Objective-C dependencies
    - Ensure device configurations are correct
    - _Requirements: 4.2_

  - [x] 5.14 Delete Objective-C Pandora files
    - Remove `Sources/Pandora/Pandora.h`, `Sources/Pandora/Pandora.m`
    - Remove `Sources/Pandora/Station.h`, `Sources/Pandora/Station.m`
    - Remove `Sources/Pandora/Crypt.h`, `Sources/Pandora/Crypt.m`
    - Remove `Sources/Pandora/PandoraDevice.h`, `Sources/Pandora/PandoraDevice.m`
    - Remove `Sources/Pandora/` directory
    - Update Xcode project references
    - _Requirements: 1.1_
    - **COMPLETED**: All Pandora Objective-C files successfully deleted

- [x] 6. Checkpoint - Phase 3 Complete
  - All tests pass
  - Authentication verified working
  - Station operations verified working
  - Tested with real Pandora account
  - All Pandora Objective-C code successfully deleted

- [x] 7. Phase 4: Controllers
  - [x] 7.1 Create PlaybackController Swift implementation
    - Create `Sources/Swift/Services/PlaybackController.swift`
    - Mark as `@MainActor` for UI state
    - Implement as `ObservableObject` with `@Published` properties
    - _Requirements: 7.1_
    - **COMPLETED**: Swift implementation created and integrated

  - [x] 7.2 Implement PlaybackController station management
    - Implement `playStation`, `reset`, `saveState`
    - Integrate with Swift Station and Playlist
    - _Requirements: 7.2, 7.9_

  - [x] 7.3 Implement PlaybackController playback controls
    - Implement `play`, `pause`, `stop`, `playpause`, `next`
    - Post state change notifications
    - _Requirements: 7.3_

  - [x] 7.4 Implement PlaybackController song rating
    - Implement `rate`, `likeCurrent`, `dislikeCurrent`, `tiredOfCurrent`
    - Integrate with PandoraClient
    - _Requirements: 7.4_

  - [x] 7.5 Implement PlaybackController volume control
    - Implement `volume` property with didSet
    - Implement `increaseVolume`, `decreaseVolume`
    - _Requirements: 7.5_

  - [x] 7.6 Implement PlaybackController media keys
    - Implement `setupMediaKeys` with MPRemoteCommandCenter
    - Handle play/pause, next track commands
    - Update Now Playing info
    - _Requirements: 7.6_

  - [x] 7.7 Implement PlaybackController system events
    - Handle screensaver start/stop
    - Handle screen lock/unlock
    - Implement `pausedByScreensaver`, `pausedByScreenLock`
    - _Requirements: 7.7_

  - [x] 7.8 Implement PlaybackController notifications
    - Post `PlaybackStateDidChangeNotification`
    - Post `PlaybackSongDidChangeNotification`
    - Post `PlaybackProgressDidChangeNotification`
    - Post `PlaybackArtDidLoadNotification`
    - _Requirements: 7.8_

  - [x] 7.9 Write property test for playback state machine
    - **Property 5: Playback state machine**
    - Test all valid state transitions (play → pause → play → stop)
    - Test that invalid transitions are handled gracefully
    - **Validates: Requirements 7.3**

  - [x] 7.10 Write property test for state persistence
    - **Property 6: State persistence round-trip**
    - Test save then restore produces equivalent state
    - Test station, volume, position are preserved
    - **Validates: Requirements 7.9**

  - [x] 7.11 Delete Objective-C PlaybackController files
    - Remove `Sources/Controllers/PlaybackController.h`
    - Remove `Sources/Controllers/PlaybackController.m`
    - Update Xcode project references
    - _Requirements: 1.1_

- [x] 8. Checkpoint - Phase 4 Complete
  - All tests pass
  - Playback controls verified working
  - Media keys verified working
  - Screensaver/lock pause behavior tested
  - PlaybackController Objective-C code successfully deleted

- [x] 9. Phase 5: Cleanup
  - [x] 9.1 Complete LastFMService migration
    - Update to use Swift Song type directly (remove NSObject casting)
    - Replace CommonCrypto MD5 with CryptoSwift md5()
    - _Requirements: 9.1, 9.2_

  - [x] 9.2 Create String+MD5 extension with CryptoSwift
    - Create extension using CryptoSwift's md5() method
    - Replace NSString+FMEngine MD5 functionality
    - _Requirements: 9.3_

  - [x] 9.3 Delete FMEngine Objective-C files
    - Remove `ImportedSources/FMEngine/FMEngine.h`
    - Remove `ImportedSources/FMEngine/FMEngine.m`
    - Remove `ImportedSources/FMEngine/NSString+FMEngine.h`
    - Remove `ImportedSources/FMEngine/NSString+FMEngine.m`
    - Update Xcode project references
    - _Requirements: 9.3, 9.4_

  - [x] 9.4 Delete blowfish C library
    - Remove `ImportedSources/blowfish/blowfish.c`
    - Remove `ImportedSources/blowfish/blowfish.h`
    - Remove `ImportedSources/blowfish/` directory
    - Update Xcode project references
    - _Requirements: 6.5, 10.4_

  - [x] 9.5 Delete SPMediaKeyTap (unused)
    - Remove `ImportedSources/SPMediaKeyTap/` directory (if exists)
    - Update Xcode project references
    - **COMPLETED**: Already removed or never present

  - [x] 9.6 Remove bridging header
    - Delete `Sources/Hermes-Bridging-Header.h`
    - Remove bridging header setting from Xcode build settings
    - _Requirements: 10.1, 10.3_

  - [x] 9.7 Clean up remaining Objective-C artifacts
    - Remove `Sources/Hermes_Prefix.pch` if no longer needed
    - Remove `Sources/HermesConstants.h` if no longer needed
    - Verify no Objective-C imports remain in project
    - _Requirements: 10.2_
    - **COMPLETED**: All Objective-C artifacts successfully removed

  - [x] 9.8 Update documentation
    - Update `Documentation/structure.md` to reflect new architecture
    - Update any other affected documentation
    - _Requirements: 12.5_

- [x] 10. Final Checkpoint - Migration Complete
  - [x] 10.1 Delete AudioStreamer Objective-C files (task 3.11)
    - **COMPLETED**: All AudioStreamer Objective-C files successfully deleted
  - [x] 10.2 Verify 100% Swift codebase
    - **VERIFIED**: No .m, .h, or .c files remain in Sources/ or ImportedSources/
  - [x] 10.3 Verify no bridging header configured
    - **VERIFIED**: Bridging header removed from build settings
  - [x] 10.4 Run all tests
    - Ensure all unit tests pass
    - Ensure all property-based tests pass
  - [x] 10.5 Full end-to-end testing
    - Verify authentication flow
    - Verify station operations (create, rename, delete)
    - Verify playback controls (play, pause, stop, next)
    - Verify song rating (like, dislike, tired)
    - Verify volume control
    - Verify media keys integration
  - [x] 10.6 Build verification
    - Run `make` successfully (Debug configuration)
    - Run `make CONFIGURATION=Release` successfully (Release configuration)
    - Verify no build warnings or errors

## Migration Status

**🎉 MIGRATION COMPLETE - 100% Swift Codebase Achieved! 🎉**

All 5 phases have been successfully completed:

- ✅ **Phase 1: Foundation** - CryptoSwift integration, DI infrastructure
- ✅ **Phase 2: Audio Layer** - AudioStreamer and Playlist migrated to Swift
- ✅ **Phase 3: API Layer** - PandoraClient and Station migrated to Swift
- ✅ **Phase 4: Controllers** - PlaybackController migrated to Swift
- ✅ **Phase 5: Cleanup** - All Objective-C artifacts removed

**Final Verification:**

- ✅ Zero Objective-C files remain (.m, .h, .c)
- ✅ Bridging header removed
- ✅ All ImportedSources cleaned up (blowfish, FMEngine)
- ✅ 100% Swift codebase with modern patterns (async/await, actors, protocols)
- ✅ CryptoSwift replaces legacy C encryption
- ✅ All tests passing
- ✅ Build succeeds in Debug and Release configurations

The Hermes codebase is now fully modernized with Swift!

## Notes

- All phases (1-5) are complete
- Property tests run with minimum 100 iterations
- All tests reference their design document property number
- **Migration Status**: ✅ 100% COMPLETE - Fully Swift codebase achieved!
- Zero Objective-C files remain in the project
- Modern Swift patterns implemented throughout (async/await, actors, protocols)
- CryptoSwift successfully replaced legacy C encryption library
