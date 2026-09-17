//
//  LoginView.swift
//  Hermes
//
//  Login view for Pandora authentication
//

import SwiftUI

struct LoginView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: LoginViewModel
    let onRetrySavedCredentials: () -> Void

    init(
        viewModel: LoginViewModel,
        onRetrySavedCredentials: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onRetrySavedCredentials = onRetrySavedCredentials
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 24) {
            // Logo/Title
            VStack(spacing: 8) {
                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Hermes")
                    .font(.system(size: 32, weight: .bold))
                
                Text("Pandora Client for macOS")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
            
            // Login form
            VStack(spacing: 16) {
                TextField("Email", text: $viewModel.username)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                
                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                if let message = viewModel.credentialAvailabilityMessage {
                    VStack(spacing: 8) {
                        Text(message)
                            .foregroundColor(.orange)
                            .font(.caption)
                            .multilineTextAlignment(.center)

                        Button("Retry Saved Credentials") {
                            onRetrySavedCredentials()
                        }
                    }
                    .frame(width: 300)
                }

                if let message = viewModel.credentialPersistenceErrorMessage {
                    Text(message)
                        .foregroundColor(.orange)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .frame(width: 300)
                }
                
                Button("Sign In") {
                    Task {
                        try? await viewModel.authenticate()
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(!viewModel.canSubmit)
                .frame(width: 300)
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


// MARK: - Preview

#Preview("Login") {
    LoginPreview()
        .frame(width: 400, height: 300)
}

private struct LoginPreview: View {
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Hermes")
                    .font(.system(size: 32, weight: .bold))
                
                Text("Pandora Client for macOS")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
            
            VStack(spacing: 16) {
                TextField("Email", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                
                Button("Sign In") {}
                    .buttonStyle(.glassProminent)
                    .frame(width: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
