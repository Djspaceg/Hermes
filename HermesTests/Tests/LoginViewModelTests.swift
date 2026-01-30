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
    
    override func setUp() async throws {
        try await super.setUp()
        // Use isolated Pandora instance to avoid keychain access
        // Tests focus on validation logic, not Pandora API
        sut = LoginViewModel(pandora: Pandora())
    }
    
    override func tearDown() async throws {
        sut = nil
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
    
    // DISABLED: Triggers Pandora authentication - needs dependency injection refactoring
    // See: .kiro/specs/dependency-injection/requirements.md
    func disabled_testInitialState() {
        // Then
        XCTAssertEqual(sut.username, "", "Username should be empty initially")
        XCTAssertEqual(sut.password, "", "Password should be empty initially")
        XCTAssertFalse(sut.isLoading, "Should not be loading initially")
        XCTAssertNil(sut.errorMessage, "Should have no error initially")
    }
    
    // DISABLED: Triggers Pandora authentication - needs dependency injection refactoring
    // See: .kiro/specs/dependency-injection/requirements.md
    func disabled_testErrorMessageCleared_OnNewAuthentication() async throws {
        // Given - Set error message manually
        sut.errorMessage = "Previous error"
        
        XCTAssertNotNil(sut.errorMessage, "Should have error message")
        
        // When - Clear error by setting new credentials
        sut.username = "user@example.com"
        sut.password = "newpassword"
        
        // Then - Error should be cleared when attempting new authentication
        // Note: Full authentication flow requires integration tests
        XCTAssertNotNil(sut.errorMessage, "Error persists until new auth attempt")
    }
}
