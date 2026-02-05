//
//  GlassButton.swift
//  Hermes
//
//  Reusable button component with glass morphism effect
//

import SwiftUI

@available(macOS 26.0, *)
// MARK: - Glass Button

/// Reusable button with glass morphism effect
///
/// A configurable button component that provides a consistent glass effect
/// styling across the application. Supports customizable icons, sizes,
/// actions, and enabled states.
///
/// ## Usage
///
/// ```swift
/// GlassButton(icon: "play.fill", action: { print("Play") })
/// GlassButton(icon: "pause.fill", size: 60, action: { print("Pause") })
/// GlassButton(icon: "forward.fill", isEnabled: false, action: { })
/// ```
struct GlassButton: View {
    // MARK: - Properties
    
    /// SF Symbol name for the button icon
    let icon: String
    
    /// Action to perform when button is tapped
    let action: () -> Void
    
    /// Size of the button (width and height)
    var size: CGFloat = 44
    
    /// Whether the button is enabled and interactive
    var isEnabled: Bool = true
    
    /// Optional accessibility label
    var accessibilityLabel: String?
    
    /// Optional help text (tooltip)
    var helpText: String?
    
    // MARK: - Body
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.5))
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
        .accessibilityLabel(accessibilityLabel ?? icon)
        .help(helpText ?? "")
    }
}

// MARK: - Previews

#Preview("Default Size") {
    GlassButton(icon: "play.fill", action: { print("Play") })
        .padding()
        .frame(width: 100, height: 100)
        .background(.black)
}

#Preview("Large Size") {
    GlassButton(icon: "pause.fill", action: { print("Pause") }, size: 80)
        .padding()
        .frame(width: 150, height: 150)
        .background(.black)
}

#Preview("Small Size") {
    GlassButton(icon: "forward.fill", action: { print("Next") }, size: 32)
        .padding()
        .frame(width: 80, height: 80)
        .background(.black)
}

#Preview("Disabled") {
    GlassButton(
        icon: "play.fill",
        action: { print("Play") },
        isEnabled: false
    )
    .padding()
    .frame(width: 100, height: 100)
    .background(.black)
}

#Preview("With Help Text") {
    GlassButton(
        icon: "heart.fill",
        action: { print("Like") },
        helpText: "Like this song"
    )
    .padding()
    .frame(width: 100, height: 100)
    .background(.black)
}

#Preview("Multiple Buttons") {
    HStack(spacing: 16) {
        GlassButton(icon: "backward.fill", action: { })
        GlassButton(icon: "play.fill", action: { }, size: 60)
        GlassButton(icon: "forward.fill", action: { })
    }
    .padding()
    .background(.black)
}
