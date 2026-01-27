//
//  SettingsManager.swift
//  Hermes
//
//  Centralized settings management - applies saved preferences at launch and on change
//

import SwiftUI
import Combine

@MainActor
final class SettingsManager: NSObject, ObservableObject {
    static let shared = SettingsManager()
    
    // MARK: - General Settings
    @AppStorage("pleaseBindMedia") var bindMediaKeys = true
    @AppStorage("statusBarIcon") var showStatusBarIcon = false
    @AppStorage("dockIconAlbumArt") var showAlbumArtInDock = false
    @AppStorage("albumArtPlayPause") var showPlayPauseOverArt = false
    @AppStorage("alwaysOnTop") var alwaysOnTop = false
    @AppStorage("statusBarShowSongTitle") var showSongInMenuBar = false
    @AppStorage("statusBarShowArtist") var showArtistInMenuBar = false
    @AppStorage("statusBarIconBlackWhite") var menuBarIconBW = false
    @AppStorage("statusBarIconAlbumArt") var menuBarIconAlbumArt = false
    
    // MARK: - Playback Settings
    @AppStorage("audioQuality") var audioQuality = 0
    @AppStorage("pleaseGrowl") var enableNotifications = false
    @AppStorage("notificationType") var notificationType = 1
    @AppStorage("pleaseGrowlNew") var notifyOnNewSong = true
    @AppStorage("pleaseGrowlPlay") var notifyOnResume = false
    @AppStorage("pleaseScrobble") var enableScrobbling = false
    @AppStorage("onlyScrobbleLiked") var onlyScrobbleLiked = false
    @AppStorage("pleaseScrobbleLikes") var scrobbleLikes = false
    @AppStorage("pauseOnScreensaverStart") var pauseOnScreensaver = true
    @AppStorage("playOnScreensaverStop") var playOnScreensaverStop = false
    @AppStorage("pauseOnScreenLock") var pauseOnLock = true
    @AppStorage("playOnScreenUnlock") var playOnUnlock = false
    @AppStorage("playAutomaticallyOnLaunch") var playAutomaticallyOnLaunch = true
    
    // MARK: - Network Settings
    @AppStorage("enabledProxy") var proxyType = 0
    @AppStorage("httpProxyHost") var httpProxyHost = ""
    @AppStorage("httpProxyPort") var httpProxyPort = 0
    @AppStorage("socksProxyHost") var socksProxyHost = ""
    @AppStorage("socksProxyPort") var socksProxyPort = 0
    @AppStorage("proxyAudio") var useProxyForAudio = false
    
    // MARK: - Update Settings
    @AppStorage("SUEnableAutomaticChecks") var automaticUpdateChecks = true
    @AppStorage("SUScheduledCheckInterval") var updateCheckInterval: Double = 86400
    @AppStorage("SUAutomaticallyUpdate") var automaticallyDownloadUpdates = true
    
    // MARK: - UI State
    @AppStorage("userCollapsedSidebar") var userCollapsedSidebar = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        setupScreensaverObservers()
        setupScreenLockObservers()
        setupPlaybackStateObserver()
    }
    
    // MARK: - Apply All Settings at Launch
    
    func applyAllSettings() {
        applyAlwaysOnTop()
        applyMediaKeys()
        // Note: applyStatusBarVisibility is NOT called here because windows
        // haven't been tracked yet. WindowTracker.windowOpened() handles
        // activation policy when windows appear.
    }
    
    // MARK: - Individual Setting Applications
    
    func applyAlwaysOnTop() {
        let level: NSWindow.Level = alwaysOnTop ? .floating : .normal
        for window in NSApp.windows where window.isVisible && !window.isSheet {
            window.level = level
        }
    }
    
    func applyMediaKeys() {
        guard let playbackController = MinimalAppDelegate.shared?.playbackController,
              let mediaKeyTap = playbackController.mediaKeyTap else { return }
        
        if bindMediaKeys {
            mediaKeyTap.startWatchingMediaKeys()
        } else {
            mediaKeyTap.stopWatchingMediaKeys()
        }
    }
    
    func applyDockIcon() {
        if showAlbumArtInDock {
            updateDockIconWithAlbumArt()
        } else {
            NSApp.applicationIconImage = nil
        }
    }
    
    func updateDockIconWithAlbumArt() {
        guard showAlbumArtInDock else { return }
        
        var image: NSImage?
        if let playbackController = MinimalAppDelegate.shared?.playbackController,
           let imageData = playbackController.lastImg {
            image = NSImage(data: imageData)
        }
        
        guard var image = image else {
            NSApp.applicationIconImage = NSImage(named: "AppIcon")
            return
        }
        
        if showPlayPauseOverArt {
            let isPlaying = MinimalAppDelegate.shared?.playbackController?.playing?.isPlaying() ?? false
            image = overlayPlayPauseIcon(on: image, isPlaying: isPlaying)
        }
        
        NSApp.applicationIconImage = image
    }
    
    private func overlayPlayPauseIcon(on image: NSImage, isPlaying: Bool) -> NSImage {
        let size = image.size
        let result = NSImage(size: size)
        
        result.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        
        let iconSize: CGFloat = size.width * 0.4
        let iconRect = NSRect(
            x: (size.width - iconSize) / 2,
            y: (size.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        
        let symbolName = isPlaying ? "pause.circle.fill" : "play.circle.fill"
        if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            // Create a white-tinted version of the symbol
            let tintedSymbol = symbol.copy() as! NSImage
            tintedSymbol.lockFocus()
            NSColor.white.set()
            NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
            tintedSymbol.unlockFocus()
            
            // Draw shadow first (offset down and slightly larger for blur effect)
            let shadowOffset: CGFloat = 2
            let shadowRect = iconRect.offsetBy(dx: 0, dy: -shadowOffset)
            
            if let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()
                context.setShadow(offset: CGSize(width: 0, height: -2), blur: 4, color: NSColor.black.withAlphaComponent(0.5).cgColor)
                tintedSymbol.draw(in: shadowRect)
                context.restoreGState()
            }
            
            // Draw the icon
            tintedSymbol.draw(in: iconRect)
        }
        
        result.unlockFocus()
        return result
    }
    
    // MARK: - Status Bar / Dock Icon Visibility
    
    func applyStatusBarVisibility(isInitialLaunch: Bool = false) {
        // WindowTracker handles both activation policy and dock icon in one place
        WindowTracker.shared.forceUpdate()
    }
    
    // MARK: - Screensaver Observers
    
    private func setupPlaybackStateObserver() {
        // Update dock icon when artwork loads
        NotificationCenter.default.publisher(for: Notification.Name("PlaybackArtDidLoadNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyDockIcon()
            }
            .store(in: &cancellables)
        
        // Update dock icon when playback state changes (for play/pause overlay)
        NotificationCenter.default.publisher(for: Notification.Name("ASStatusChangedNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyDockIcon()
            }
            .store(in: &cancellables)
    }
    
    private func setupScreensaverObservers() {
        DistributedNotificationCenter.default().publisher(for: Notification.Name("com.apple.screensaver.didstart"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleScreensaverStart()
            }
            .store(in: &cancellables)
        
        DistributedNotificationCenter.default().publisher(for: Notification.Name("com.apple.screensaver.didstop"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleScreensaverStop()
            }
            .store(in: &cancellables)
    }
    
    private func handleScreensaverStart() {
        guard pauseOnScreensaver else { return }
        MinimalAppDelegate.shared?.playbackController?.pause()
    }
    
    private func handleScreensaverStop() {
        guard playOnScreensaverStop else { return }
        MinimalAppDelegate.shared?.playbackController?.play()
    }
    
    // MARK: - Screen Lock Observers
    
    private func setupScreenLockObservers() {
        DistributedNotificationCenter.default().publisher(for: Notification.Name("com.apple.screenIsLocked"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleScreenLock()
            }
            .store(in: &cancellables)
        
        DistributedNotificationCenter.default().publisher(for: Notification.Name("com.apple.screenIsUnlocked"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleScreenUnlock()
            }
            .store(in: &cancellables)
    }
    
    private func handleScreenLock() {
        guard pauseOnLock else { return }
        MinimalAppDelegate.shared?.playbackController?.pause()
    }
    
    private func handleScreenUnlock() {
        guard playOnUnlock else { return }
        MinimalAppDelegate.shared?.playbackController?.play()
    }
}
