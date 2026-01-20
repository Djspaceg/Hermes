# Requirements Document: Objective-C to Swift Migration

## Introduction

This specification defines the requirements for migrating remaining Objective-C code in the Hermes macOS application to modern Swift. The goal is to modernize the codebase while preserving all existing functionality, keeping only core business logic (Pandora API, audio streaming, playback control) in Objective-C.

## Glossary

- **Migration_System**: The collection of tools, processes, and code changes required to migrate Objective-C code to Swift
- **Legacy_Code**: Objective-C files (.h, .m) that are candidates for migration to Swift
- **Core_Business_Logic**: Pandora API client, AudioStreamer, and PlaybackController - complex, stable Objective-C code that will remain
- **Swift_Equivalent**: Modern Swift implementation that replaces Objective-C functionality
- **Build_System**: Xcode project and build configuration
- **Test_Suite**: Collection of 50 unit tests that verify functionality

## Requirements

### Requirement 1: Code Migration Integrity

**User Story:** As a developer, I want to migrate Objective-C code to Swift without breaking functionality, so that the app remains stable while modernizing.

#### Acceptance Criteria

1. WHEN any Objective-C file is migrated to Swift, THEN the Build_System SHALL compile successfully with zero errors
2. WHEN any migration is complete, THEN the Test_Suite SHALL pass all 50 tests
3. WHEN Legacy_Code is replaced with Swift_Equivalent, THEN all functionality SHALL behave identically to the original
4. IF a migration introduces compilation errors, THEN the Migration_System SHALL revert changes and report the issue
5. WHEN multiple files are migrated, THEN each migration SHALL be completed and verified independently before proceeding

### Requirement 2: Constants Migration

**User Story:** As a developer, I want to migrate C preprocessor macros to Swift constants, so that the code is type-safe and maintainable.

#### Acceptance Criteria

1. WHEN HermesConstants.h macros are migrated, THEN the Migration_System SHALL create Swift enums and structs for type safety
2. WHEN Objective-C code still requires constants, THEN the Migration_System SHALL provide @objc compatibility wrappers
3. WHEN Swift code uses constants, THEN it SHALL use the Swift type-safe versions
4. WHEN constants are migrated, THEN all UserDefaults keys SHALL remain unchanged to preserve user settings

### Requirement 3: Utility Code Migration

**User Story:** As a developer, I want to migrate utility code (networking, image loading) to modern Swift APIs, so that the codebase uses current best practices.

#### Acceptance Criteria

1. WHEN ImageLoader is migrated, THEN the Migration_System SHALL use SwiftUI AsyncImage and URLCache
2. WHEN NetworkConnection is migrated, THEN the Migration_System SHALL use NWPathMonitor from Network framework
3. WHEN URLConnection is migrated, THEN the Migration_System SHALL use URLSession with async/await
4. WHEN utility code is migrated, THEN the Migration_System SHALL update all consumers to use the new Swift APIs

### Requirement 4: Integration Code Migration

**User Story:** As a developer, I want to migrate integration code (Last.fm, AppleScript) to Swift, so that external integrations use modern patterns.

#### Acceptance Criteria

1. WHEN Scrobbler is migrated, THEN the Migration_System SHALL create LastFMService in Swift with async/await
2. WHEN AppleScript support is migrated, THEN the Migration_System SHALL maintain @objc compatibility for scripting bridge
3. WHEN integration code is migrated, THEN all API calls SHALL use modern error handling
4. WHEN external services are accessed, THEN the Migration_System SHALL use Swift concurrency patterns

### Requirement 5: Dead Code Removal

**User Story:** As a developer, I want to remove unused legacy code, so that the codebase is cleaner and easier to maintain.

#### Acceptance Criteria

1. WHEN unused files are identified, THEN the Migration_System SHALL verify zero references exist
2. WHEN files are deleted, THEN the Build_System SHALL remove all project references
3. WHEN obsolete workarounds are found, THEN the Migration_System SHALL verify they are not needed with SwiftUI
4. WHEN dead code is removed, THEN the Test_Suite SHALL continue passing

### Requirement 6: Core Business Logic Preservation

**User Story:** As a developer, I want to keep complex, stable business logic in Objective-C, so that we don't introduce bugs in critical functionality.

#### Acceptance Criteria

1. THE Migration_System SHALL NOT migrate PlaybackController.{h,m}
2. THE Migration_System SHALL NOT migrate Pandora API files (Pandora/, Station, Song)
3. THE Migration_System SHALL NOT migrate AudioStreamer files
4. WHEN Core_Business_Logic is preserved, THEN the Migration_System SHALL document the decision
5. WHEN Swift code needs to interact with Core_Business_Logic, THEN it SHALL use NotificationCenter or direct Objective-C calls

### Requirement 7: Project File Management

**User Story:** As a developer, I want the Xcode project to remain valid after migrations, so that the build system continues working.

#### Acceptance Criteria

1. WHEN files are added or removed, THEN the Build_System SHALL update project.pbxproj correctly
2. WHEN project.pbxproj is modified, THEN it SHALL remain parseable by Xcode
3. IF project.pbxproj becomes corrupted, THEN the Migration_System SHALL restore from git
4. WHEN bridging headers are updated, THEN the Build_System SHALL expose correct Objective-C APIs to Swift

### Requirement 8: Migration Progress Tracking

**User Story:** As a developer, I want to track migration progress, so that I know what's been completed and what remains.

#### Acceptance Criteria

1. WHEN a task is completed, THEN the Migration_System SHALL update the progress tracking document
2. WHEN tasks are in progress, THEN the Migration_System SHALL mark them appropriately
3. WHEN all tasks are complete, THEN the Migration_System SHALL report final statistics
4. WHEN effort estimates change, THEN the Migration_System SHALL update remaining effort calculations
