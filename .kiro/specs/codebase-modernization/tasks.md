# Implementation Plan: Codebase Modernization

## Overview

This implementation plan breaks down the Hermes codebase modernization into discrete, executable tasks organized across three phases. The codebase is **already 100% Swift/SwiftUI** with no Objective-C code. This plan focuses on refining the existing Swift codebase by adopting Swift 5.9+ features, improving organization, and enhancing testability.

The plan follows a phased approach:

- **Phase 1 (1-2 weeks)**: Foundation - Critical consolidations and standardizations
- **Phase 2 (1 month)**: Modern Patterns - Swift 5.9+ adoption and testing infrastructure
- **Phase 3 (2-3 months)**: Complete Refinement - Code organization and optimization

## Tasks

### Phase 1: Foundation (1-2 weeks)

- [x] 1. Remove Duplicate Protocol Definition
  - [x] 1.1 Verify PandoraProtocol locations
    - Search for all PandoraProtocol definitions in the codebase
    - Confirm PandoraProtocol.swift is the canonical version
    - Document any differences between definitions
    - _Requirements: 1.1, 1.2_
  
  - [x] 1.2 Remove inline protocol definition from PandoraClient.swift
    - Remove the @objc protocol PandoraProtocol definition from PandoraClient.swift
    - Keep only the extension that declares conformance
    - Verify PandoraClient.swift imports PandoraProtocol.swift
    - _Requirements: 1.2, 1.3_
  
  - [x] 1.3 Verify compilation and functionality
    - Build the project and verify no errors
    - Run existing tests to ensure functionality unchanged
    - _Requirements: 1.3, 1.4_

- [x] 2. Create Centralized UserDefaults Keys
  - [x] 2.1 Create UserDefaultsKeys.swift
    - Create `Sources/Swift/Utilities/UserDefaultsKeys.swift`
    - Define struct with static string constants for all keys
    - Group by category (Authentication, Playback, Preferences, Window State, etc.)
    - Use existing key names for backward compatibility
    - _Requirements: 6.1, 6.2_
  
  - [x] 2.2 Replace UserDefaults string literals with constants
    - Search codebase for UserDefaults.standard calls with string literals
    - Replace with UserDefaultsKeys constants
    - Verify backward compatibility (same key strings)
    - _Requirements: 6.3, 6.5_
  
  - [x] 2.3 Write tests for UserDefaults key usage
    - Test that keys are accessible and correct
    - Test backward compatibility with existing saved preferences
    - _Requirements: 6.1, 6.4, 6.5_

- [x] 3. Verify Notification Names Consistency
  - [x] 3.1 Audit notification usage
    - Search for NotificationCenter.default.post calls
    - Search for NotificationCenter.default.addObserver calls
    - Verify all use typed Notification.Name constants from NotificationNames.swift
    - Document any string literals found
    - _Requirements: 4.1, 4.2_
  
  - [x] 3.2 Replace any remaining string literals
    - Replace string literals with typed constants
    - Add any missing notification names to NotificationNames.swift
    - _Requirements: 4.2, 4.3_
  
  - [x] 3.3 Write test to verify typed notification usage
    - Create test that scans for notification string literals
    - Assert all notifications use typed constants
    - _Requirements: 4.1, 4.2_

- [x] 4. Plan Model Consolidation Strategy
  - [x] 4.1 Audit Song and SongModel implementations
    - Document all properties in Song.swift
    - Document all properties in SongModel.swift
    - Identify unique functionality in each
    - Determine consolidation approach
    - _Requirements: 2.1_
  
  - [x] 4.2 Audit Station and StationModel implementations
    - Document all properties in Station.swift
    - Document all properties in StationModel.swift
    - Identify unique functionality in each
    - Determine consolidation approach
    - _Requirements: 2.2_
  
  - [x] 4.3 Document model consolidation plan
    - Create migration plan for Song/SongModel consolidation
    - Create migration plan for Station/StationModel consolidation
    - Identify all files that reference wrapper models
    - Plan testing strategy
    - _Requirements: 2.1, 2.2, 2.5_

- [x] 5. Phase 1 Checkpoint
  - Run full test suite and verify all tests pass
  - Verify no compilation warnings
  - Verify app launches and basic functionality works
  - Document Phase 1 completion and any issues encountered
  - _Requirements: 25.1, 25.2, 25.3, 25.4_

### Phase 2: Modern Patterns (1 month)

- [x] 6. Consolidate Song and SongModel
  - [x] 6.1 Add @Observable to Song.swift
    - Import Observation framework
    - Add @Observable macro to Song class
    - Remove any @objc annotations that conflict
    - Keep NSCoding support for history persistence
    - _Requirements: 2.1, 10.1_
  
  - [x] 6.2 Migrate views from SongModel to Song
    - Update PlayerView to use Song directly
    - Update HistoryListView to use Song directly
    - Update any other views using SongModel
    - _Requirements: 2.1, 2.4_
  
  - [x] 6.3 Migrate view models from SongModel to Song
    - Update PlayerViewModel to use Song
    - Update HistoryViewModel to use Song
    - Remove SongModel references
    - _Requirements: 2.1, 2.4_
  
  - [x] 6.4 Delete SongModel.swift
    - Verify no remaining references to SongModel
    - Delete Sources/Swift/Models/SongModel.swift
    - Run tests to verify functionality
    - _Requirements: 2.1, 2.4_

- [x] 7. Consolidate Station and StationModel
  - [x] 7.1 Add @Observable to Station.swift
    - Import Observation framework
    - Add @Observable macro to Station class
    - Preserve Playlist inheritance and playback functionality
    - Keep NSSecureCoding support
    - _Requirements: 2.2, 10.1_
  
  - [x] 7.2 Migrate views from StationModel to Station
    - Update StationsListView to use Station directly
    - Update SidebarView to use Station directly
    - Update any other views using StationModel
    - _Requirements: 2.2, 2.4_
  
  - [x] 7.3 Migrate view models from StationModel to Station
    - Update StationsViewModel to use Station
    - Remove StationModel references
    - _Requirements: 2.2, 2.4_
  
  - [x] 7.4 Delete StationModel.swift
    - Verify no remaining references to StationModel
    - Delete Sources/Swift/Models/StationModel.swift
    - Run tests to verify functionality
    - _Requirements: 2.2, 2.4_

- [x] 8. Migrate View Models to @Observable
  - [x] 8.1 Convert AppState to @Observable
    - Replace ObservableObject with @Observable macro
    - Remove @Published wrappers
    - Verify state updates still trigger view refreshes
    - Test authentication flow
    - _Requirements: 10.1, 10.2, 10.4_
  
  - [x] 8.2 Convert PlayerViewModel to @Observable
    - Replace ObservableObject with @Observable macro
    - Remove @Published wrappers
    - Update views to remove @ObservedObject where appropriate
    - Test playback controls
    - _Requirements: 10.1, 10.2, 10.3_
  
  - [x] 8.3 Convert StationsViewModel to @Observable
    - Replace ObservableObject with @Observable macro
    - Remove @Published wrappers
    - Update views to remove @ObservedObject where appropriate
    - Test station management
    - _Requirements: 10.1, 10.2, 10.3_
  
  - [x] 8.4 Convert remaining view models to @Observable
    - Convert LoginViewModel to @Observable
    - Convert HistoryViewModel to @Observable
    - Convert StationAddViewModel to @Observable
    - Convert StationEditViewModel to @Observable
    - _Requirements: 10.1, 10.2, 10.3_
  
  - [x] 8.5 Write tests for @Observable state updates
    - Test state changes trigger view refreshes
    - Test no ObservableObject usage remains
    - _Requirements: 10.4, 10.5_

- [x] 9. Migrate Previews to #Preview Macro
  - [x] 9.1 Audit current preview usage
    - Search for PreviewProvider protocol usage
    - Search for #Preview macro usage
    - Document which files use which pattern
    - _Requirements: 12.1_
  
  - [x] 9.2 Convert all PreviewProvider to #Preview
    - Replace PreviewProvider protocol with #Preview macro
    - Preserve all preview configurations
    - Add descriptive names to previews
    - Create separate #Preview for each variant
    - _Requirements: 12.1, 12.2, 12.3, 12.4_
  
  - [x] 9.3 Verify all previews render correctly
    - Test each preview in Xcode
    - Fix any rendering issues
    - _Requirements: 12.5_

- [x] 10. Verify Image Loading Implementation
  - [x] 10.1 Review ImageCache.swift implementation
    - Verify uses URLSession with URLCache
    - Verify async/await patterns
    - Verify memory management and cache eviction
    - Document any improvements needed
    - _Requirements: 13.1, 13.2, 13.3_
  
  - [x] 10.2 Review image loading in views
    - Verify placeholder images for loading/error states
    - Verify consistent behavior across views
    - Document any improvements needed
    - _Requirements: 13.4, 13.5_

- [x] 11. Add Missing Test Coverage
  - [x] 11.1 Add tests for AudioStreamer
    - Test core streaming functionality
    - Test state transitions (stopped, playing, paused, buffering)
    - Test error handling
    - _Requirements: 20.1_
  
  - [x] 11.2 Add tests for Playlist management
    - Test adding songs to playlist
    - Test removing songs from playlist
    - Test playlist ordering
    - _Requirements: 20.2_
  
  - [x] 11.3 Add tests for ImageCache
    - Test cache hit/miss behavior
    - Test cache size limits
    - Test cache eviction
    - _Requirements: 20.3_

- [x] 12. Phase 2 Checkpoint
  - Run full test suite and verify all tests pass
  - Verify code coverage meets 80% for critical components
  - Verify no compilation warnings
  - Verify app functionality with new patterns
  - Document Phase 2 completion and improvements
  - _Requirements: 26.1, 26.2, 26.3, 26.4_

### Phase 3: Complete Modernization (2-3 months)

- [x] 13. Split AudioStreamer.swift (1910 lines)
  - [x] 13.1 Extract AudioStreamState
    - Create `Sources/Swift/Services/Audio/AudioStreamState.swift`
    - Move state management code (~150 lines)
    - _Requirements: 7.2_
  
  - [x] 13.2 Extract AudioStreamBuffer
    - Create `Sources/Swift/Services/Audio/AudioStreamBuffer.swift`
    - Move buffer management code (~200 lines)
    - _Requirements: 7.2_
  
  - [x] 13.3 Extract AudioStreamDecoder
    - Create `Sources/Swift/Services/Audio/AudioStreamDecoder.swift`
    - Move audio decoding code (~200 lines)
    - _Requirements: 7.2_
  
  - [x] 13.4 Extract AudioStreamOutput
    - Create `Sources/Swift/Services/Audio/AudioStreamOutput.swift`
    - Move audio output code (~150 lines)
    - _Requirements: 7.2_
  
  - [x] 13.5 Extract AudioStreamError
    - Create `Sources/Swift/Services/Audio/AudioStreamError.swift`
    - Move error types (~100 lines)
    - _Requirements: 7.2_
  
  - [x] 13.6 Refactor core AudioStreamer
    - Keep core streaming engine (~300 lines)
    - Update to use extracted components
    - Add MARK comments for organization
    - _Requirements: 7.2, 7.5_
  
  - [x] 13.7 Verify AudioStreamer tests still pass
    - Run all AudioStreamer tests
    - Verify functionality unchanged
    - _Requirements: 7.5_

- [x] 14. Split PandoraClient.swift (1597 lines)
  - [x] 14.1 Extract PandoraAuth
    - Create `Sources/Swift/Services/Pandora/PandoraAuth.swift`
    - Move authentication code (~200 lines)
    - _Requirements: 7.3_
  
  - [x] 14.2 Extract PandoraStations
    - Create `Sources/Swift/Services/Pandora/PandoraStations.swift`
    - Move station operations (~250 lines)
    - _Requirements: 7.3_
  
  - [x] 14.3 Extract PandoraPlayback
    - Create `Sources/Swift/Services/Pandora/PandoraPlayback.swift`
    - Move playback operations (~250 lines)
    - _Requirements: 7.3_
  
  - [x] 14.4 Extract PandoraNetwork
    - Create `Sources/Swift/Services/Pandora/PandoraNetwork.swift`
    - Move network layer (~250 lines)
    - _Requirements: 7.3_
  
  - [x] 14.5 Extract PandoraModels
    - Create `Sources/Swift/Services/Pandora/PandoraModels.swift`
    - Move response models (~200 lines)
    - _Requirements: 7.3_
  
  - [x] 14.6 Refactor core PandoraClient
    - Keep main client interface (~200 lines)
    - Update to use extracted components
    - Add MARK comments for organization
    - _Requirements: 7.3, 7.5_
  
  - [x] 14.7 Verify PandoraClient tests still pass
    - Run all PandoraClient tests
    - Verify functionality unchanged
    - _Requirements: 7.5_

- [x] 15. Split PlayerView.swift (500+ lines)
  - [x] 15.1 Extract AlbumArtworkView
    - Create `Sources/Swift/Views/Components/AlbumArtworkView.swift`
    - Move artwork display code (~80 lines)
    - Make configurable via parameters
    - _Requirements: 7.4, 8.1, 8.3_
  
  - [x] 15.2 Extract PlaybackControlsView
    - Create `Sources/Swift/Views/Components/PlaybackControlsView.swift`
    - Move play/pause/skip buttons (~100 lines)
    - Make configurable via parameters
    - _Requirements: 7.4, 8.1, 8.3_
  
  - [x] 15.3 Extract SongInfoView
    - Create `Sources/Swift/Views/Components/SongInfoView.swift`
    - Move song metadata display (~80 lines)
    - Make configurable via parameters
    - _Requirements: 7.4, 8.1, 8.3_
  
  - [x] 15.4 Extract RatingControlsView
    - Create `Sources/Swift/Views/Components/RatingControlsView.swift`
    - Move thumbs up/down/tired buttons (~80 lines)
    - Make configurable via parameters
    - _Requirements: 7.4, 8.1, 8.3_
  
  - [x] 15.5 Extract VolumeControlView
    - Create `Sources/Swift/Views/Components/VolumeControlView.swift`
    - Move volume slider (~60 lines)
    - Make configurable via parameters
    - _Requirements: 7.4, 8.1, 8.3_
  
  - [x] 15.6 Refactor core PlayerView
    - Keep main container (~100 lines)
    - Update to use extracted components
    - Add MARK comments for organization
    - _Requirements: 7.4, 7.5, 8.5_
  
  - [x] 15.7 Write tests for extracted components
    - Test components accept parameters
    - Test components render correctly
    - _Requirements: 8.3_

- [x] 16. Create Reusable Component Library
  - [x] 16.1 Create GlassButton component
    - Create `Sources/Swift/Views/Components/GlassButton.swift`
    - Implement with glass morphism effect
    - Make configurable (icon, size, action, enabled state)
    - Add #Preview examples
    - _Requirements: 8.1, 8.3_
  
  - [x] 16.2 Verify ImageCache implementation
    - Review existing `Sources/Swift/Utilities/ImageCache.swift`
    - Verify actor-based implementation
    - Verify memory management and eviction
    - Document any improvements needed
    - _Requirements: 13.1, 13.2, 13.3_
  
  - [x] 16.3 Write tests for ImageCache
    - Test cache hit/miss behavior
    - Test cache size limits
    - Test cache eviction
    - _Requirements: 13.3, 20.3_
  
  - [x] 16.4 Update all views to use reusable components
    - Replace custom buttons with GlassButton
    - Verify consistent styling across app
    - _Requirements: 8.5_

- [x] 17. Add Consistent MARK Comments
  - [x] 17.1 Add MARK comments to all Swift files
    - Follow pattern: Properties → Initializers → Lifecycle → Public Methods → Private Methods
    - Use `// MARK: - Section Name` format
    - Ensure Xcode jump bar navigation works
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [x] 18. Optimize Threading
  - [x] 18.1 Move heavy operations off main thread
    - Audit code for main thread blocking
    - Move image loading to background
    - Move API requests to background
    - Move parsing operations to background
    - _Requirements: 21.1, 21.2_
  
  - [x] 18.2 Ensure UI updates on main thread
    - Add @MainActor to view models
    - Verify async completion handlers dispatch to main
    - Add assertions for main thread UI updates
    - _Requirements: 21.3_
  
  - [x] 18.3 Write tests for threading
    - Test heavy operations don't block main thread
    - Test UI updates happen on main thread
    - _Requirements: 21.1, 21.3_

- [x] 19. Implement Notification Debouncing
  - [x] 19.1 Add debouncing to high-frequency notifications
    - Identify rapid-fire notifications (song progress, volume changes)
    - Apply Combine debounce operator
    - Use consistent debounce intervals (100ms)
    - Ensure latest value is processed
    - _Requirements: 22.1, 22.2, 22.3_
  
  - [x] 19.2 Verify debouncing with property tests
    - Run property tests for debouncing behavior
    - Verify frequency reduction
    - Verify latest value processing
    - _Requirements: 22.1, 22.3_

- [x] 20. Add DocC Documentation
  - [x] 20.1 Add documentation to public APIs
    - Document all public classes, structs, and protocols
    - Include summary, parameters, returns, throws sections
    - Use proper markdown formatting
    - Add usage examples for complex APIs
    - _Requirements: 23.1, 23.2, 23.3, 23.4_
  
  - [x] 20.2 Generate and verify DocC documentation
    - Run DocC build
    - Review generated documentation
    - Fix any formatting issues
    - _Requirements: 23.5_

- [x] 21. Update Outdated Comments
  - [x] 21.1 Audit and update comments
    - Search for references to deprecated APIs
    - Update comments describing outdated behavior
    - Implement or remove TODO comments
    - Remove misleading comments
    - Ensure comments add value
    - _Requirements: 24.1, 24.2, 24.3, 24.4, 24.5_

- [x] 22. Phase 3 Final Checkpoint
  - Run full test suite and verify all tests pass
  - Verify code coverage meets 90% for Swift code
  - Verify no files exceed 800 lines
  - Verify no compilation warnings
  - Generate DocC documentation
  - Run performance benchmarks
  - Create final completion report
  - Update architecture documentation
  - _Requirements: 27.1, 27.2, 27.3, 27.4, 27.5_

## Notes

- All tasks are required for comprehensive modernization
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at phase boundaries
- Property tests validate universal correctness properties with minimum 100 iterations
- Unit tests validate specific examples, edge cases, and error conditions
- All tests use Swift Testing framework with @Test attributes
- File splitting maintains all existing functionality and tests
- Component extraction follows single-responsibility principle
- Threading optimization ensures responsive UI
- Documentation follows DocC standards
