//
//  WindowTracker.swift
//  Hermes
//
//  Tracks open windows and manages activation policy for accessory mode
//

import SwiftUI
import AppKit

@MainActor
final class WindowTracker: ObservableObject {
    static let shared = WindowTracker()
    
    @Published private(set) var openWindows: Set<String> = []
    
    private init() {}
    
    func windowOpened(_ identifier: String) {
        print("WindowTracker: Window opened - \(identifier)")
        openWindows.insert(identifier)
        updateActivationPolicy()
    }
    
    func windowClosed(_ identifier: String) {
        print("WindowTracker: Window closed - \(identifier)")
        openWindows.remove(identifier)
        updateActivationPolicy()
    }
    
    /// Force update activation policy based on current settings
    func forceUpdate() {
        print("WindowTracker: Force update - open windows: \(openWindows)")
        updateActivationPolicy()
    }
    
    private func updateActivationPolicy() {
        // Only manage activation policy if user has enabled status bar icon (accessory mode)
        guard SettingsManager.shared.showStatusBarIcon else {
            // User wants regular mode, ensure we're in it
            if NSApp.activationPolicy() != .regular {
                print("WindowTracker: Switching to .regular (user preference)")
                NSApp.setActivationPolicy(.regular)
            }
            return
        }
        
        // User wants accessory mode - but only switch to .accessory when NO windows are open
        // Always allow windows to open by staying in .regular when windows exist
        if openWindows.isEmpty {
            // No windows open, switch to accessory to hide dock icon
            if NSApp.activationPolicy() != .accessory {
                print("WindowTracker: Switching to .accessory (no windows)")
                NSApp.setActivationPolicy(.accessory)
            }
        } else {
            // Windows are open, MUST be in regular mode for windows to display
            if NSApp.activationPolicy() != .regular {
                print("WindowTracker: Switching to .regular (\(openWindows.count) windows open)")
                NSApp.setActivationPolicy(.regular)
            }
        }
    }
}
