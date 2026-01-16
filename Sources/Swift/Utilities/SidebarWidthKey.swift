//
//  SidebarWidthKey.swift
//  Hermes
//
//  Environment key for tracking sidebar width
//

import SwiftUI

// MARK: - Sidebar Width Environment Key

private struct SidebarWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 250 // Reasonable default for initial render
}

extension EnvironmentValues {
    var sidebarWidth: CGFloat {
        get { self[SidebarWidthKey.self] }
        set { self[SidebarWidthKey.self] = newValue }
    }
}

// MARK: - Sidebar Width Preference Key

struct SidebarWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0 // Start with 0 to hide artwork until actual width is measured
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
