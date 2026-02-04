//
//  LoginViewModel.swift
//  Hermes
//
//  Manages authentication state
//

import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let pandora: PandoraClient
    
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)
        return emailPredicate.evaluate(with: username)
    }
    
    var canSubmit: Bool {
        !username.isEmpty && !password.isEmpty && isValidEmail && !isLoading
    }
    
    init(pandora: PandoraClient) {
        self.pandora = pandora
    }
    
    func authenticate() async throws {
        guard canSubmit else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Save credentials
            UserDefaults.standard.set(username, forKey: "pandora.username")
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
    
    enum LoginError: Error {
        case authenticationFailed
    }
}
