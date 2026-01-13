//
//  DoubleClickModifier.swift
//  Hermes
//
//  Shared double-click modifier for SwiftUI views
//

import SwiftUI

// MARK: - Double Click View Modifier

extension View {
    /// Adds a double-click handler that works with List selection
    func onDoubleClick(perform action: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            TapGesture(count: 2).onEnded {
                action()
            }
        )
    }
}
