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
    
    private let pandora: Pandora
    
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)
        return emailPredicate.evaluate(with: username)
    }
    
    var canSubmit: Bool {
        !username.isEmpty && !password.isEmpty && isValidEmail && !isLoading
    }
    
    init(pandora: Pandora) {
        self.pandora = pandora
    }
    
    func authenticate() async throws {
        guard canSubmit else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Save credentials
        UserDefaults.standard.set(username, forKey: "pandora.username")
        try? KeychainManager.shared.saveCredentials(username: username, password: password)
        
        // Authenticate
        let success = pandora.authenticate(username, password: password, request: nil)
        
        if !success {
            isLoading = false
            errorMessage = "Authentication failed"
            throw LoginError.authenticationFailed
        }
    }
    
    enum LoginError: Error {
        case authenticationFailed
    }
}
