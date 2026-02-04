# Implementation Plan: Dependency Injection System

## Overview

This plan implements a dependency injection system for Hermes to enable test isolation and restore 18 disabled tests. The implementation follows a phased approach to ensure backward compatibility while gradually migrating components to use dependency injection.

## Tasks

- [x] 1. Create protocol foundation
  - Create `Sources/Swift/Protocols/PandoraProtocol.swift` with protocol definition
  - Define all method signatures matching existing Pandora API
  - Include authentication, station management, playback, and song operations
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [x] 2. Implement Pandora protocol conformance
  - Create `Sources/Swift/Extensions/Pandora+Protocol.swift`
  - Add extension making Pandora conform to PandoraProtocol
  - Add computed property wrappers for Objective-C methods where needed
  - Verify compilation succeeds with no errors
  - _Requirements: 1.6_

- [ ] 3. Create mock implementation
  - [x] 3.1 Create `HermesTests/Mocks/MockPandora.swift`
    - Implement PandoraProtocol with call recording
    - Add Call struct with Method enum for all operations
    - Store calls array with timestamps
    - _Requirements: 3.1, 3.2_
  
  - [~] 3.2 Write property test for mock call recording
    - **Property 2: Mock call recording is complete**
    - **Validates: Requirements 3.2**
  
  - [~] 3.3 Add configurable behavior to MockPandora
    - Add properties for return values (authenticateResult, fetchStationsResult, etc.)
    - Add properties for error simulation (authenticateError, etc.)
    - Add mockStations array for station list simulation
    - _Requirements: 3.3, 3.4_
  
  - [~] 3.4 Write property test for mock configuration
    - **Property 3: Mock configuration affects behavior**
    - **Validates: Requirements 3.3, 3.4**
  
  - [~] 3.5 Implement notification posting in MockPandora
    - Post "hermes.authenticated" on successful authentication
    - Post "hermes.stations" on successful fetchStations
    - Post "hermes.error" on errors
    - Match notification patterns from real Pandora
    - _Requirements: 3.1, 6.3, 6.4_
  
  - [~] 3.6 Add test helper methods to MockPandora
    - Implement reset() to clear state
    - Implement didCall() to check for specific calls
    - Implement callCount() to count method invocations
    - _Requirements: 3.6_

- [ ] 4. Refactor AppState for dependency injection
  - [~] 4.1 Add factory methods to AppState
    - Create static production() factory method
    - Create static test() factory method accepting PandoraProtocol
    - Update shared singleton to use production() factory
    - _Requirements: 4.2, 4.3, 4.4, 4.5_
  
  - [~] 4.2 Update AppState initializer
    - Change init to accept pandora: PandoraProtocol parameter
    - Add skipCredentialCheck parameter for test mode
    - Store pandora as instance property
    - Pass pandora to ViewModel initializers
    - _Requirements: 4.1, 4.6_
  
  - [~] 4.3 Write unit tests for AppState factories
    - Test production() creates AppState with real Pandora
    - Test test() creates AppState with mock Pandora
    - Test singleton pattern still works
    - _Requirements: 4.2, 4.3, 4.6_

- [ ] 5. Checkpoint - Verify foundation is solid
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. Migrate LoginViewModel to dependency injection
  - [~] 6.1 Update LoginViewModel initializer
    - Add pandora: PandoraProtocol parameter with default value
    - Store pandora as private property
    - Update authenticate() to use injected pandora
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
  
  - [~] 6.2 Write property test for LoginViewModel DI
    - **Property 1: Dependency injection preserves instance identity**
    - **Validates: Requirements 2.3, 2.4, 2.5**
  
  - [~] 6.3 Restore LoginViewModel tests
    - Remove `disabled_` prefix from testInitialState
    - Remove `disabled_` prefix from testErrorMessageCleared_OnNewAuthentication
    - Update tests to use MockPandora
    - Verify tests pass without side effects
    - _Requirements: 5.4, 5.5, 5.6, 5.7, 5.8_

- [ ] 7. Migrate StationsViewModel to dependency injection
  - [~] 7.1 Update StationsViewModel initializer
    - Add pandora: PandoraProtocol parameter with default value
    - Store pandora as private property
    - Update all methods to use injected pandora
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
  
  - [~] 7.2 Restore StationsViewModel tests
    - Remove `disabled_` prefix from testSorting_ByName
    - Remove `disabled_` prefix from testSearch_EmptyString_ReturnsAll
    - Remove `disabled_` prefix from testStartRenameStation_SetsState
    - Update tests to use MockPandora
    - Verify tests pass without side effects
    - _Requirements: 5.2, 5.5, 5.6, 5.7, 5.8_

- [ ] 8. Restore HistoryViewModel tests
  - [~] 8.1 Update test setup to use test AppState
    - Create test AppState with MockPandora in setUp
    - Ensure HistoryViewModel doesn't trigger Pandora authentication
    - _Requirements: 5.1, 5.5, 5.6, 5.7_
  
  - [~] 8.2 Restore all 15 HistoryViewModel tests
    - Remove `disabled_` prefix from testHistoryLimit_EnforcesMaximum
    - Remove `disabled_` prefix from testHistoryLimit_MaintainsOrder
    - Remove `disabled_` prefix from testAddSong_InsertsAtBeginning
    - Remove `disabled_` prefix from testAddSong_RemovesDuplicates
    - Remove `disabled_` prefix from testSaveHistory_CreatesFile
    - Remove `disabled_` prefix from testSaveAndLoad_PreservesHistory
    - Remove `disabled_` prefix from testAutoSave_OnAddSong
    - Remove `disabled_` prefix from testClearHistory_RemovesAllItems
    - Remove `disabled_` prefix from testClearHistory_SavesEmptyState
    - Remove `disabled_` prefix from testSelection_InitiallyNil
    - Remove `disabled_` prefix from testSelection_CanSelectItem
    - Remove `disabled_` prefix from testOpenSongOnPandora_WithValidURL
    - Remove `disabled_` prefix from testOpenArtistOnPandora_WithValidURL
    - Remove `disabled_` prefix from testOpenAlbumOnPandora_WithValidURL
    - Remove `disabled_` prefix from testShowLyrics_WithValidSong
    - Remove `disabled_` prefix from testAddSong_PostsDistributedNotification
    - Verify all tests pass without side effects
    - _Requirements: 5.1, 5.8_

- [ ] 9. Migrate StationArtworkLoader to dependency injection
  - [~] 9.1 Update StationArtworkLoader.configure(with:)
    - Change parameter type from Pandora to PandoraProtocol
    - Update internal pandora property type
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
  
  - [~] 9.2 Restore StationArtworkLoader test
    - Remove `disabled_` prefix from testCacheFileFormat_HandlesEmptyGenres
    - Update test to use MockPandora
    - Verify test passes without side effects
    - _Requirements: 5.3, 5.5, 5.6, 5.7, 5.8_

- [ ] 10. Checkpoint - Verify all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Create test utilities and helpers
  - [~] 11.1 Create `HermesTests/Utilities/TestHelpers.swift`
    - Add AppState.testInstance() helper
    - Add ViewModel.testInstance() helpers for each ViewModel
    - Add convenience functions for creating mock stations and songs
    - _Requirements: 3.6_
  
  - [~] 11.2 Write unit tests for test helpers
    - Test that testInstance() creates proper test instances
    - Test that helpers return both instance and mock
    - _Requirements: 3.6_

- [ ] 12. Add comprehensive property tests
  - [~] 12.1 Write property test for test isolation
    - **Property 4: Test isolation prevents side effects**
    - **Validates: Requirements 3.5, 5.5, 5.6, 5.7**
  
  - [~] 12.2 Write property test for backward compatibility
    - **Property 5: Backward compatibility preservation**
    - **Validates: Requirements 2.6, 6.1, 6.5**
  
  - [~] 12.3 Write property test for notification bridge
    - **Property 6: Notification bridge integrity**
    - **Validates: Requirements 6.3, 6.4**

- [ ] 13. Verify Objective-C bridge compatibility
  - [~] 13.1 Test that existing Objective-C code still works
    - Verify PlaybackController still functions
    - Verify notification posting from Objective-C works
    - Verify no changes needed to Objective-C business logic
    - _Requirements: 6.1, 6.5_
  
  - [~] 13.2 Write integration tests for Objective-C bridge
    - Test notifications flow from Objective-C to Swift
    - Test that both real and mock Pandora post same notifications
    - _Requirements: 6.3, 6.4_

- [ ] 14. Final checkpoint - Full test suite validation
  - Run complete test suite
  - Verify all 18 restored tests pass
  - Verify no network requests in tests
  - Verify no keychain access in tests
  - Verify production app still works normally
  - _Requirements: 5.8_

- [~] 15. Documentation and examples
  - Add inline documentation to PandoraProtocol
  - Add usage examples in MockPandora comments
  - Document test helper functions
  - Add migration guide comments for future components
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

## Notes

- All tasks are required for comprehensive testing and validation
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties with minimum 100 iterations
- Unit tests validate specific examples and edge cases
- The phased approach ensures backward compatibility throughout migration
- All changes maintain the existing Objective-C bridge without modifications
