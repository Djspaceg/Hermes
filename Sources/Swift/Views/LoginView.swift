//
//  LoginView.swift
//  Hermes
//
//  Login view for Pandora authentication
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    
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
                
                Button("Sign In") {
                    Task {
                        try? await viewModel.authenticate()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSubmit)
                .frame(width: 300)
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}


// MARK: - Preview

#Preview {
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
                    .buttonStyle(.borderedProminent)
                    .frame(width: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
