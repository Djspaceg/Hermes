//
//  ViewModifiers.swift
//  Hermes
//
//  Reusable view modifiers for consistent styling
//

import SwiftUI

// MARK: - Content on Glass

extension View {
    /// Applies shadow styling for content displayed on glass surfaces.
    /// Use this for text and icons that appear over `.glassEffect()` backgrounds.
    func contentOnGlass() -> some View {
        self.shadow(color: .black.opacity(0.6), radius: 2)
    }
}
