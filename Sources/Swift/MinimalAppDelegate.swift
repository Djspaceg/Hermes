//
//  MinimalAppDelegate.swift
//  Hermes
//
//  Minimal AppDelegate for Objective-C integration only
//  Does NOT manage UI - only handles notifications and business logic callbacks
//

import Cocoa
import Combine

/// Minimal AppDelegate for Objective-C business logic integration
/// UI is completely managed by SwiftUI
@objc class MinimalAppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // Expose controllers for Swift and Objective-C access
    @objc static var shared: MinimalAppDelegate?
    @objc private(set) var playbackController: PlaybackController?
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("MinimalAppDelegate: applicationDidFinishLaunching")
        
        MinimalAppDelegate.shared = self
        
        // Configure main window for transparent title bar
        configureMainWindow()
        
        // Create PlaybackController
        print("MinimalAppDelegate: Creating PlaybackController...")
        playbackController = PlaybackController()
        print("MinimalAppDelegate: PlaybackController created = \(String(describing: playbackController))")
        
        // Initialize the controller (sets up notification observers, media keys, etc.)
        print("MinimalAppDelegate: Setting up PlaybackController...")
        playbackController?.setup()
        print("MinimalAppDelegate: PlaybackController setup completed")
        
        // Set up notification observers for Pandora API callbacks
        setupNotificationObservers()
        
        // Register default preferences
        registerDefaults()
        
        // Initialize media key handler
        setupMediaKeys()
        
        // Prepare playback controller
        print("MinimalAppDelegate: Preparing playback...")
        preparePlayback()
        print("MinimalAppDelegate: Initialization complete")
        
        // Notify that playback controller is ready
        NotificationCenter.default.post(name: Notification.Name("PlaybackControllerReady"), object: nil)
        
        // Apply all settings (activation policy, dock icon, media keys, etc.)
        SettingsManager.shared.applyAllSettings()
    }
    
    private func configureMainWindow() {
        // Delay slightly to ensure SwiftUI window is created
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" || $0.title == "Hermes" }) else {
                // Try again if window not found yet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.configureMainWindow()
                }
                return
            }
            
            // Make title bar transparent with content underneath
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            
            // Keep traffic lights visible
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Save state before terminating
        saveState()
    }
    
    func applicationWillResignActive(_ notification: Notification) {
        // Save state when app becomes inactive
        saveState()
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        let center = NotificationCenter.default
        
        // Observe Pandora errors
        center.addObserver(
            self,
            selector: #selector(handlePandoraError(_:)),
            name: Notification.Name("PandoraDidErrorNotification"),
            object: nil
        )
        
        // Observe logout
        center.addObserver(
            self,
            selector: #selector(handleLogout(_:)),
            name: Notification.Name("PandoraDidLogOutNotification"),
            object: nil
        )
        
        // Observe sleep notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        // Observe preference changes from SwiftUI Settings
        center.addObserver(
            self,
            selector: #selector(handleAlwaysOnTopChanged(_:)),
            name: Notification.Name("PreferenceAlwaysOnTopChangedNotification"),
            object: nil
        )
        
        center.addObserver(
            self,
            selector: #selector(handleMediaKeysChanged(_:)),
            name: Notification.Name("PreferenceMediaKeysChangedNotification"),
            object: nil
        )
        
        center.addObserver(
            self,
            selector: #selector(handleDockIconChanged(_:)),
            name: Notification.Name("PreferenceDockIconChangedNotification"),
            object: nil
        )
        
        center.addObserver(
            self,
            selector: #selector(handleStatusBarChanged(_:)),
            name: Notification.Name("PreferenceStatusBarChangedNotification"),
            object: nil
        )
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handlePandoraError(_ notification: Notification) {
        // Forward to Swift via NotificationCenter publisher
        // AppState will handle displaying error
    }
    
    @objc private func handleStreamError(_ notification: Notification) {
        // Forward to Swift via NotificationCenter publisher
    }
    
    @objc private func handleLogout(_ notification: Notification) {
        // Forward to Swift via NotificationCenter publisher
    }
    
    @objc private func handleSleep(_ notification: Notification) {
        // Pause playback when system sleeps
        if let playbackController = getPlaybackController() {
            playbackController.pause()
        }
    }
    
    // MARK: - Preference Change Handlers
    
    @objc private func handleAlwaysOnTopChanged(_ notification: Notification) {
        let alwaysOnTop = UserDefaults.standard.bool(forKey: UserDefaultsKeys.alwaysOnTop)
        
        // Find the main window and set its level
        if let window = NSApp.windows.first(where: { $0.isKeyWindow || $0.isMainWindow }) {
            window.level = alwaysOnTop ? .floating : .normal
        }
    }
    
    @objc private func handleMediaKeysChanged(_ notification: Notification) {
        // Re-initialize media keys with current preference
        playbackController?.setupMediaKeys()
    }
    
    @objc private func handleDockIconChanged(_ notification: Notification) {
        let showAlbumArt = UserDefaults.standard.bool(forKey: UserDefaultsKeys.dockIconAlbumArt)
        
        if showAlbumArt {
            // Get current album art from playback and set as dock icon
            if let imageData = playbackController?.lastImg,
               let image = NSImage(data: imageData) {
                NSApp.applicationIconImage = image
            }
        } else {
            // Reset to default icon
            NSApp.applicationIconImage = nil
        }
    }
    
    @objc private func handleStatusBarChanged(_ notification: Notification) {
        // Status bar functionality would need a StatusBarManager
        // For now, just log that the setting changed
        print("Status bar setting changed")
    }
    
    // MARK: - Setup Methods
    
    private func registerDefaults() {
        let defaults: [String: Any] = [
            "PLEASE_SCROBBLE": false,
            "ONLY_SCROBBLE_LIKED": false,
            "PLEASE_GROWL": true,
            "PLEASE_GROWL_PLAY": false,
            "PLEASE_GROWL_NEW": true,
            "PLEASE_BIND_MEDIA": true,
            "PLEASE_CLOSE_DRAWER": false,
            "ENABLED_PROXY": 0,
            "PROXY_AUDIO": false,
            "DESIRED_QUALITY": 1, // Medium quality
            "OPEN_DRAWER": 0, // Stations
            "HIST_DRAWER_WIDTH": 150,
            "DRAWER_WIDTH": 130
        ]
        
        UserDefaults.standard.register(defaults: defaults)
    }
    
    func setupMediaKeys() {
        // Media keys are handled by MediaKeyHandler in AppState
        // This is just a placeholder for any additional setup
    }
    
    private func preparePlayback() {
        // Initialize playback controller
        playbackController?.prepareFirst()
    }
    
    private func saveState() {
        // Save playback state
        playbackController?.saveState()
    }
    
    private func getPlaybackController() -> PlaybackController? {
        return playbackController
    }
    
    // MARK: - Objective-C Compatibility
    
    @objc func logMessage(_ message: String) {
        // Log message for Pandora API
        print("Pandora: \(message)")
    }
    
    @objc func showLoader() {
        // SwiftUI handles loading state
        // This is called by PlaybackController but we don't need it
    }
    
    @objc func show() {
        // SwiftUI handles view state
        // This is called by PlaybackController but we don't need it
    }
    
    @objc func setCurrentView(_ view: NSView) {
        // SwiftUI handles all views
        // This is called by legacy code but we don't need it
    }
    
    @objc func stateDirectory(_ file: String) -> String? {
        // Return path for state files
        let fileManager = FileManager.default
        let folder = NSString(string: "~/Library/Application Support/Hermes/").expandingTildeInPath
        
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: folder, isDirectory: &isDirectory) {
            try? fileManager.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
        }
        
        return (folder as NSString).appendingPathComponent(file)
    }
    
    @objc func pandora() -> Pandora {
        // Return the shared Pandora instance
        // Use MainActor.assumeIsolated since this is called from main thread contexts
        return MainActor.assumeIsolated {
            AppState.shared.pandora
        }
    }
    
    @objc func updateStatusItem(_ sender: Any?) {
        // SwiftUI doesn't use status bar items
        // This is called by PlaybackController but we don't need it
    }
    
    @objc func window() -> NSWindow? {
        // Return nil - SwiftUI manages windows
        return nil
    }
}
