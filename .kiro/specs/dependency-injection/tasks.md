# Implementation Plan: Dependency Injection System

## Overview

This plan implements a dependency injection system for Hermes to enable test isolation and restore 18 disabled tests. The implementation uses Swift protocols to abstract Pandora operations, allowing production code to use real implementations while tests use mock implementations. The codebase is now primarily Swift-based, with only MinimalAppDelegate serving as a minimal bridge for AppleScript support.

## Tasks

- [x] 1. Create protocol foundation
  - Create `Sources/Swift/Protocols/PandoraProtocol.swift` defining the protocol interface
  - Define all method signatures matching existing Pandora API (authentication, stations, playback, ratings, search)
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [x] 2. Implement Pandora protocol conformance
  - Create `Sources/Swift/Extensions/Pandora+Protocol.swift` extension
  - Make PandoraClient conform to PandoraProtocol
  - Add computed property wrappers where needed for protocol compatibility
  - _Requirements: 1.6_

- [ ] 3. Create mock implementation for testing
  - [x] 3.1 Create MockPandora class in `HermesTests/Mocks/MockPandora.swift`
    - Implement PandoraProtocol with call recording infrastructure
    - Add Call struct with Method enum covering all protocol operations
    - Store calls array with timestamps for verification
    - _Requirements: 3.1, 3.2_

  - [x] 3.2 Write property test for mock call recording
    - **Property 2: Mock call recording is complete**
    - **Validates: Requirements 3.2**

  - [x] 3.3 Add configurable behavior to MockPandora
    - Add properties for configuring return values (authenticateResult, fetchStationsResult, etc.)
    - Add properties for error simulation (authenticateError, etc.)
    - Add mockStations array and other mock data structures
    - Implement all protocol methods to use configured behavior
    - _Requirements: 3.3, 3.4_

  - [x] 3.4 Write property test for mock configuration
    - **Property 3: Mock configuration affects behavior**
    - **Validates: Requirements 3.3, 3.4**

  - [x] 3.5 Implement notification posting in MockPandora
    - Post "hermes.authenticated" notification on successful authentication
    - Post "hermes.stations" notification on successful fetchStations
    - Post "hermes.error" notification on errors
    - Match notification patterns from PandoraClient implementation
    - _Requirements: 3.1, 6.3, 6.4_

  - [x] 3.6 Add test helper methods to MockPandora
    - Implement reset() method to clear all state
    - Implement didCall() method to check for specific method calls
    - Implement callCount() method to count invocations
    - _Requirements: 3.6_

- [ ] 4. Refactor AppState for dependency injection
  - [x] 4.1 Add factory methods to AppState
    - Create static production() factory returning AppState with PandoraClient
    - Create static test() factory accepting PandoraProtocol parameter
    - Update shared singleton to use production() factory
    - _Requirements: 4.2, 4.3, 4.4, 4.5_

  - [x] 4.2 Update AppState initializer for DI
    - Change init to private and accept pandora: PandoraProtocol parameter
    - Add skipCredentialCheck parameter for test mode
    - Store pandora as instance property
    - Pass pandora to ViewModel initializers
    - _Requirements: 4.1, 4.6_

  - [ ] 4.3 Write unit tests for AppState factories
    - Test production() creates AppState with PandoraClient
    - Test test() creates AppState with mock Pandora
    - Verify singleton pattern still works for production
    - _Requirements: 4.2, 4.3, 4.6_

- [x] 5. Checkpoint - Verify foundation
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. Migrate LoginViewModel to dependency injection
  - [x] 6.1 Update LoginViewModel for DI
    - Add pandora: PandoraProtocol parameter with default value (AppState.shared.pandora)
    - Store pandora as private property
    - Update authenticate() method to use injected pandora instead of singleton
    - Maintain all existing functionality
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 6.2 Write property test for LoginViewModel DI
    - **Property 1: Dependency injection preserves instance identity**
    - **Validates: Requirements 2.3, 2.4, 2.5**

  - [x] 6.3 Restore LoginViewModel tests
    - Remove `disabled_` prefix from testInitialState
    - Remove `disabled_` prefix from testErrorMessageCleared_OnNewAuthentication
    - Update tests to create LoginViewModel with MockPandora
    - Verify tests pass without network requests or keychain access
    - _Requirements: 5.4, 5.5, 5.6, 5.7, 5.8_

- [x] 7. Migrate StationsViewModel to dependency injection
  - [x] 7.1 Update StationsViewModel for DI
    - Add pandora: PandoraProtocol parameter with default value
    - Store pandora as private property
    - Update all methods (loadStations, createStation, removeStation, renameStation) to use injected pandora
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 7.2 Restore StationsViewModel tests
    - Remove `disabled_` prefix from testSorting_ByName
    - Remove `disabled_` prefix from testSearch_EmptyString_ReturnsAll
    - Remove `disabled_` prefix from testStartRenameStation_SetsState
    - Update tests to use MockPandora with configured mock stations
    - Verify tests pass without side effects
    - _Requirements: 5.2, 5.5, 5.6, 5.7, 5.8_

- [x] 8. Restore HistoryViewModel tests
  - [x] 8.1 Update HistoryViewModel test setup
    - Create test AppState with MockPandora in setUp
    - Pass test AppState to HistoryViewModel if needed
    - Ensure no Pandora authentication is triggered during test initialization
    - _Requirements: 5.1, 5.5, 5.6, 5.7_

  - [x] 8.2 Restore all 15 HistoryViewModel tests
    - Remove `disabled_` prefix from all 15 test methods
    - Update tests to use test AppState setup
    - Verify all tests pass without production API calls
    - _Requirements: 5.1, 5.8_

- [x] 9. Migrate StationArtworkLoader to dependency injection
  - [x] 9.1 Update StationArtworkLoader for DI
    - Change configure(with:) parameter type from Pandora to PandoraProtocol
    - Update internal pandora property type to PandoraProtocol
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x] 9.2 Restore StationArtworkLoader test
    - Remove `disabled_` prefix from testCacheFileFormat_HandlesEmptyGenres
    - Update test to use MockPandora
    - Verify test passes without side effects
    - _Requirements: 5.3, 5.5, 5.6, 5.7, 5.8_

- [x] 10. Checkpoint - Verify all restored tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Create test utilities and documentation
  - [x] 11.1 Create test helper utilities
    - Create `HermesTests/Utilities/TestHelpers.swift`
    - Add AppState.testInstance() helper returning (appState, mockPandora) tuple
    - Add ViewModel.testInstance() helpers for each ViewModel
    - Add convenience functions for creating mock stations and songs
    - _Requirements: 3.6_

  - [x] 11.2 Write unit tests for test helpers
    - Test that testInstance() helpers create proper test instances
    - Test that helpers return both instance and mock correctly
    - _Requirements: 3.6_

- [x] 12. Add comprehensive property tests
  - [x] 12.1 Write property test for test isolation
    - **Property 4: Test isolation prevents side effects**
    - **Validates: Requirements 3.5, 5.5, 5.6, 5.7**

  - [x] 12.2 Write property test for backward compatibility
    - **Property 5: Backward compatibility preservation**
    - **Validates: Requirements 2.6, 6.1, 6.5**

  - [x] 12.3 Write property test for notification bridge
    - **Property 6: Notification bridge integrity**
    - **Validates: Requirements 6.3, 6.4**
    - Test that PandoraClient and MockPandora post consistent notifications
    - Verify Swift ViewModels receive notifications correctly

- [x] 13. Verify AppleScript integration
  - [x] 13.1 Test AppleScript support still functions
    - Verify MinimalAppDelegate provides PlaybackController access for AppleScript commands
    - Verify AppleScript commands (play, pause, skip, etc.) work with DI-enabled PlaybackController
    - Test that AppleScript properties (volume, playbackState, currentSong) still work
    - _Requirements: 6.1, 6.2, 6.5_

- [x] 14. Final validation and documentation
  - [x] 14.1 Run full test suite validation
    - Run complete test suite and verify all tests pass
    - Verify all 18 restored tests pass without failures
    - Verify no network requests occur during test execution
    - Verify no keychain access occurs during test execution
    - Verify production app still works normally
    - _Requirements: 5.8_

  - [x] 14.2 Add documentation and examples
    - Add inline documentation to PandoraProtocol with usage examples
    - Add documentation to MockPandora explaining configuration options
    - Document test helper functions with usage examples
    - Add comments explaining DI pattern for future component migration
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

## Notes

- Tasks marked with `*` are optional property-based and integration tests
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
- Property tests validate universal correctness properties with minimum 100 iterations
- Unit tests validate specific examples, edge cases, and integration points
- The codebase is now primarily Swift-based with modern architecture
- MinimalAppDelegate serves only as a minimal bridge for AppleScript support
- All Pandora API, audio streaming, and playback logic is in Swift
