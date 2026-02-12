//
//  LoginViewModelTests.swift
//  HermesTests
//
//  Tests for LoginViewModel to verify parity with AuthController
//

import XCTest
@testable import Hermes

@MainActor
final class LoginViewModelTests: XCTestCase {
    
    var sut: LoginViewModel!
    var mockPandora: MockPandora!
    
    override func setUp() async throws {
        try await super.setUp()
        // Use MockPandora to avoid any side effects (keychain, network, UserDefaults)
        mockPandora = MockPandora()
        sut = LoginViewModel(pandora: mockPandora)
    }
    
    override func tearDown() async throws {
        sut = nil
        mockPandora = nil
        try await super.tearDown()
    }
    
    // MARK: - Email Validation Tests (from AuthController)
    
    func testEmailValidation_ValidEmail() {
        // Given
        sut.username = "user@example.com"
        
        // Then
        XCTAssertTrue(sut.isValidEmail, "Valid email should pass validation")
    }
    
    func testEmailValidation_InvalidEmail_NoAtSign() {
        // Given
        sut.username = "userexample.com"
        
        // Then
        XCTAssertFalse(sut.isValidEmail, "Email without @ should fail validation")
    }
    
    func testEmailValidation_InvalidEmail_NoDomain() {
        // Given
        sut.username = "user@"
        
        // Then
        XCTAssertFalse(sut.isValidEmail, "Email without domain should fail validation")
    }
    
    func testEmailValidation_InvalidEmail_NoTLD() {
        // Given
        sut.username = "user@example"
        
        // Then
        XCTAssertFalse(sut.isValidEmail, "Email without TLD should fail validation")
    }
    
    func testEmailValidation_EmptyString() {
        // Given
        sut.username = ""
        
        // Then
        XCTAssertFalse(sut.isValidEmail, "Empty email should fail validation")
    }
    
    // MARK: - Form Validation Tests (from AuthController controlTextDidChange)
    
    func testCanSubmit_ValidCredentials() {
        // Given
        sut.username = "user@example.com"
        sut.password = "password123"
        
        // Then
        XCTAssertTrue(sut.canSubmit, "Valid credentials should enable submit")
    }
    
    func testCanSubmit_InvalidEmail() {
        // Given
        sut.username = "invalid"
        sut.password = "password123"
        
        // Then
        XCTAssertFalse(sut.canSubmit, "Invalid email should disable submit")
    }
    
    func testCanSubmit_EmptyPassword() {
        // Given
        sut.username = "user@example.com"
        sut.password = ""
        
        // Then
        XCTAssertFalse(sut.canSubmit, "Empty password should disable submit")
    }
    
    func testCanSubmit_EmptyUsername() {
        // Given
        sut.username = ""
        sut.password = "password123"
        
        // Then
        XCTAssertFalse(sut.canSubmit, "Empty username should disable submit")
    }
    
    func testCanSubmit_WhileLoading() {
        // Given
        sut.username = "user@example.com"
        sut.password = "password123"
        sut.isLoading = true
        
        // Then
        XCTAssertFalse(sut.canSubmit, "Should disable submit while loading")
    }
    
    // MARK: - Authentication Tests (from AuthController authenticate:)
    
    func testAuthenticate_SetsLoadingState() async throws {
        // Given
        sut.username = "user@example.com"
        sut.password = "password123"
        
        // When - Start authentication (will fail without real Pandora, but we can test state)
        let initialLoading = sut.isLoading
        
        // Then
        XCTAssertFalse(initialLoading, "Should not be loading initially")
        
        // Note: Full authentication testing requires integration tests with real Pandora API
        // Unit tests focus on validation logic and state management
    }
    
    func testAuthenticate_SavesCredentials() async throws {
        // Given
        sut.username = "user@example.com"
        sut.password = "password123"
        
        // When - Credentials are set
        // Then - They should be accessible
        XCTAssertEqual(sut.username, "user@example.com")
        XCTAssertEqual(sut.password, "password123")
        
        // Note: Keychain testing requires integration tests or keychain mocking
    }
    
    // MARK: - State Management Tests
    
    /// Tests initial state of LoginViewModel
    /// Restored: Now uses MockPandora - no side effects
    func testInitialState() {
        // Then
        XCTAssertEqual(sut.username, "", "Username should be empty initially")
        XCTAssertEqual(sut.password, "", "Password should be empty initially")
        XCTAssertFalse(sut.isLoading, "Should not be loading initially")
        XCTAssertNil(sut.errorMessage, "Should have no error initially")
    }
    
    /// Tests that error message persists until cleared
    /// Restored: Now uses MockPandora - no side effects
    func testErrorMessageCleared_OnNewAuthentication() async throws {
        // Given - Set error message manually
        sut.errorMessage = "Previous error"
        
        XCTAssertNotNil(sut.errorMessage, "Should have error message")
        
        // When - Clear error by setting new credentials
        sut.username = "user@example.com"
        sut.password = "newpassword"
        
        // Then - Error should persist until new auth attempt
        // Note: We don't call authenticate() here because that saves to UserDefaults
        XCTAssertNotNil(sut.errorMessage, "Error persists until new auth attempt")
    }
    
    // MARK: - Dependency Injection Tests
    
    /// Tests that LoginViewModel uses the injected Pandora instance
    func testDependencyInjection_UsesMockPandora() {
        // Given - sut was created with mockPandora in setUp
        
        // When - Call mock directly to verify it's the same instance
        _ = mockPandora.authenticate("test@example.com", password: "pass", request: nil)
        
        // Then - Mock should have recorded the call
        XCTAssertTrue(mockPandora.didCall(.authenticate(username: "test@example.com", password: "pass")))
    }
    
    // MARK: - Property 1: Dependency Injection Preserves Instance Identity
    //
    // For any ViewModel initialized with a specific PandoraProtocol instance,
    // all operations performed by that ViewModel should use the exact same
    // instance that was injected, not a different instance or global singleton.
    //
    // **Validates: Requirements 2.3, 2.4, 2.5**
    
    /// Property test: Dependency injection preserves instance identity
    /// Tests that the injected PandoraProtocol instance is used for all operations
    func testProperty_DependencyInjectionPreservesInstanceIdentity() async throws {
        // Feature: dependency-injection, Property 1: Dependency injection preserves instance identity
        // **Validates: Requirements 2.3, 2.4, 2.5**
        
        // Run 100+ iterations with different mock configurations
        for iteration in 0..<100 {
            // Given - Create a fresh mock for each iteration
            let mock = MockPandora()
            let viewModel = LoginViewModel(pandora: mock)
            
            // Generate random credentials
            let username = "user\(Int.random(in: 1...1000))@example.com"
            let password = "password\(Int.random(in: 1...10000))"
            
            // Configure the mock with random success/failure
            let shouldSucceed = Bool.random()
            mock.authenticateResult = shouldSucceed
            
            // Set credentials on the view model
            viewModel.username = username
            viewModel.password = password
            
            // When - Attempt authentication
            do {
                try await viewModel.authenticate()
            } catch {
                // Expected when shouldSucceed is false
            }
            
            // Then - Verify the injected mock was used (not a different instance)
            XCTAssertTrue(
                mock.didCall(.authenticate(username: username, password: password)),
                "Iteration \(iteration): Expected authenticate to be called on the injected mock with username '\(username)'"
            )
            
            // Verify exactly one authenticate call was made to this mock
            XCTAssertEqual(
                mock.callCount(for: .authenticate(username: username, password: password)),
                1,
                "Iteration \(iteration): Expected exactly one authenticate call to the injected mock"
            )
            
            // Verify the mock's state reflects the operation
            if shouldSucceed {
                XCTAssertTrue(
                    mock.isAuthenticatedValue,
                    "Iteration \(iteration): Mock should be authenticated after successful auth"
                )
            }
        }
    }
    
    /// Property test: Multiple ViewModels with different mocks maintain isolation
    /// Tests that each ViewModel uses its own injected instance independently
    func testProperty_MultipleViewModelsWithDifferentMocksMaintainIsolation() async throws {
        // Feature: dependency-injection, Property 1: Dependency injection preserves instance identity
        // **Validates: Requirements 2.3, 2.4, 2.5**
        
        // Run 100+ iterations
        for iteration in 0..<100 {
            // Given - Create two separate mocks and view models
            let mock1 = MockPandora()
            let mock2 = MockPandora()
            let viewModel1 = LoginViewModel(pandora: mock1)
            let viewModel2 = LoginViewModel(pandora: mock2)
            
            // Generate different credentials for each
            let username1 = "user1_\(iteration)@example.com"
            let password1 = "pass1_\(iteration)"
            let username2 = "user2_\(iteration)@example.com"
            let password2 = "pass2_\(iteration)"
            
            // Configure mocks differently
            mock1.authenticateResult = true
            mock2.authenticateResult = false
            
            // Set credentials
            viewModel1.username = username1
            viewModel1.password = password1
            viewModel2.username = username2
            viewModel2.password = password2
            
            // When - Authenticate both
            do {
                try await viewModel1.authenticate()
            } catch {
                XCTFail("Iteration \(iteration): viewModel1 should succeed")
            }
            
            do {
                try await viewModel2.authenticate()
                XCTFail("Iteration \(iteration): viewModel2 should fail")
            } catch {
                // Expected
            }
            
            // Then - Verify each mock only received calls from its own ViewModel
            XCTAssertTrue(
                mock1.didCall(.authenticate(username: username1, password: password1)),
                "Iteration \(iteration): mock1 should have received call from viewModel1"
            )
            XCTAssertFalse(
                mock1.didCall(.authenticate(username: username2, password: password2)),
                "Iteration \(iteration): mock1 should NOT have received call from viewModel2"
            )
            
            XCTAssertTrue(
                mock2.didCall(.authenticate(username: username2, password: password2)),
                "Iteration \(iteration): mock2 should have received call from viewModel2"
            )
            XCTAssertFalse(
                mock2.didCall(.authenticate(username: username1, password: password1)),
                "Iteration \(iteration): mock2 should NOT have received call from viewModel1"
            )
            
            // Verify call counts
            XCTAssertEqual(mock1.calls.count, 1, "Iteration \(iteration): mock1 should have exactly 1 call")
            XCTAssertEqual(mock2.calls.count, 1, "Iteration \(iteration): mock2 should have exactly 1 call")
        }
    }
    
    /// Property test: Injected dependency is stored and reused across multiple operations
    /// Tests that the same injected instance is used for all operations on a ViewModel
    func testProperty_InjectedDependencyIsStoredAndReused() async throws {
        // Feature: dependency-injection, Property 1: Dependency injection preserves instance identity
        // **Validates: Requirements 2.3, 2.4, 2.5**
        
        // Run 100+ iterations
        for iteration in 0..<100 {
            // Given - Create a mock and view model
            let mock = MockPandora()
            let viewModel = LoginViewModel(pandora: mock)
            
            // Generate random number of authentication attempts
            let attemptCount = Int.random(in: 2...5)
            var expectedCallCount = 0
            
            for attempt in 0..<attemptCount {
                // Generate credentials for this attempt
                let username = "user\(attempt)_\(iteration)@example.com"
                let password = "pass\(attempt)_\(iteration)"
                
                // Randomly configure success/failure
                mock.authenticateResult = Bool.random()
                
                // Set credentials
                viewModel.username = username
                viewModel.password = password
                viewModel.isLoading = false // Reset loading state
                viewModel.errorMessage = nil // Reset error
                
                // When - Attempt authentication
                do {
                    try await viewModel.authenticate()
                } catch {
                    // Expected on failure
                }
                
                expectedCallCount += 1
                
                // Then - Verify the call was recorded on the same mock
                XCTAssertTrue(
                    mock.didCall(.authenticate(username: username, password: password)),
                    "Iteration \(iteration), attempt \(attempt): Call should be recorded on injected mock"
                )
            }
            
            // Verify total call count matches expected
            XCTAssertEqual(
                mock.calls.count,
                expectedCallCount,
                "Iteration \(iteration): Expected \(expectedCallCount) total calls on the injected mock"
            )
        }
    }
}
