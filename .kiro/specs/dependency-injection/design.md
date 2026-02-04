# Design Document: Dependency Injection System

## Overview

This design implements a dependency injection (DI) system for the Hermes macOS application to enable proper test isolation and eliminate the current tight coupling to global singletons. The system uses Swift protocols to abstract Pandora API operations, allowing production code to use real implementations while tests use mock implementations.

The design follows modern Swift best practices, leveraging protocol-oriented programming and Swift's type system to ensure compile-time safety. The implementation maintains full backward compatibility with the existing Objective-C bridge layer while enabling gradual migration of components to the DI pattern.

### Key Goals

1. Enable test isolation by allowing mock injection during testing
2. Restore 18 disabled tests across 4 test suites
3. Maintain backward compatibility with existing Objective-C code
4. Support gradual migration without breaking existing functionality
5. Follow modern Swift/SwiftUI patterns and conventions

## Architecture

### Protocol Hierarchy

The DI system is built around a set of Swift protocols that abstract Pandora operations. These protocols mirror the existing Pandora API but provide abstraction points for dependency injection.

```swift
// Core protocol that all Pandora implementations must conform to
protocol PandoraProtocol: AnyObject {
    // Authentication
    var isAuthenticated: Bool { get }
    func authenticate(_ username: String, password: String, request: PandoraRequest?) -> Bool
    func logout()
    
    // Station management
    var stations: [Station] { get }
    func fetchStations() -> Bool
    func createStation(_ musicId: String) -> Bool
    func removeStation(_ stationToken: String) -> Bool
    func renameStation(_ stationToken: String, to name: String) -> Bool
    func fetchStationInfo(_ station: Station) -> Bool
    
    // Playback
    func fetchPlaylistForStation(_ station: Station) -> Bool
    
    // Song operations
    func rateSong(_ song: Song, as liked: Bool) -> Bool
    func tiredOfSong(_ song: Song) -> Bool
    func deleteRating(_ song: Song) -> Bool
    
    // Search
    func search(_ query: String) -> Bool
    
    // Seed management
    func addSeed(_ token: String, toStation station: Station) -> Bool
    func removeSeed(_ seedId: String) -> Bool
    func deleteFeedback(_ feedbackId: String) -> Bool
}
```

### Protocol Design Rationale

**Single Protocol Approach**: Rather than splitting into multiple protocols (AuthProtocol, StationProtocol, etc.), we use a single `PandoraProtocol` because:

1. The Pandora API is a cohesive unit - operations are interdependent
2. Authentication state affects all operations
3. Simplifies dependency injection (one dependency instead of many)
4. Matches the existing Pandora class structure
5. Easier to mock (one mock class instead of coordinating multiple mocks)

**Method Signatures**: All protocol methods match the existing Pandora class signatures exactly to ensure:

- Zero changes required to existing Objective-C code
- Seamless conformance by the existing Pandora class
- Type safety at compile time

### Pandora Conformance

The existing Objective-C `Pandora` class will conform to `PandoraProtocol` through a Swift extension:

```swift
// Extension to make Pandora conform to PandoraProtocol
extension Pandora: PandoraProtocol {
    var isAuthenticated: Bool {
        return self.isAuthenticated()
    }
    
    var stations: [Station] {
        return (self.stations as? [Station]) ?? []
    }
    
    // All other methods already match the protocol signatures
    // No implementation needed - they're inherited from the Objective-C class
}
```

This extension is purely declarative - it doesn't add new functionality, it just declares that Pandora conforms to the protocol. The compiler verifies that all required methods exist with matching signatures.

## Components and Interfaces

### 1. Protocol Definition

**File**: `Sources/Swift/Protocols/PandoraProtocol.swift`

Defines the `PandoraProtocol` interface that abstracts all Pandora operations. This protocol serves as the contract between ViewModels and Pandora implementations.

### 2. Pandora Extension

**File**: `Sources/Swift/Extensions/Pandora+Protocol.swift`

Extends the Objective-C `Pandora` class to conform to `PandoraProtocol`. This is a zero-cost abstraction - no runtime overhead, just compile-time type checking.

### 3. Mock Implementation

**File**: `HermesTests/Mocks/MockPandora.swift`

Provides a test double that implements `PandoraProtocol` for testing purposes.

```swift
@MainActor
final class MockPandora: PandoraProtocol {
    // MARK: - Call Recording
    
    struct Call: Equatable {
        enum Method: Equatable {
            case authenticate(username: String, password: String)
            case fetchStations
            case createStation(musicId: String)
            case removeStation(token: String)
            case renameStation(token: String, name: String)
            case rateSong(songToken: String, liked: Bool)
            case tiredOfSong(songToken: String)
            case search(query: String)
            // ... other methods
        }
        
        let method: Method
        let timestamp: Date
    }
    
    private(set) var calls: [Call] = []
    
    // MARK: - Configurable Behavior
    
    var authenticateResult: Bool = true
    var authenticateError: Error?
    var fetchStationsResult: Bool = true
    var mockStations: [Station] = []
    var isAuthenticatedValue: Bool = false
    
    // MARK: - Protocol Implementation
    
    var isAuthenticated: Bool {
        return isAuthenticatedValue
    }
    
    var stations: [Station] {
        return mockStations
    }
    
    func authenticate(_ username: String, password: String, request: PandoraRequest?) -> Bool {
        calls.append(Call(method: .authenticate(username: username, password: password), timestamp: Date()))
        
        if let error = authenticateError {
            // Post error notification
            NotificationCenter.default.post(
                name: Notification.Name("hermes.error"),
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
            return false
        }
        
        if authenticateResult {
            isAuthenticatedValue = true
            // Post success notification
            NotificationCenter.default.post(name: Notification.Name("hermes.authenticated"), object: nil)
        }
        
        return authenticateResult
    }
    
    func fetchStations() -> Bool {
        calls.append(Call(method: .fetchStations, timestamp: Date()))
        
        if fetchStationsResult {
            // Post stations loaded notification
            NotificationCenter.default.post(name: Notification.Name("hermes.stations"), object: nil)
        }
        
        return fetchStationsResult
    }
    
    // ... implement all other protocol methods with similar recording and notification patterns
    
    // MARK: - Test Helpers
    
    func reset() {
        calls.removeAll()
        authenticateResult = true
        authenticateError = nil
        fetchStationsResult = true
        mockStations = []
        isAuthenticatedValue = false
    }
    
    func didCall(_ method: Call.Method) -> Bool {
        return calls.contains { $0.method == method }
    }
    
    func callCount(for method: Call.Method) -> Int {
        return calls.filter { $0.method == method }.count
    }
}
```

### 4. ViewModel Dependency Injection

Each ViewModel will be updated to accept `PandoraProtocol` as a dependency with a default parameter for production use.

**Example: LoginViewModel**

```swift
@MainActor
final class LoginViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let pandora: PandoraProtocol
    
    // Default parameter uses production Pandora singleton
    init(pandora: PandoraProtocol = AppState.shared.pandora) {
        self.pandora = pandora
    }
    
    func authenticate() async throws {
        guard canSubmit else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Save credentials
        UserDefaults.standard.set(username, forKey: "pandora.username")
        try? KeychainManager.shared.saveCredentials(username: username, password: password)
        
        // Use injected dependency instead of global singleton
        let success = pandora.authenticate(username, password: password, request: nil)
        
        if !success {
            isLoading = false
            errorMessage = "Authentication failed"
            throw LoginError.authenticationFailed
        }
    }
    
    // ... rest of implementation
}
```

**Pattern for All ViewModels**:

1. Store `PandoraProtocol` as a private property
2. Accept it as an initializer parameter with default value
3. Use the injected dependency instead of accessing singletons
4. Maintain all existing functionality

### 5. AppState Refactoring

AppState will be refactored to support dependency injection while maintaining the singleton pattern for production use.

```swift
@MainActor
final class AppState: ObservableObject {
    // Singleton for production use
    static let shared: AppState = {
        print("AppState.shared: Creating singleton instance")
        return AppState.production()
    }()
    
    // MARK: - Published Properties
    
    @Published var currentView: ViewState = .login
    @Published var isSidebarVisible: Bool = true
    @Published var isAuthenticated: Bool = false
    
    // MARK: - Dependencies
    
    let pandora: PandoraProtocol
    let loginViewModel: LoginViewModel
    let playerViewModel: PlayerViewModel
    let stationsViewModel: StationsViewModel
    let historyViewModel: HistoryViewModel
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Factory Methods
    
    /// Creates an AppState instance for production use with real Pandora implementation
    static func production() -> AppState {
        let pandora = Pandora()
        return AppState(pandora: pandora)
    }
    
    /// Creates an AppState instance for testing with mock Pandora implementation
    static func test(pandora: PandoraProtocol) -> AppState {
        return AppState(pandora: pandora, skipCredentialCheck: true)
    }
    
    // MARK: - Initialization
    
    private init(pandora: PandoraProtocol, skipCredentialCheck: Bool = false) {
        print("AppState: Initializing...")
        
        self.pandora = pandora
        
        // Initialize view models with injected dependency
        self.loginViewModel = LoginViewModel(pandora: pandora)
        self.playerViewModel = PlayerViewModel()
        self.stationsViewModel = StationsViewModel(pandora: pandora)
        self.historyViewModel = HistoryViewModel()
        
        // Subscribe to notifications
        setupNotificationSubscriptions()
        
        // Check for saved credentials - but NOT in test mode
        if !skipCredentialCheck && !Self.isPreview && !Self.isRunningTests {
            checkSavedCredentials()
        } else {
            print("AppState: Skipping credential check (test/preview mode)")
        }
        
        print("AppState: Initialized - currentView: \(currentView)")
    }
    
    // ... rest of implementation unchanged
}
```

### 6. Test Utilities

**File**: `HermesTests/Utilities/TestHelpers.swift`

Provides convenience functions for creating test instances:

```swift
@MainActor
extension AppState {
    /// Creates a test AppState with a fresh MockPandora instance
    static func testInstance() -> (appState: AppState, mockPandora: MockPandora) {
        let mock = MockPandora()
        let appState = AppState.test(pandora: mock)
        return (appState, mock)
    }
}

@MainActor
extension LoginViewModel {
    /// Creates a test LoginViewModel with a fresh MockPandora instance
    static func testInstance() -> (viewModel: LoginViewModel, mockPandora: MockPandora) {
        let mock = MockPandora()
        let viewModel = LoginViewModel(pandora: mock)
        return (viewModel, mock)
    }
}

// Similar helpers for other ViewModels
```

## Data Models

No new data models are required. The design works with existing models:

- `Station` (Objective-C)
- `Song` (Objective-C)
- `StationModel` (Swift wrapper)
- `SongModel` (Swift wrapper)
- `PandoraRequest` (Objective-C)

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Dependency Injection Preserves Instance Identity

*For any* ViewModel initialized with a specific PandoraProtocol instance, all operations performed by that ViewModel should use the exact same instance that was injected, not a different instance or global singleton.

**Validates: Requirements 2.3, 2.4, 2.5**

### Property 2: Mock Call Recording is Complete

*For any* sequence of method calls made on a MockPandora instance, the mock's call history should contain exactly those calls in the same order, with no missing or extra calls.

**Validates: Requirements 3.2**

### Property 3: Mock Configuration Affects Behavior

*For any* MockPandora instance, when a return value or error is configured for a method, calling that method should return the configured value or throw the configured error, not the default behavior.

**Validates: Requirements 3.3, 3.4**

### Property 4: Test Isolation Prevents Side Effects

*For any* test that uses MockPandora, no network requests should be made, no keychain access should occur, and no production API calls should be triggered during test execution.

**Validates: Requirements 3.5, 5.5, 5.6, 5.7**

### Property 5: Backward Compatibility Preservation

*For any* existing code that creates ViewModels without explicit parameters, the code should continue to compile and function correctly using production dependencies.

**Validates: Requirements 2.6, 6.1, 6.5**

### Property 6: Notification Bridge Integrity

*For any* notification posted from Objective-C Pandora code, Swift ViewModels using either real or mock Pandora implementations should receive the notification with correct userInfo data.

**Validates: Requirements 6.3, 6.4**

## Error Handling

### Compilation Errors

**Protocol Conformance Mismatch**: If Pandora method signatures don't match the protocol, compilation will fail with clear error messages indicating which methods need adjustment.

**Solution**: The protocol is designed to exactly match existing Pandora signatures, so this should not occur. If it does, adjust the protocol to match reality.

### Runtime Errors

**Nil Pandora Instance**: If a ViewModel is somehow initialized with a nil Pandora reference (shouldn't be possible with non-optional protocol type).

**Solution**: Use non-optional `PandoraProtocol` type to make this impossible at compile time.

**Mock Misconfiguration**: Tests might fail if mocks aren't properly configured to return expected values.

**Solution**: Provide sensible defaults in MockPandora (e.g., `authenticateResult = true`) and clear documentation on configuration.

### Test Failures

**Notification Timing Issues**: Tests might fail if they don't wait for asynchronous notifications.

**Solution**: Use XCTest expectations or async/await patterns to properly wait for notifications.

**State Pollution**: Tests might fail if previous test state isn't properly cleaned up.

**Solution**: Each test creates fresh mock instances and calls `reset()` in tearDown.

## Testing Strategy

### Dual Testing Approach

The implementation will use both unit tests and property-based tests:

**Unit Tests**: Verify specific examples, edge cases, and integration points

- Test that ViewModels can be created with mocks
- Test that specific method calls are recorded correctly
- Test that notifications are properly posted and received
- Test that restored tests pass without side effects

**Property Tests**: Verify universal properties across all inputs

- Test that dependency injection always preserves instance identity
- Test that mock recording is always complete and accurate
- Test that test isolation always prevents side effects
- Test that backward compatibility is always maintained

### Test Organization

**Mock Tests** (`HermesTests/Tests/MockPandoraTests.swift`):

- Verify mock call recording
- Verify mock configuration
- Verify mock notification posting
- Minimum 100 iterations per property test

**ViewModel DI Tests** (`HermesTests/Tests/ViewModelDependencyInjectionTests.swift`):

- Verify dependency injection works for each ViewModel
- Verify default parameters use production dependencies
- Verify injected dependencies are used instead of singletons
- Minimum 100 iterations per property test

**Restored Tests**:

- Re-enable all 18 disabled tests
- Update to use MockPandora instead of real Pandora
- Verify no side effects occur

### Property Test Configuration

All property tests will use Swift's built-in randomization capabilities or a property-based testing library like [swift-check](https://github.com/typelift/SwiftCheck) if available.

Each property test will:

- Run minimum 100 iterations
- Use randomized inputs where applicable
- Include a comment tag: `// Feature: dependency-injection, Property N: [property text]`
- Reference the design document property number

Example:

```swift
func testDependencyInjectionPreservesInstanceIdentity() {
    // Feature: dependency-injection, Property 1: Dependency injection preserves instance identity
    
    for _ in 0..<100 {
        let mock = MockPandora()
        let viewModel = LoginViewModel(pandora: mock)
        
        // Verify the injected instance is used
        _ = viewModel.pandora.isAuthenticated
        XCTAssertTrue(mock.didCall(.isAuthenticated))
    }
}
```

### Unit Test Balance

Unit tests will focus on:

- Specific examples of ViewModel creation with DI
- Edge cases like empty station lists or nil values
- Integration between ViewModels and mocks
- Notification delivery across the Objective-C bridge

Property tests will focus on:

- Universal correctness properties
- Comprehensive input coverage through randomization
- Invariants that must hold across all executions

Together, these provide comprehensive coverage without excessive redundancy.

## Migration Strategy

### Phase 1: Foundation (No Breaking Changes)

1. Create `PandoraProtocol.swift` with protocol definition
2. Create `Pandora+Protocol.swift` extension for conformance
3. Create `MockPandora.swift` in test target
4. Verify compilation succeeds

**Validation**: All existing code compiles and runs unchanged.

### Phase 2: AppState Refactoring

1. Add factory methods to AppState (`production()`, `test()`)
2. Update AppState initializer to accept `PandoraProtocol`
3. Keep singleton pattern for production use
4. Update AppState to use injected pandora

**Validation**: App runs normally, singleton still works.

### Phase 3: ViewModel Migration

Migrate ViewModels one at a time:

1. **LoginViewModel**
   - Add `pandora: PandoraProtocol` parameter with default
   - Update to use injected dependency
   - Restore 2 disabled tests

2. **StationsViewModel**
   - Add `pandora: PandoraProtocol` parameter with default
   - Update to use injected dependency
   - Restore 3 disabled tests

3. **HistoryViewModel**
   - Already doesn't use Pandora directly
   - Restore 15 disabled tests (they fail due to AppState initialization)

4. **StationArtworkLoader**
   - Update `configure(with:)` to accept `PandoraProtocol`
   - Restore 1 disabled test

**Validation**: After each ViewModel, verify:

- Existing code still works
- New tests pass
- No side effects in tests

### Phase 4: Test Restoration

1. Remove `disabled_` prefix from all test methods
2. Update tests to use `MockPandora`
3. Run full test suite
4. Fix any remaining issues

**Validation**: All 18 tests pass without side effects.

### Phase 5: Documentation

1. Add inline documentation to protocols
2. Create usage examples in test files
3. Update README with DI patterns
4. Document migration guide for future components

## Objective-C Bridge Compatibility

### Maintaining Existing Behavior

The Objective-C `Pandora` class continues to work exactly as before:

```objc
// Objective-C code - unchanged
Pandora *pandora = [[Pandora alloc] init];
[pandora authenticate:@"user@example.com" password:@"password" request:nil];
```

### Swift Interoperability

Swift code can use Pandora through the protocol:

```swift
// Swift code - using protocol
let pandora: PandoraProtocol = Pandora()
pandora.authenticate("user@example.com", password: "password", request: nil)
```

### Notification Bridge

The notification-based communication between Objective-C and Swift remains unchanged:

**Objective-C posts**:

```objc
[[NSNotificationCenter defaultCenter] postNotificationName:@"hermes.authenticated" object:nil];
```

**Swift receives**:

```swift
NotificationCenter.default.pandoraAuthenticatedPublisher
    .sink { [weak self] in
        self?.handleAuthentication()
    }
    .store(in: &cancellables)
```

Both real Pandora and MockPandora post the same notifications, ensuring consistent behavior.

### Gradual Migration

Components can be migrated to DI incrementally:

1. **Already migrated**: Use `PandoraProtocol` parameter
2. **Not yet migrated**: Continue using `Pandora()` directly
3. **Objective-C code**: Completely unchanged

This allows the migration to proceed at a comfortable pace without breaking existing functionality.

## Implementation Notes

### Swift Concurrency

The design uses `@MainActor` annotations on ViewModels and MockPandora to ensure thread safety:

```swift
@MainActor
final class MockPandora: PandoraProtocol {
    // All properties and methods run on main thread
}
```

This matches the existing ViewModel pattern and prevents race conditions in tests.

### Memory Management

All dependencies use strong references since:

- ViewModels are owned by AppState
- AppState owns the Pandora instance
- No retain cycles are created

In tests, both the ViewModel and mock are owned by the test method, ensuring proper cleanup.

### Performance Considerations

The DI system has zero runtime overhead:

- Protocol dispatch is optimized by the Swift compiler
- No reflection or dynamic lookup
- Default parameters are resolved at compile time
- Production code path is identical to current implementation

### Type Safety

The design leverages Swift's type system for safety:

- Non-optional protocol types prevent nil references
- Protocol conformance checked at compile time
- Method signatures verified by compiler
- No runtime type checking needed

## Future Enhancements

### Potential Improvements

1. **Protocol Composition**: If needed, split `PandoraProtocol` into smaller protocols (e.g., `PandoraAuth`, `PandoraStations`) using protocol composition

2. **Async/Await**: Convert Pandora methods to async/await instead of callbacks (future modernization)

3. **Dependency Container**: Introduce a DI container for managing multiple dependencies (if complexity grows)

4. **Mock Builders**: Add fluent builder API for configuring mocks:

   ```swift
   let mock = MockPandora()
       .withAuthentication(succeeds: true)
       .withStations([station1, station2])
       .withSearchResults([result1, result2])
   ```

### Not Recommended

1. **Third-party DI frameworks**: Unnecessary complexity for this use case
2. **Service locator pattern**: Hides dependencies, makes testing harder
3. **Splitting into many protocols**: Current cohesive design is simpler

## Summary

This design implements a lightweight, type-safe dependency injection system that:

- Enables proper test isolation through mock injection
- Maintains full backward compatibility with existing code
- Supports gradual migration without breaking changes
- Follows modern Swift best practices
- Restores 18 disabled tests across 4 test suites
- Provides a foundation for future testing improvements

The implementation is minimal, focused, and leverages Swift's protocol-oriented programming to achieve maximum benefit with minimum complexity.
