//
//  LoginViewModel.swift
//  Hermes
//
//  Manages authentication state
//

import Foundation
import Combine
import Observation

/// View model for the login screen, managing authentication state and user credentials.
///
/// This view model uses dependency injection to accept a `PandoraProtocol` implementation,
/// enabling test isolation by allowing mock implementations to be injected during testing.
///
/// ## Dependency Injection Pattern
///
/// The view model accepts a `PandoraProtocol` parameter with a default value for production use:
///
/// ```swift
/// // Production usage (uses default AppState.shared.pandora)
/// let viewModel = LoginViewModel()
///
/// // Test usage (inject mock)
/// let mock = MockPandora()
/// let viewModel = LoginViewModel(pandora: mock)
/// ```
///
/// ## Testing
///
/// Use the `testInstance()` helper for convenient test setup:
///
/// ```swift
/// let (viewModel, mock) = LoginViewModel.testInstance()
/// mock.authenticateResult = false
/// mock.authenticateError = SomeError()
/// try await viewModel.authenticate()
/// XCTAssertNotNil(viewModel.errorMessage)
/// ```
///
@MainActor
@Observable
final class LoginViewModel {
    // MARK: - Properties
    
    var username: String = ""
    var password: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    
    @ObservationIgnored
    private let pandora: PandoraProtocol
    
    // MARK: - Computed Properties
    
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)
        return emailPredicate.evaluate(with: username)
    }
    
    var canSubmit: Bool {
        !username.isEmpty && !password.isEmpty && isValidEmail && !isLoading
    }
    
    // MARK: - Initialization
    
    /// Initializes the LoginViewModel with a Pandora implementation
    ///
    /// - Parameter pandora: The PandoraProtocol implementation to use.
    ///   Defaults to AppState.shared.pandora for production use.
    init(pandora: PandoraProtocol = AppState.shared.pandora) {
        self.pandora = pandora
    }
    
    // MARK: - Public Methods
    
    func authenticate() async throws {
        guard canSubmit else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Save credentials
        UserDefaults.standard.set(username, forKey: UserDefaultsKeys.username)
        try? KeychainManager.shared.saveCredentials(username: username, password: password)
        
        // Use the synchronous protocol method
        let success = pandora.authenticate(username, password: password, request: nil)
        
        if !success {
            isLoading = false
            errorMessage = "Authentication failed"
            throw LoginError.authenticationFailed
        }
        
        // Wait for authentication notification or error
        // The isLoading flag will be cleared by notification handlers in AppState
    }
    
    // MARK: - Error Types
    
    enum LoginError: Error {
        case authenticationFailed
    }
}
