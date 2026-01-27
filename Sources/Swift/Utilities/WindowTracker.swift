//
//  WindowTracker.swift
//  Hermes
//
//  Tracks open windows and manages activation policy and dock icon for accessory mode
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
        updateAppPresentation()
    }
    
    func windowClosed(_ identifier: String) {
        print("WindowTracker: Window closed - \(identifier)")
        openWindows.remove(identifier)
        updateAppPresentation()
    }
    
    /// Force update based on current state - call when settings change
    func forceUpdate() {
        print("WindowTracker: Force update - open windows: \(openWindows)")
        updateAppPresentation()
    }
    
    // MARK: - Unified App Presentation Logic
    
    /// Single method that handles both activation policy and dock icon
    /// Rules:
    /// 1. If accessory mode disabled → regular mode, apply dock icon setting
    /// 2. If accessory mode enabled AND no windows → accessory mode (no dock icon visible)
    /// 3. If accessory mode enabled AND windows open → regular mode, apply dock icon setting
    private func updateAppPresentation() {
        let wantsAccessoryMode = SettingsManager.shared.showStatusBarIcon
        let hasOpenWindows = !openWindows.isEmpty
        
        // Determine target activation policy
        let targetPolicy: NSApplication.ActivationPolicy = (wantsAccessoryMode && !hasOpenWindows) ? .accessory : .regular
        let currentPolicy = NSApp.activationPolicy()
        
        print("WindowTracker: updateAppPresentation - wantsAccessory=\(wantsAccessoryMode), hasWindows=\(hasOpenWindows), current=\(currentPolicy.rawValue), target=\(targetPolicy.rawValue)")
        
        // Apply activation policy if changed
        if currentPolicy != targetPolicy {
            print("WindowTracker: Switching to .\(targetPolicy == .accessory ? "accessory" : "regular")")
            NSApp.setActivationPolicy(targetPolicy)
            
            // When switching TO regular mode, activate the app
            if targetPolicy == .regular {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        
        // Always apply dock icon when in regular mode (dock is visible)
        if targetPolicy == .regular {
            print("WindowTracker: Applying dock icon (regular mode)")
            SettingsManager.shared.applyDockIcon()
        }
    }
}
