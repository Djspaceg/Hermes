//
//  LoginViewModel.swift
//  Hermes
//
//  Manages authentication state
//

import Foundation
import Combine
import Observation

@MainActor
@Observable
final class LoginViewModel {
    // MARK: - Properties
    
    var username: String = ""
    var password: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    
    @ObservationIgnored
    private let pandora: PandoraClient
    
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
    
    init(pandora: PandoraClient) {
        self.pandora = pandora
    }
    
    // MARK: - Public Methods
    
    func authenticate() async throws {
        guard canSubmit else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Save credentials
            UserDefaults.standard.set(username, forKey: UserDefaultsKeys.username)
            try? KeychainManager.shared.saveCredentials(username: username, password: password)
            
            // Authenticate using async/await
            try await pandora.authenticate(username: username, password: password)
            
            isLoading = false
        } catch {
            isLoading = false
            
            // Extract error message
            if let pandoraError = error as? PandoraError {
                switch pandoraError {
                case .invalidUsername, .invalidPassword:
                    errorMessage = "Invalid username or password"
                case .apiError(let code, let message):
                    errorMessage = message
                    print("LoginViewModel: API error \(code): \(message)")
                case .networkError(let httpError):
                    errorMessage = "Network error: \(httpError.localizedDescription)"
                    print("LoginViewModel: Network error: \(httpError)")
                default:
                    errorMessage = "Authentication failed: \(error.localizedDescription)"
                    print("LoginViewModel: Auth error: \(error)")
                }
            } else {
                errorMessage = "Authentication failed: \(error.localizedDescription)"
                print("LoginViewModel: Unexpected error: \(error)")
            }
            
            throw LoginError.authenticationFailed
        }
    }
    
    // MARK: - Error Types
    
    enum LoginError: Error {
        case authenticationFailed
    }
}
