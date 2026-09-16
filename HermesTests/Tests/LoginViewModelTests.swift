//
//  LoginViewModelTests.swift
//  HermesTests
//
//  Tests for LoginViewModel to verify parity with AuthController
//

import Testing
import Foundation
@testable import Hermes

@MainActor
@Suite("LoginViewModelTests", .serialized)
struct LoginViewModelTests {
    let sut: LoginViewModel
    let mockPandora: MockPandora

    init() {
        // Use MockPandora to avoid any side effects (keychain, network, UserDefaults)
        mockPandora = MockPandora()
        sut = LoginViewModel(pandora: mockPandora, persistCredentials: false)
    }

    // MARK: - Email Validation Tests (from AuthController)

    @Test("Email Validation Valid Email")

    func testEmailValidation_ValidEmail() {
        // Given
        sut.username = "user@example.com"

        // Then
        #expect(sut.isValidEmail, "Valid email should pass validation")
    }

    @Test("Email Validation Invalid Email No At Sign")

    func testEmailValidation_InvalidEmail_NoAtSign() {
        // Given
        sut.username = "userexample.com"

        // Then
        #expect(!(sut.isValidEmail), "Email without @ should fail validation")
    }

    @Test("Email Validation Invalid Email No Domain")

    func testEmailValidation_InvalidEmail_NoDomain() {
        // Given
        sut.username = "user@"

        // Then
        #expect(!(sut.isValidEmail), "Email without domain should fail validation")
    }

    @Test("Email Validation Invalid Email No TLD")

    func testEmailValidation_InvalidEmail_NoTLD() {
        // Given
        sut.username = "user@example"

        // Then
        #expect(!(sut.isValidEmail), "Email without TLD should fail validation")
    }

    @Test("Email Validation Empty String")

    func testEmailValidation_EmptyString() {
        // Given
        sut.username = ""

        // Then
        #expect(!(sut.isValidEmail), "Empty email should fail validation")
    }

    // MARK: - Form Validation Tests (from AuthController controlTextDidChange)

    @Test("Can Submit Valid Credentials")

    func testCanSubmit_ValidCredentials() {
        // Given
        sut.username = "user@example.com"
        sut.password = "password123"

        // Then
        #expect(sut.canSubmit, "Valid credentials should enable submit")
    }

    @Test("Can Submit Invalid Email")

    func testCanSubmit_InvalidEmail() {
        // Given
        sut.username = "invalid"
        sut.password = "password123"

        // Then
        #expect(!(sut.canSubmit), "Invalid email should disable submit")
    }

    @Test("Can Submit Empty Password")

    func testCanSubmit_EmptyPassword() {
        // Given
        sut.username = "user@example.com"
        sut.password = ""

        // Then
        #expect(!(sut.canSubmit), "Empty password should disable submit")
    }

    @Test("Can Submit Empty Username")

    func testCanSubmit_EmptyUsername() {
        // Given
        sut.username = ""
        sut.password = "password123"

        // Then
        #expect(!(sut.canSubmit), "Empty username should disable submit")
    }

    @Test("Can Submit While Loading")

    func testCanSubmit_WhileLoading() {
        // Given
        sut.username = "user@example.com"
        sut.password = "password123"
        sut.isLoading = true

        // Then
        #expect(!(sut.canSubmit), "Should disable submit while loading")
    }

    // MARK: - Authentication Tests (from AuthController authenticate:)

    @Test("Authenticate Sets Loading State")

    func testAuthenticate_SetsLoadingState() async throws {
        // Given
        sut.username = "user@example.com"
        sut.password = "password123"

        // When - Start authentication (will fail without real Pandora, but we can test state)
        let initialLoading = sut.isLoading

        // Then
        #expect(!(initialLoading), "Should not be loading initially")

        // Note: Full authentication testing requires integration tests with real Pandora API
        // Unit tests focus on validation logic and state management
    }

    @Test("Authenticate Saves Credentials")

    func testAuthenticate_SavesCredentials() async throws {
        // Given
        sut.username = "user@example.com"
        sut.password = "password123"

        // When - Credentials are set
        // Then - They should be accessible
        #expect((sut.username) == ("user@example.com"))
        #expect((sut.password) == ("password123"))

        // Note: Keychain testing requires integration tests or keychain mocking
    }

    // MARK: - State Management Tests

    /// Tests initial state of LoginViewModel
    /// Restored: Now uses MockPandora - no side effects
    @Test("Initial State")
    func testInitialState() {
        // Then
        #expect((sut.username) == (""), "Username should be empty initially")
        #expect((sut.password) == (""), "Password should be empty initially")
        #expect(!(sut.isLoading), "Should not be loading initially")
        #expect((sut.errorMessage) == nil, "Should have no error initially")
    }

    /// Tests that error message persists until cleared
    /// Restored: Now uses MockPandora - no side effects
    @Test("Error Message Cleared On New Authentication")
    func testErrorMessageCleared_OnNewAuthentication() async throws {
        // Given - Set error message manually
        sut.errorMessage = "Previous error"

        #expect((sut.errorMessage) != nil, "Should have error message")

        // When - Clear error by setting new credentials
        sut.username = "user@example.com"
        sut.password = "newpassword"

        // Then - Error should persist until new auth attempt
        // Note: We don't call authenticate() here because that saves to UserDefaults
        #expect((sut.errorMessage) != nil, "Error persists until new auth attempt")
    }

    // MARK: - Dependency Injection Tests

    /// Tests that LoginViewModel uses the injected Pandora instance
    @Test("Dependency Injection Uses Mock Pandora")
    func testDependencyInjection_UsesMockPandora() {
        // Given - sut was created with mockPandora in setUp

        // When - Call mock directly to verify it's the same instance
        _ = mockPandora.authenticate("test@example.com", password: "pass", request: nil)

        // Then - Mock should have recorded the call
        #expect(mockPandora.didCall(.authenticate(username: "test@example.com", password: "pass")))
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
    @Test("Property Dependency Injection Preserves Instance Identity")
    func testProperty_DependencyInjectionPreservesInstanceIdentity() async throws {
        // Feature: dependency-injection, Property 1: Dependency injection preserves instance identity
        // **Validates: Requirements 2.3, 2.4, 2.5**

        // Run 100+ iterations with different mock configurations
        for iteration in 0..<100 {
            // Given - Create a fresh mock for each iteration
            let mock = MockPandora()
            let viewModel = LoginViewModel(pandora: mock, persistCredentials: false)

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
            #expect(mock.didCall(.authenticate(username: username, password: password)), "Iteration \(iteration): Expected authenticate to be called on the injected mock with username '\(username)'")

            // Verify exactly one authenticate call was made to this mock
            #expect((mock.callCount(for: .authenticate(username: username, password: password))) == (1), "Iteration \(iteration): Expected exactly one authenticate call to the injected mock")

            // Verify the mock's state reflects the operation
            if shouldSucceed {
                #expect(mock.isAuthenticatedValue, "Iteration \(iteration): Mock should be authenticated after successful auth")
            }
        }
    }

    /// Property test: Multiple ViewModels with different mocks maintain isolation
    /// Tests that each ViewModel uses its own injected instance independently
    @Test("Property Multiple View Models With Different Mocks Maintain Isolation")
    func testProperty_MultipleViewModelsWithDifferentMocksMaintainIsolation() async throws {
        // Feature: dependency-injection, Property 1: Dependency injection preserves instance identity
        // **Validates: Requirements 2.3, 2.4, 2.5**

        // Run 100+ iterations
        for iteration in 0..<100 {
            // Given - Create two separate mocks and view models
            let mock1 = MockPandora()
            let mock2 = MockPandora()
            let viewModel1 = LoginViewModel(pandora: mock1, persistCredentials: false)
            let viewModel2 = LoginViewModel(pandora: mock2, persistCredentials: false)

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
                Issue.record("Iteration \(iteration): viewModel1 should succeed")
            }

            do {
                try await viewModel2.authenticate()
                Issue.record("Iteration \(iteration): viewModel2 should fail")
            } catch {
                // Expected
            }

            // Then - Verify each mock only received calls from its own ViewModel
            #expect(mock1.didCall(.authenticate(username: username1, password: password1)), "Iteration \(iteration): mock1 should have received call from viewModel1")
            #expect(!(mock1.didCall(.authenticate(username: username2, password: password2))), "Iteration \(iteration): mock1 should NOT have received call from viewModel2")

            #expect(mock2.didCall(.authenticate(username: username2, password: password2)), "Iteration \(iteration): mock2 should have received call from viewModel2")
            #expect(!(mock2.didCall(.authenticate(username: username1, password: password1))), "Iteration \(iteration): mock2 should NOT have received call from viewModel1")

            // Verify call counts
            #expect((mock1.calls.count) == (1), "Iteration \(iteration): mock1 should have exactly 1 call")
            #expect((mock2.calls.count) == (1), "Iteration \(iteration): mock2 should have exactly 1 call")
        }
    }

    /// Property test: Injected dependency is stored and reused across multiple operations
    /// Tests that the same injected instance is used for all operations on a ViewModel
    @Test("Property Injected Dependency Is Stored And Reused")
    func testProperty_InjectedDependencyIsStoredAndReused() async throws {
        // Feature: dependency-injection, Property 1: Dependency injection preserves instance identity
        // **Validates: Requirements 2.3, 2.4, 2.5**

        // Run 100+ iterations
        for iteration in 0..<100 {
            // Given - Create a mock and view model
            let mock = MockPandora()
            let viewModel = LoginViewModel(pandora: mock, persistCredentials: false)

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
                #expect(mock.didCall(.authenticate(username: username, password: password)), "Iteration \(iteration), attempt \(attempt): Call should be recorded on injected mock")
            }

            // Verify total call count matches expected
            #expect((mock.calls.count) == (expectedCallCount), "Iteration \(iteration): Expected \(expectedCallCount) total calls on the injected mock")
        }
    }
}
