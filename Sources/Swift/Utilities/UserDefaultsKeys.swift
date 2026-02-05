//
//  UserDefaultsKeys.swift
//  Hermes
//
//  Centralized UserDefaults keys with type-safe access
//  All preference keys are defined here to avoid string literal duplication
//

import Foundation

/// Centralized UserDefaults keys for type-safe preference access
struct UserDefaultsKeys {
    private init() {}
    
    // MARK: - Authentication
    
    /// Pandora username for login
    static let username = "pandora.username"
    
    /// Whether to remember login credentials
    static let rememberLogin = "rememberLogin"
    
    // MARK: - Playback
    
    /// Current volume level (0-100)
    static let volume = "hermes.volume"
    
    /// Last played station ID
    static let lastStation = "lastStation"
    
    /// Audio quality setting (0=high, 1=medium, 2=low)
    static let audioQuality = "audioQuality"
    
    /// Whether to start playing automatically when a station is selected
    static let playOnStart = "playOnStart"
    
    /// Whether to pause playback when screensaver starts
    static let pauseOnScreensaverStart = "pauseOnScreensaverStart"
    
    /// Whether to resume playback when screensaver stops
    static let playOnScreensaverStop = "playOnScreensaverStop"
    
    /// Whether to pause playback when screen locks
    static let pauseOnScreenLock = "pauseOnScreenLock"
    
    /// Whether to resume playback when screen unlocks
    static let playOnScreenUnlock = "playOnScreenUnlock"
    
    /// Whether to start playing automatically on app launch
    static let playAutomaticallyOnLaunch = "playAutomaticallyOnLaunch"
    
    // MARK: - Last.fm Scrobbling
    
    /// Whether Last.fm scrobbling is enabled
    static let pleaseScrobble = "pleaseScrobble"
    
    /// Whether to scrobble liked songs (legacy key)
    static let pleaseScrobbleLikes = "pleaseScrobbleLikes"
    
    /// Whether to only scrobble liked songs
    static let onlyScrobbleLiked = "onlyScrobbleLiked"
    
    // MARK: - Notifications
    
    /// Whether notifications are enabled
    static let pleaseGrowl = "pleaseGrowl"
    
    /// Whether to show notification when playback starts
    static let pleaseGrowlPlay = "pleaseGrowlPlay"
    
    /// Whether to show notification when a new song starts
    static let pleaseGrowlNew = "pleaseGrowlNew"
    
    /// Notification type preference
    static let notificationType = "notificationType"
    
    // MARK: - Media Keys
    
    /// Whether media key handling is enabled
    static let pleaseBindMedia = "pleaseBindMedia"
    
    // MARK: - Window State
    
    /// Sidebar width for stations view
    static let sidebarWidth = "DRAWER_WIDTH"
    
    /// Sidebar width for history view
    static let historySidebarWidth = "HIST_DRAWER_WIDTH"
    
    /// Which sidebar is open (0=stations, 1=history)
    static let openDrawer = "OPEN_DRAWER"
    
    /// Whether to close the sidebar
    static let closeDrawer = "PLEASE_CLOSE_DRAWER"
    
    // MARK: - UI Preferences
    
    /// Whether to keep window always on top
    static let alwaysOnTop = "alwaysOnTop"
    
    /// Whether to show album art in dock icon
    static let dockIconAlbumArt = "dockIconAlbumArt"
    
    /// Whether to enable play/pause on album art click
    static let albumArtPlayPause = "albumArtPlayPause"
    
    /// Whether to show status bar icon
    static let statusBarIcon = "statusBarIcon"
    
    /// Whether to show song title in status bar
    static let statusBarShowSongTitle = "statusBarShowSongTitle"
    
    /// Whether to use black and white status bar icon
    static let statusBarIconBlackWhite = "statusBarIconBlackWhite"
    
    /// Whether to show album art in status bar icon
    static let statusBarIconAlbumArt = "statusBarIconAlbumArt"
    
    // MARK: - Station Management
    
    /// Station sorting preference
    static let sortStations = "sortStations"
    
    /// Station last played timestamps (dictionary of stationId -> timestamp)
    static let stationPlayTimestamps = "stationPlayTimestamps"
    
    // MARK: - Proxy Settings
    
    /// Enabled proxy type (0=system, 1=HTTP, 2=SOCKS)
    static let enabledProxy = "enabledProxy"
    
    /// HTTP proxy host
    static let httpProxyHost = "httpProxyHost"
    
    /// HTTP proxy port
    static let httpProxyPort = "httpProxyPort"
    
    /// SOCKS proxy host
    static let socksProxyHost = "socksProxyHost"
    
    /// SOCKS proxy port
    static let socksProxyPort = "socksProxyPort"
    
    /// Whether to proxy audio streaming
    static let proxyAudio = "proxyAudio"
}

// MARK: - Backward Compatibility Aliases

extension UserDefaultsKeys {
    /// Legacy key names for backward compatibility
    /// These map old preference keys to new standardized names
    struct Legacy {
        private init() {}
        
        /// Legacy "PLEASE_SCROBBLE" key (now pleaseScrobble)
        static let pleaseScrobbleUppercase = "PLEASE_SCROBBLE"
        
        /// Legacy "ONLY_SCROBBLE_LIKED" key (now onlyScrobbleLiked)
        static let onlyScrobbleLikedUppercase = "ONLY_SCROBBLE_LIKED"
        
        /// Legacy "PLEASE_GROWL" key (now pleaseGrowl)
        static let pleaseGrowlUppercase = "PLEASE_GROWL"
        
        /// Legacy "PLEASE_GROWL_PLAY" key (now pleaseGrowlPlay)
        static let pleaseGrowlPlayUppercase = "PLEASE_GROWL_PLAY"
        
        /// Legacy "PLEASE_GROWL_NEW" key (now pleaseGrowlNew)
        static let pleaseGrowlNewUppercase = "PLEASE_GROWL_NEW"
        
        /// Legacy "PLEASE_BIND_MEDIA" key (now pleaseBindMedia)
        static let pleaseBindMediaUppercase = "PLEASE_BIND_MEDIA"
        
        /// Legacy "ENABLED_PROXY" key (now enabledProxy)
        static let enabledProxyUppercase = "ENABLED_PROXY"
        
        /// Legacy "PROXY_AUDIO" key (now proxyAudio)
        static let proxyAudioUppercase = "PROXY_AUDIO"
        
        /// Legacy "DESIRED_QUALITY" key (now audioQuality)
        static let desiredQuality = "DESIRED_QUALITY"
    }
}
