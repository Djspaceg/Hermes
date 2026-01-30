# Requirements Document

## Introduction

This specification defines the requirements for implementing dependency injection (DI) in the Hermes macOS application. The current architecture uses global singletons (e.g., `AppState.shared.pandora`) which creates tight coupling and prevents proper test isolation. When tests instantiate ViewModels, they inadvertently trigger production Pandora API authentication, causing test failures and crashes.

The dependency injection system will enable proper separation of concerns, allowing production code to use real implementations while tests use mock implementations. This will restore 18 disabled tests across HistoryViewModelTests, StationsViewModelTests, StationArtworkLoaderTests, and LoginViewModelTests.

## Glossary

- **DI (Dependency Injection)**: A design pattern where dependencies are provided to objects rather than created internally
- **Protocol**: Swift interface defining a contract for behavior
- **Mock**: A test double that simulates real behavior for testing purposes
- **ViewModel**: SwiftUI observable object managing view state and business logic
- **Pandora**: The Objective-C API client for Pandora music service
- **AppState**: Singleton managing global application state
- **Test_Isolation**: The ability to run tests independently without side effects
- **Production_Code**: Code that runs in the released application
- **Test_Code**: Code that runs during automated testing

## Requirements

### Requirement 1: Protocol Abstraction for Pandora Operations

**User Story:** As a developer, I want protocol abstractions for Pandora operations, so that I can substitute mock implementations during testing.

#### Acceptance Criteria

1. THE System SHALL define a protocol representing Pandora authentication operations
2. THE System SHALL define a protocol representing Pandora station management operations
3. THE System SHALL define a protocol representing Pandora playback operations
4. THE System SHALL define a protocol representing Pandora song rating operations
5. THE System SHALL ensure all protocol methods match existing Pandora API signatures
6. THE System SHALL make the existing Pandora class conform to these protocols

### Requirement 2: ViewModel Dependency Injection

**User Story:** As a developer, I want ViewModels to accept dependencies through their initializers, so that I can inject mock implementations during testing.

#### Acceptance Criteria

1. WHEN a ViewModel is initialized, THE System SHALL accept protocol-typed dependencies as parameters
2. THE System SHALL provide default parameter values for production use
3. THE System SHALL store injected dependencies as instance properties
4. THE System SHALL use injected dependencies instead of global singletons
5. WHEN a ViewModel accesses Pandora operations, THE System SHALL use the injected dependency
6. THE System SHALL maintain backward compatibility with existing ViewModel instantiation sites

### Requirement 3: Mock Implementation for Testing

**User Story:** As a test engineer, I want mock implementations of Pandora protocols, so that I can test ViewModels without triggering production API calls.

#### Acceptance Criteria

1. THE System SHALL provide mock implementations for all Pandora protocols
2. WHEN a mock method is called, THE System SHALL record the invocation for verification
3. THE System SHALL allow configuring mock return values and behaviors
4. THE System SHALL allow simulating success and error conditions
5. WHEN tests instantiate ViewModels with mocks, THE System SHALL NOT trigger production API calls
6. THE System SHALL provide mock implementations that are reusable across test suites

### Requirement 4: AppState Dependency Management

**User Story:** As a developer, I want AppState to support dependency injection, so that the entire application can use injected dependencies consistently.

#### Acceptance Criteria

1. THE System SHALL allow AppState to be initialized with injected dependencies
2. THE System SHALL provide a factory method for creating production AppState instances
3. THE System SHALL provide a factory method for creating test AppState instances
4. WHEN production code creates AppState, THE System SHALL inject real Pandora implementation
5. WHEN test code creates AppState, THE System SHALL inject mock implementations
6. THE System SHALL maintain the singleton pattern for production use while allowing test instances

### Requirement 5: Test Restoration and Validation

**User Story:** As a test engineer, I want all disabled tests restored and passing, so that I can verify the application behaves correctly without production side effects.

#### Acceptance Criteria

1. THE System SHALL restore all 15 disabled HistoryViewModel tests
2. THE System SHALL restore all 3 disabled StationsViewModel tests
3. THE System SHALL restore the disabled StationArtworkLoader test
4. THE System SHALL restore all 2 disabled LoginViewModel tests
5. WHEN restored tests run, THE System SHALL use mock implementations
6. WHEN restored tests run, THE System SHALL NOT make network requests
7. WHEN restored tests run, THE System SHALL NOT access production keychain
8. WHEN all restored tests run, THE System SHALL pass without failures

### Requirement 6: Objective-C Bridge Compatibility

**User Story:** As a developer, I want the DI system to work with the existing Objective-C bridge, so that I don't break existing functionality during migration.

#### Acceptance Criteria

1. WHEN Objective-C code accesses Pandora, THE System SHALL continue using the existing singleton
2. WHEN Swift code accesses Pandora through DI, THE System SHALL use injected dependencies
3. THE System SHALL maintain NotificationCenter-based communication between layers
4. WHEN notifications are posted from Objective-C, THE System SHALL be received by Swift ViewModels
5. THE System SHALL NOT require changes to existing Objective-C business logic
6. THE System SHALL allow gradual migration of components to DI

### Requirement 7: Documentation and Examples

**User Story:** As a developer, I want clear documentation and examples of the DI system, so that I can correctly implement and test new features.

#### Acceptance Criteria

1. THE System SHALL provide documentation explaining the DI architecture
2. THE System SHALL provide examples of creating ViewModels with DI in production
3. THE System SHALL provide examples of creating ViewModels with mocks in tests
4. THE System SHALL provide examples of creating custom mock behaviors
5. THE System SHALL document the protocol hierarchy and responsibilities
6. THE System SHALL provide migration guidance for existing code
