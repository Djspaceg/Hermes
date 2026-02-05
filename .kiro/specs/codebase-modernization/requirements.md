# Requirements Document: Codebase Modernization

## Introduction

This specification defines the requirements for refining and modernizing the Hermes macOS Pandora client codebase. The codebase has **already been fully migrated to Swift/SwiftUI** with no Objective-C code remaining. This modernization focuses on adopting Swift 5.9+ features, improving code organization, enhancing testability, and following modern Apple development best practices.

The modernization targets macOS Tahoe (26.0) exclusively and addresses architecture refinement, code organization, and testing improvements.

The modernization is structured in three phases:

- **Phase 1**: Foundation (1-2 weeks) - Critical consolidations and standardizations
- **Phase 2**: Modern Patterns (1 month) - Swift 5.9+ features and testing infrastructure
- **Phase 3**: Complete Refinement (2-3 months) - Code organization and optimization

## Glossary

- **System**: The Hermes macOS application codebase (100% Swift/SwiftUI)
- **AppState**: Central state management singleton using ObservableObject
- **View_Model**: ObservableObject class managing view state (to be migrated to @Observable)
- **Protocol_Definition**: Swift protocol defining interface contracts
- **Model_Object**: Data structure representing domain entities (Song, Station, etc.)
- **Wrapper_Model**: SwiftUI-friendly wrapper around base model (e.g., SongModel wraps Song)
- **Notification_Constant**: Typed Notification.Name extension (already implemented)
- **UserDefaults_Key**: String constant for persistent storage keys (needs centralization)
- **MARK_Comment**: Code organization comment following `// MARK: - Section` pattern
- **Observable_Macro**: Swift 5.9+ @Observable macro for state management (target pattern)
- **Preview_Macro**: Swift 5.9+ #Preview macro for SwiftUI previews (partially adopted)
- **DocC**: Apple's documentation compiler format
- **Swift_Testing**: Modern Swift testing framework replacing XCTest
- **Async_Await**: Swift concurrency pattern using async/await keywords (already in use)
- **Combine**: Apple's reactive programming framework (currently used for state)
- **Main_Thread**: Primary UI thread requiring @MainActor annotation

## Requirements

### Requirement 1: Consolidate Duplicate Protocol Definitions

**User Story:** As a developer, I want a single source of truth for protocol definitions, so that I can avoid inconsistencies and maintenance overhead.

#### Acceptance Criteria

1. WHEN the codebase contains duplicate protocol definitions, THE System SHALL identify all duplicates and consolidate them into a single canonical definition
2. WHEN PandoraProtocol exists in multiple files, THE System SHALL maintain exactly one PandoraProtocol definition in the most appropriate location
3. WHEN consolidating protocols, THE System SHALL update all conforming types to reference the canonical definition
4. WHEN protocols are consolidated, THE System SHALL ensure all method signatures and requirements are preserved
5. WHEN duplicate protocols are removed, THE System SHALL verify that all existing functionality continues to work

### Requirement 2: Resolve Model Duplication Pattern

**User Story:** As a developer, I want a single unified model for each domain entity, so that I can avoid duplication and simplify state management.

#### Acceptance Criteria

1. WHEN Song and SongModel both exist, THE System SHALL consolidate them into a single @Observable model
2. WHEN Station and StationModel both exist, THE System SHALL consolidate them into a single @Observable model
3. WHEN models are consolidated, THE System SHALL preserve all existing functionality
4. WHEN consolidation is complete, THE System SHALL use the unified model throughout the codebase
5. WHEN the model pattern is established, THE System SHALL document the pattern in code comments and architecture documentation

### Requirement 3: Reduce Singleton Overuse

**User Story:** As a developer, I want proper dependency injection instead of global singletons, so that code is testable and maintainable.

#### Acceptance Criteria

1. WHEN a class uses singleton pattern unnecessarily, THE System SHALL refactor it to use dependency injection
2. WHEN AppState is the appropriate singleton, THE System SHALL ensure all state access goes through AppState
3. WHEN dependencies are injected, THE System SHALL use initializer injection or environment values
4. WHEN singletons are removed, THE System SHALL update all call sites to receive dependencies
5. WHEN refactoring is complete, THE System SHALL ensure improved testability through mockable dependencies

### Requirement 4: Verify Notification Names Consistency

**User Story:** As a developer, I want all notification usage to be consistent with the typed constants, so that the codebase remains maintainable.

#### Acceptance Criteria

1. WHEN notification names are used, THE System SHALL verify they use typed Notification.Name extensions from NotificationNames.swift
2. WHEN string literals are found for notifications, THE System SHALL replace them with typed constants
3. WHEN new notifications are added, THE System SHALL add them to NotificationNames.swift
4. WHEN posting or observing notifications, THE System SHALL use the typed constants exclusively
5. WHEN verification is complete, THE System SHALL ensure no string literal notification names remain

### Requirement 5: Remove Inconsistent Naming Prefixes

**User Story:** As a developer, I want consistent naming conventions, so that code is predictable and professional.

#### Acceptance Criteria

1. WHEN @objc names use "Swift" prefix inconsistently, THE System SHALL remove the prefix
2. WHEN Objective-C code references Swift types, THE System SHALL use the standard bridging name
3. WHEN renaming occurs, THE System SHALL update all references in both Swift and Objective-C code
4. WHEN naming is standardized, THE System SHALL follow Apple's Swift naming guidelines
5. WHEN changes are complete, THE System SHALL verify no compilation errors exist

### Requirement 6: Standardize UserDefaults Keys

**User Story:** As a developer, I want namespaced UserDefaults keys, so that I can avoid key collisions and organize preferences clearly.

#### Acceptance Criteria

1. WHEN UserDefaults keys are defined, THE System SHALL use a consistent namespacing pattern
2. WHEN keys are scattered across files, THE System SHALL consolidate them into a single UserDefaults extension
3. WHEN accessing UserDefaults, THE System SHALL use the typed key constants exclusively
4. WHEN keys are namespaced, THE System SHALL use reverse-DNS notation (e.g., "com.hermes.preference.key")
5. WHEN migration is complete, THE System SHALL ensure existing user preferences continue to work

### Requirement 7: Split Large Files

**User Story:** As a developer, I want reasonably-sized files, so that code is navigable and maintainable.

#### Acceptance Criteria

1. WHEN a file exceeds 800 lines, THE System SHALL evaluate it for splitting into logical components
2. WHEN AudioStreamer.swift (1910 lines) is split, THE System SHALL separate concerns into focused files (state, buffer, decoder, output, error)
3. WHEN PandoraClient.swift (1597 lines) is split, THE System SHALL organize by API domain (auth, stations, playback, search, seeds)
4. WHEN PlayerView.swift (~500 lines) is split, THE System SHALL extract reusable view components
5. WHEN files are split, THE System SHALL maintain all existing functionality and tests

### Requirement 8: Extract Reusable View Components

**User Story:** As a developer, I want small, reusable SwiftUI components, so that I can compose views efficiently and avoid duplication.

#### Acceptance Criteria

1. WHEN view code is duplicated, THE System SHALL extract it into a reusable component
2. WHEN a view body exceeds 50 lines, THE System SHALL evaluate extracting subviews
3. WHEN components are extracted, THE System SHALL make them configurable via parameters
4. WHEN components are created, THE System SHALL follow single-responsibility principle
5. WHEN extraction is complete, THE System SHALL ensure all views use the extracted components

### Requirement 9: Add Consistent MARK Comments

**User Story:** As a developer, I want consistent code organization markers, so that I can navigate files quickly.

#### Acceptance Criteria

1. WHEN organizing code sections, THE System SHALL use `// MARK: - Section Name` format
2. WHEN files lack MARK comments, THE System SHALL add them following standard patterns
3. WHEN MARK comments exist inconsistently, THE System SHALL standardize them
4. WHEN sections are marked, THE System SHALL follow the order: Properties → Initializers → Lifecycle → Public Methods → Private Methods
5. WHEN MARK comments are added, THE System SHALL ensure Xcode's jump bar navigation works correctly

### Requirement 10: Migrate to @Observable Macro

**User Story:** As a developer, I want modern state management using @Observable, so that I can leverage Swift 5.9+ features and reduce boilerplate.

#### Acceptance Criteria

1. WHEN a class uses ObservableObject protocol, THE System SHALL migrate it to @Observable macro
2. WHEN migrating to @Observable, THE System SHALL remove @Published property wrappers
3. WHEN @Observable is applied, THE System SHALL update views to remove @ObservedObject/@StateObject where appropriate
4. WHEN migration is complete, THE System SHALL verify all state updates trigger view refreshes
5. WHEN all view models are migrated, THE System SHALL ensure no ObservableObject usage remains except where required for compatibility

### Requirement 11: Standardize Environment Key Usage

**User Story:** As a developer, I want consistent environment value patterns, so that dependency injection is predictable.

#### Acceptance Criteria

1. WHEN custom environment values are needed, THE System SHALL define them using EnvironmentKey protocol
2. WHEN environment values are defined, THE System SHALL provide default values
3. WHEN accessing environment values, THE System SHALL use @Environment property wrapper
4. WHEN environment keys are scattered, THE System SHALL consolidate them into a single file
5. WHEN standardization is complete, THE System SHALL document the pattern for future additions

### Requirement 12: Migrate to #Preview Macro

**User Story:** As a developer, I want modern preview syntax, so that previews are concise and follow current Swift conventions.

#### Acceptance Criteria

1. WHEN SwiftUI previews use PreviewProvider protocol, THE System SHALL migrate them to #Preview macro
2. WHEN migrating previews, THE System SHALL preserve all preview configurations and variants
3. WHEN #Preview is used, THE System SHALL provide descriptive names for each preview
4. WHEN multiple preview variants exist, THE System SHALL create separate #Preview declarations
5. WHEN migration is complete, THE System SHALL verify all previews render correctly in Xcode

### Requirement 13: Verify Image Loading Implementation

**User Story:** As a developer, I want to ensure the existing image loading implementation follows best practices, so that it remains maintainable.

#### Acceptance Criteria

1. WHEN reviewing ImageCache.swift, THE System SHALL verify it uses URLSession with URLCache
2. WHEN reviewing image loading, THE System SHALL verify it uses async/await patterns
3. WHEN reviewing caching, THE System SHALL verify proper memory management and cache eviction
4. WHEN reviewing error handling, THE System SHALL verify placeholder images or error states exist
5. WHEN verification is complete, THE System SHALL document any improvements needed

### Requirement 14: Centralize State Access Through AppState

**User Story:** As a developer, I want all app-wide state managed through AppState, so that state flow is predictable and debuggable.

#### Acceptance Criteria

1. WHEN app-wide state exists outside AppState, THE System SHALL migrate it into AppState
2. WHEN view models need app state, THE System SHALL access it through AppState singleton or environment injection
3. WHEN state is centralized, THE System SHALL ensure single source of truth for each state property
4. WHEN AppState is updated, THE System SHALL ensure all dependent views update correctly
5. WHEN centralization is complete, THE System SHALL document the state management architecture

### Requirement 15: Standardize on Async/Await

**User Story:** As a developer, I want consistent async patterns, so that asynchronous code is readable and maintainable.

#### Acceptance Criteria

1. WHEN new asynchronous code is written, THE System SHALL use async/await over Combine publishers
2. WHEN Combine is used for UI state, THE System SHALL evaluate migration to async/await or @Observable
3. WHEN async methods are defined, THE System SHALL mark them with appropriate async/throws keywords
4. WHEN calling async code from sync contexts, THE System SHALL use Task appropriately
5. WHEN async/await is standardized, THE System SHALL ensure proper error propagation and cancellation handling

### Requirement 16: Create Unified Error Hierarchy

**User Story:** As a developer, I want a consistent error type system, so that error handling is predictable and informative.

#### Acceptance Criteria

1. WHEN errors occur in the system, THE System SHALL use a unified error enum or hierarchy
2. WHEN defining errors, THE System SHALL include descriptive messages and recovery suggestions
3. WHEN errors are thrown, THE System SHALL provide sufficient context for debugging
4. WHEN errors are displayed to users, THE System SHALL show user-friendly messages
5. WHEN error hierarchy is established, THE System SHALL document error handling patterns

### Requirement 17: Replace Silent Error Handling

**User Story:** As a developer, I want visible error logging, so that I can debug issues effectively.

#### Acceptance Criteria

1. WHEN errors are caught silently, THE System SHALL add appropriate logging
2. WHEN logging errors, THE System SHALL include relevant context (file, line, function)
3. WHEN errors occur, THE System SHALL use os_log or unified logging system
4. WHEN critical errors occur, THE System SHALL ensure they are visible to developers
5. WHEN error handling is improved, THE System SHALL remove empty catch blocks

### Requirement 18: Migrate to Swift Testing Framework

**User Story:** As a developer, I want modern test syntax, so that tests are readable and leverage Swift 5.9+ features.

#### Acceptance Criteria

1. WHEN tests use XCTest, THE System SHALL migrate them to Swift Testing framework
2. WHEN migrating tests, THE System SHALL preserve all test coverage and assertions
3. WHEN using Swift Testing, THE System SHALL use @Test attribute and modern assertion syntax
4. WHEN tests are organized, THE System SHALL use @Suite for logical grouping
5. WHEN migration is complete, THE System SHALL verify all tests pass

### Requirement 19: Fix and Re-enable Disabled Tests

**User Story:** As a developer, I want all tests enabled and passing, so that I can trust the test suite.

#### Acceptance Criteria

1. WHEN tests are disabled or commented out, THE System SHALL investigate and fix the underlying issues
2. WHEN tests fail due to outdated assumptions, THE System SHALL update them to match current behavior
3. WHEN tests are flaky, THE System SHALL identify and fix race conditions or timing issues
4. WHEN tests are fixed, THE System SHALL re-enable them in the test suite
5. WHEN all tests are enabled, THE System SHALL ensure the full suite passes consistently

### Requirement 20: Add Missing Test Coverage

**User Story:** As a developer, I want comprehensive test coverage, so that I can refactor confidently.

#### Acceptance Criteria

1. WHEN AudioStreamer lacks tests, THE System SHALL add unit tests for core streaming functionality
2. WHEN Playlist lacks tests, THE System SHALL add tests for playlist management operations
3. WHEN ImageCache lacks tests, THE System SHALL add tests for caching behavior and memory management
4. WHEN adding tests, THE System SHALL achieve minimum 80% code coverage for critical components
5. WHEN test coverage is added, THE System SHALL include both unit tests and property-based tests where appropriate

### Requirement 21: Move Heavy Operations Off Main Thread

**User Story:** As a developer, I want responsive UI, so that users don't experience freezing or lag.

#### Acceptance Criteria

1. WHEN heavy operations run on main thread, THE System SHALL move them to background threads
2. WHEN operations are moved off main thread, THE System SHALL use async/await or Task with appropriate priority
3. WHEN background work completes, THE System SHALL update UI on main thread using @MainActor
4. WHEN operations are CPU-intensive, THE System SHALL consider using DispatchQueue with appropriate QoS
5. WHEN threading is optimized, THE System SHALL verify UI responsiveness under load

### Requirement 22: Apply Notification Debouncing

**User Story:** As a developer, I want debounced notifications, so that rapid updates don't cause performance issues.

#### Acceptance Criteria

1. WHEN notifications fire rapidly, THE System SHALL apply debouncing to reduce update frequency
2. WHEN debouncing is applied, THE System SHALL use consistent debounce intervals across similar events
3. WHEN debouncing notifications, THE System SHALL ensure the latest value is always processed
4. WHEN using Combine for debouncing, THE System SHALL use debounce operator appropriately
5. WHEN debouncing is implemented, THE System SHALL verify UI updates remain smooth

### Requirement 23: Add DocC-Compatible Documentation

**User Story:** As a developer, I want comprehensive API documentation, so that I can understand code without reading implementation.

#### Acceptance Criteria

1. WHEN public APIs exist, THE System SHALL add DocC-compatible documentation comments
2. WHEN documenting APIs, THE System SHALL include summary, parameters, returns, and throws sections
3. WHEN documentation is added, THE System SHALL use proper markdown formatting
4. WHEN complex APIs exist, THE System SHALL include usage examples in documentation
5. WHEN documentation is complete, THE System SHALL generate DocC documentation successfully

### Requirement 24: Update Outdated Comments

**User Story:** As a developer, I want accurate comments, so that documentation matches implementation.

#### Acceptance Criteria

1. WHEN comments reference deprecated APIs, THE System SHALL update them to reference current APIs
2. WHEN comments describe outdated behavior, THE System SHALL update them to match current implementation
3. WHEN TODO comments exist, THE System SHALL either implement the TODO or remove the comment
4. WHEN comments are misleading, THE System SHALL correct or remove them
5. WHEN comments are updated, THE System SHALL ensure they add value and aren't redundant with code

### Requirement 25: Phase 1 Completion Checkpoint

**User Story:** As a project manager, I want to verify Phase 1 completion, so that I can approve moving to Phase 2.

#### Acceptance Criteria

1. WHEN Phase 1 tasks are complete, THE System SHALL have consolidated all duplicate protocols
2. WHEN Phase 1 tasks are complete, THE System SHALL have standardized all notification names and UserDefaults keys
3. WHEN Phase 1 tasks are complete, THE System SHALL have resolved model duplication patterns
4. WHEN Phase 1 tasks are complete, THE System SHALL have all tests passing
5. WHEN Phase 1 is verified, THE System SHALL produce a completion report documenting changes

### Requirement 26: Phase 2 Completion Checkpoint

**User Story:** As a project manager, I want to verify Phase 2 completion, so that I can approve moving to Phase 3.

#### Acceptance Criteria

1. WHEN Phase 2 tasks are complete, THE System SHALL have migrated all tests to Swift Testing framework
2. WHEN Phase 2 tasks are complete, THE System SHALL have added missing test coverage for critical components
3. WHEN Phase 2 tasks are complete, THE System SHALL have standardized async/await usage
4. WHEN Phase 2 tasks are complete, THE System SHALL have improved error handling throughout
5. WHEN Phase 2 is verified, THE System SHALL produce a completion report documenting improvements

### Requirement 27: Phase 3 Completion Checkpoint

**User Story:** As a project manager, I want to verify Phase 3 completion, so that I can approve the modernization as complete.

#### Acceptance Criteria

1. WHEN Phase 3 tasks are complete, THE System SHALL have migrated all view models to @Observable macro
2. WHEN Phase 3 tasks are complete, THE System SHALL have split all large files into manageable components
3. WHEN Phase 3 tasks are complete, THE System SHALL have extracted all reusable view components
4. WHEN Phase 3 tasks are complete, THE System SHALL have comprehensive DocC documentation
5. WHEN Phase 3 is verified, THE System SHALL produce a final completion report and updated architecture documentation
