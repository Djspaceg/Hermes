//
//  ErrorView.swift
//  Hermes
//
//  Error view with retry button
//

import SwiftUI

struct ErrorView: View {
    // MARK: - Properties
    
    let errorMessage: String
    let onRetry: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title)
                .fontWeight(.semibold)
            
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.glassProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}


// MARK: - Preview

#Preview("Error View") {
    ErrorView(errorMessage: "Failed to connect to Pandora servers. Please check your internet connection and try again.") {
        print("Retry tapped")
    }
}
