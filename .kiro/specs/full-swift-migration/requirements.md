# Requirements Document: Full Swift Migration

## Introduction

This specification defines the requirements for completing the migration of ALL remaining Objective-C code in the Hermes macOS application to modern Swift. This is a comprehensive migration that achieves 100% Swift for the entire codebase with zero Objective-C or C dependencies, using CryptoSwift for Blowfish encryption instead of the legacy C library.

The migration covers approximately 3,500 lines of Objective-C across:

- AudioStreamer module (~1,600 lines) - Core audio streaming with CoreAudio C APIs
- Pandora API module (~1,200 lines) - API client, Station, Crypt
- PlaybackController (~500 lines) - Playback state management
- FMEngine (~200 lines) - Last.fm integration (partial migration needed)

## Glossary

- **Migration_System**: The collection of processes and code changes required to migrate Objective-C code to Swift
- **AudioStreamer**: The audio streaming engine that wraps CoreAudio's AudioQueue framework for HTTP audio streaming
- **Pandora_API**: The client implementation for Pandora's JSON API including authentication, station management, and song operations
- **PlaybackController**: The controller managing playback state, media keys, and coordination between audio streaming and the Pandora API
- **Crypt_Module**: The encryption/decryption wrapper using Blowfish in ECB mode for Pandora API communication
- **CryptoSwift**: A pure Swift cryptography library providing Blowfish and other algorithms
- **DI_Infrastructure**: The existing dependency injection infrastructure including PandoraProtocol and related protocols
- **Swift_Concurrency**: Modern Swift async/await and actor patterns for concurrent code
- **Build_System**: Xcode project and build configuration
- **Test_Suite**: Collection of unit tests that verify functionality

## Requirements

### Requirement 1: Migration Integrity and Backward Compatibility

**User Story:** As a developer, I want to migrate Objective-C code to Swift without breaking any existing functionality, so that users experience no regressions.

#### Acceptance Criteria

1. WHEN any Objective-C file is migrated to Swift, THEN the Build_System SHALL compile successfully with zero errors
2. WHEN any migration is complete, THEN the Test_Suite SHALL pass all existing tests
3. WHEN a component is migrated, THEN all public API signatures SHALL remain compatible with existing callers
4. WHEN the AudioStreamer is migrated, THEN audio playback SHALL function identically including streaming, buffering, seeking, and volume control
5. WHEN the Pandora_API is migrated, THEN all API operations SHALL produce identical results including authentication, station management, and song operations
6. IF a migration introduces compilation errors, THEN the Migration_System SHALL revert changes and report the issue
7. WHEN multiple files are migrated, THEN each migration SHALL be completed and verified independently before proceeding

### Requirement 2: AudioStreamer Migration

**User Story:** As a developer, I want to migrate the AudioStreamer module to Swift, so that the audio streaming code uses modern Swift patterns while maintaining full functionality.

#### Acceptance Criteria

1. WHEN AudioStreamer is migrated, THEN the Migration_System SHALL create a Swift class that wraps CoreAudio's AudioQueue APIs
2. WHEN AudioStreamer is migrated, THEN it SHALL support all existing states: initialized, waiting for data, waiting for queue, playing, paused, done, stopped
3. WHEN AudioStreamer is migrated, THEN it SHALL handle all existing error codes and provide equivalent error handling
4. WHEN AudioStreamer is migrated, THEN HTTP streaming with proxy support SHALL function identically
5. WHEN AudioStreamer is migrated, THEN seeking within streams SHALL work when bitrate is known
6. WHEN AudioStreamer is migrated, THEN volume control SHALL work identically
7. WHEN AudioStreamer is migrated, THEN timeout handling SHALL function identically
8. WHEN AudioStreamer is migrated, THEN the ASBitrateReadyNotification and ASStatusChangedNotification SHALL continue to be posted
9. THE Migration_System SHALL use Swift actors or appropriate synchronization for thread-safe audio buffer management

### Requirement 3: ASPlaylist Migration

**User Story:** As a developer, I want to migrate ASPlaylist to Swift, so that playlist management uses modern Swift patterns.

#### Acceptance Criteria

1. WHEN ASPlaylist is migrated, THEN the Migration_System SHALL create a Swift class managing the queue of AudioStreamer instances
2. WHEN ASPlaylist is migrated, THEN song advancement SHALL work identically
3. WHEN ASPlaylist is migrated, THEN volume propagation to all streamers SHALL work identically
4. WHEN ASPlaylist is migrated, THEN progress and duration calculations SHALL be accurate
5. WHEN ASPlaylist is migrated, THEN it SHALL integrate with the migrated AudioStreamer

### Requirement 4: Pandora API Migration

**User Story:** As a developer, I want to migrate the Pandora API client to Swift, so that API communication uses modern async/await patterns.

#### Acceptance Criteria

1. WHEN Pandora is migrated, THEN the Migration_System SHALL implement the existing PandoraProtocol interface
2. WHEN Pandora is migrated, THEN authentication flow SHALL work identically including partner login, user login, and subscriber status check
3. WHEN Pandora is migrated, THEN all station operations SHALL work identically: fetch, create, remove, rename, fetch info, fetch genre stations, sort
4. WHEN Pandora is migrated, THEN all song operations SHALL work identically: rate, tired of, delete rating
5. WHEN Pandora is migrated, THEN playlist fetching SHALL work identically
6. WHEN Pandora is migrated, THEN search functionality SHALL work identically
7. WHEN Pandora is migrated, THEN seed management SHALL work identically: add seed, remove seed, delete feedback
8. WHEN Pandora is migrated, THEN all existing notifications SHALL continue to be posted with identical userInfo
9. THE Migration_System SHALL use Swift async/await for all network operations
10. THE Migration_System SHALL use the existing HTTPClient for network requests

### Requirement 5: Station Model Migration

**User Story:** As a developer, I want to migrate the Station model to Swift, so that station data uses Swift value types and modern patterns.

#### Acceptance Criteria

1. WHEN Station is migrated, THEN the Migration_System SHALL create a Swift class or struct with all existing properties
2. WHEN Station is migrated, THEN it SHALL maintain compatibility with existing StationModel bridging
3. WHEN Station is migrated, THEN playlist management (songs array, advancement) SHALL work identically
4. WHEN Station is migrated, THEN it SHALL integrate with the migrated ASPlaylist for audio streaming

### Requirement 6: Crypt Module Migration

**User Story:** As a developer, I want to migrate the Crypt module to pure Swift using CryptoSwift, so that the entire codebase is Swift with no C dependencies.

#### Acceptance Criteria

1. WHEN Crypt is migrated, THEN the Migration_System SHALL use CryptoSwift's Blowfish implementation in ECB mode
2. WHEN Crypt is migrated, THEN PandoraEncryptData functionality SHALL produce identical encrypted output
3. WHEN Crypt is migrated, THEN PandoraDecryptString functionality SHALL produce identical decrypted output
4. WHEN Crypt is migrated, THEN hex encoding/decoding SHALL work identically
5. WHEN Crypt is migrated, THEN the blowfish.c and blowfish.h files SHALL be deleted
6. THE Migration_System SHALL add CryptoSwift as a Swift Package Manager dependency

### Requirement 7: PlaybackController Migration

**User Story:** As a developer, I want to migrate PlaybackController to Swift, so that playback coordination uses modern Swift patterns.

#### Acceptance Criteria

1. WHEN PlaybackController is migrated, THEN the Migration_System SHALL create a Swift class with @MainActor for UI-related state
2. WHEN PlaybackController is migrated, THEN station playback SHALL work identically
3. WHEN PlaybackController is migrated, THEN play/pause/stop/next controls SHALL work identically
4. WHEN PlaybackController is migrated, THEN song rating (like/dislike/tired) SHALL work identically
5. WHEN PlaybackController is migrated, THEN volume control SHALL work identically
6. WHEN PlaybackController is migrated, THEN media key handling via MPRemoteCommandCenter SHALL work identically
7. WHEN PlaybackController is migrated, THEN screensaver/screen lock pause handling SHALL work identically
8. WHEN PlaybackController is migrated, THEN all existing notifications SHALL continue to be posted
9. WHEN PlaybackController is migrated, THEN state persistence (save/restore station) SHALL work identically

### Requirement 8: Dependency Injection Integration

**User Story:** As a developer, I want all view models to use dependency injection, so that the codebase is fully testable.

#### Acceptance Criteria

1. WHEN DI is integrated, THEN AppState SHALL accept PandoraProtocol via initializer instead of creating Pandora directly
2. WHEN DI is integrated, THEN StationsViewModel SHALL accept PandoraProtocol via initializer
3. WHEN DI is integrated, THEN PlayerViewModel SHALL accept dependencies via initializer
4. WHEN DI is integrated, THEN the migrated Pandora class SHALL conform to PandoraProtocol
5. WHEN DI is integrated, THEN existing MockPandora SHALL continue to work for testing
6. THE Migration_System SHALL update AppState.shared to use a factory pattern for production vs test instances

### Requirement 9: FMEngine Completion

**User Story:** As a developer, I want to complete the FMEngine migration to Swift, so that Last.fm integration is fully in Swift.

#### Acceptance Criteria

1. WHEN FMEngine migration is completed, THEN LastFMService SHALL handle all scrobbling operations
2. WHEN FMEngine migration is completed, THEN authentication with Last.fm SHALL work identically
3. WHEN FMEngine migration is completed, THEN the NSString+FMEngine category SHALL be replaced with Swift String extensions
4. WHEN FMEngine migration is completed, THEN the original FMEngine Objective-C files SHALL be deleted

### Requirement 10: Bridging Header Removal

**User Story:** As a developer, I want to completely remove the bridging header, so that the codebase is 100% Swift with no Objective-C interop.

#### Acceptance Criteria

1. WHEN migration is complete, THEN the Hermes-Bridging-Header.h file SHALL be deleted
2. WHEN migration is complete, THEN no Objective-C imports SHALL remain in the project
3. WHEN migration is complete, THEN the Build_System SHALL have no bridging header configured
4. WHEN migration is complete, THEN the ImportedSources/blowfish directory SHALL be deleted

### Requirement 11: Modern Swift Patterns

**User Story:** As a developer, I want the migrated code to use modern Swift patterns, so that the codebase follows current best practices.

#### Acceptance Criteria

1. THE Migration_System SHALL use async/await for all asynchronous operations
2. THE Migration_System SHALL use Swift actors for thread-safe mutable state where appropriate
3. THE Migration_System SHALL use @Observable (or @ObservableObject) for observable state
4. THE Migration_System SHALL use Swift error handling (throws/Result) instead of error codes
5. THE Migration_System SHALL use Swift enums with associated values for state machines
6. THE Migration_System SHALL use protocols for abstraction and testability
7. THE Migration_System SHALL use value types (structs) where appropriate instead of classes

### Requirement 12: Code Quality and Documentation

**User Story:** As a developer, I want the migrated code to be well-documented and maintainable, so that future developers can understand and modify it.

#### Acceptance Criteria

1. WHEN code is migrated, THEN all public APIs SHALL have documentation comments
2. WHEN code is migrated, THEN complex algorithms SHALL have inline comments explaining the logic
3. WHEN code is migrated, THEN the Migration_System SHALL follow existing Swift naming conventions in the codebase
4. WHEN code is migrated, THEN the Migration_System SHALL organize code with MARK comments for sections
5. WHEN migration is complete, THEN the Migration_System SHALL update structure.md to reflect the new architecture

### Requirement 13: Phased Migration Approach

**User Story:** As a developer, I want the migration to proceed in phases, so that risk is minimized and progress is incremental.

#### Acceptance Criteria

1. THE Migration_System SHALL complete Phase 1 (Foundation) before Phase 2: Crypt migration, duplicate file cleanup, DI integration
2. THE Migration_System SHALL complete Phase 2 (Audio Layer) before Phase 3: AudioStreamer, ASPlaylist
3. THE Migration_System SHALL complete Phase 3 (API Layer) before Phase 4: Pandora, Station
4. THE Migration_System SHALL complete Phase 4 (Controllers) before Phase 5: PlaybackController
5. THE Migration_System SHALL complete Phase 5 (Cleanup) last: FMEngine completion, bridging header minimization
6. WHEN each phase is complete, THEN all tests SHALL pass before proceeding to the next phase
