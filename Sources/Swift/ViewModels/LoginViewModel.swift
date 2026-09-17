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
    var credentialAvailabilityMessage: String?
    var credentialPersistenceErrorMessage: String?
    
    @ObservationIgnored
    private let pandora: PandoraProtocol
    @ObservationIgnored
    private let credentialStore: any CredentialStore
    @ObservationIgnored
    private let userDefaults: UserDefaults
    
    /// Whether to persist credentials to UserDefaults/Keychain.
    /// Set to false during testing to prevent test data from polluting real storage.
    @ObservationIgnored
    private let persistCredentials: Bool
    @ObservationIgnored
    var onManualAuthenticationStarted: (@MainActor () -> Void)?
    @ObservationIgnored
    private var pendingManualCredentials: PendingManualCredentials?
    
    // MARK: - Computed Properties
    
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)
        return emailPredicate.evaluate(with: username)
    }
    
    var canSubmit: Bool {
        !username.isEmpty && !password.isEmpty && isValidEmail && !isLoading
    }

    var showsCredentialRetry: Bool {
        credentialAvailabilityMessage != nil
    }
    
    // MARK: - Initialization
    
    /// Initializes the LoginViewModel with a Pandora implementation
    ///
    /// - Parameters:
    ///   - pandora: The PandoraProtocol implementation to use.
    ///     Defaults to AppState.shared.pandora for production use.
    ///   - persistCredentials: Whether to save credentials to UserDefaults/Keychain.
    ///     Defaults to true for production. Pass false during testing to prevent
    ///     test data from polluting real storage.
    @MainActor
    init(
        pandora: PandoraProtocol? = nil,
        credentialStore: (any CredentialStore)? = nil,
        userDefaults: UserDefaults? = nil,
        persistCredentials: Bool = true
    ) {
        self.pandora = pandora ?? AppState.shared.pandora
        self.credentialStore = credentialStore ?? KeychainManager.shared
        self.userDefaults = userDefaults ?? Self.defaultUserDefaults
        self.persistCredentials = persistCredentials
    }
    
    // MARK: - Public Methods
    
    func authenticate() async throws {
        guard canSubmit else { return }
        onManualAuthenticationStarted?()
        let pendingCredentials = persistCredentials
            ? PendingManualCredentials(username: username, password: password)
            : nil
        try await authenticate(pendingCredentials: pendingCredentials)
    }

    func authenticateRestoredCredentials() async throws {
        guard canSubmit else { return }
        try await authenticate(pendingCredentials: nil)
    }

    private func authenticate(pendingCredentials: PendingManualCredentials?) async throws {
        isLoading = true
        errorMessage = nil
        credentialPersistenceErrorMessage = nil
        pendingManualCredentials = nil
        
        // Use the synchronous protocol method
        let success = pandora.authenticate(username, password: password, request: nil)
        
        if !success {
            isLoading = false
            errorMessage = "Authentication failed"
            throw LoginError.authenticationFailed
        }

        pendingManualCredentials = pendingCredentials
    }

    func persistPendingManualCredentials() async {
        guard let credentials = pendingManualCredentials else {
            return
        }
        pendingManualCredentials = nil
        do {
            try await credentialStore.saveCredentials(
                username: credentials.username,
                password: credentials.password
            )
            userDefaults.set(credentials.username, forKey: UserDefaultsKeys.username)
        } catch {
            credentialPersistenceErrorMessage = "Signed in, but Hermes could not save these credentials: \(error.localizedDescription)"
        }
    }

    func discardPendingManualCredentials() {
        pendingManualCredentials = nil
    }

    private static var defaultUserDefaults: UserDefaults {
        if isRunningTests {
            return UserDefaults(suiteName: "com.hermes.tests.login.\(UUID().uuidString)")!
        }
        return .standard
    }

    private static var isRunningTests: Bool {
        TestProcessDetection.isRunningTests
    }
    
    // MARK: - Error Types
    
    enum LoginError: Error {
        case authenticationFailed
    }

    private struct PendingManualCredentials {
        let username: String
        let password: String
    }
}
