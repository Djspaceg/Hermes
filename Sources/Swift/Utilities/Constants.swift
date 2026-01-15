//
//  Constants.swift
//  Hermes
//
//  Type-safe Swift constants migrated from HermesConstants.h
//  Objective-C code continues to use HermesConstants.h macros
//

import Foundation

// MARK: - Proxy Type

/// Proxy configuration type for network connections
enum ProxyType: Int, CaseIterable {
    case system = 0
    case http = 1
    case socks = 2
    
    var displayName: String {
        switch self {
        case .system: return "System Proxy"
        case .http: return "HTTP Proxy"
        case .socks: return "SOCKS Proxy"
        }
    }
}

// MARK: - Audio Quality

/// Audio streaming quality setting
enum AudioQuality: Int, CaseIterable {
    case high = 0
    case medium = 1
    case low = 2
    
    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

// MARK: - Station Sort Order

/// Station list sorting options
enum StationSortOrder: Int, CaseIterable {
    case dateAscending = 0
    case dateDescending = 1
    case nameAscending = 2
    case nameDescending = 3
    
    var displayName: String {
        switch self {
        case .dateAscending: return "Date (Oldest First)"
        case .dateDescending: return "Date (Newest First)"
        case .nameAscending: return "Name (A-Z)"
        case .nameDescending: return "Name (Z-A)"
        }
    }
}

// MARK: - UserDefaults Keys

/// Type-safe UserDefaults keys matching HermesConstants.h macros
struct UserDefaultsKeys {
    private init() {}
    
    // MARK: Proxy Settings
    static let enabledProxy = "enabledProxy"
    static let httpProxyHost = "httpProxyHost"
    static let httpProxyPort = "httpProxyPort"
    static let socksProxyHost = "socksProxyHost"
    static let socksProxyPort = "socksProxyPort"
    static let proxyAudio = "proxyAudio"
    
    // MARK: Audio Quality
    static let audioQuality = "audioQuality"
    
    // MARK: Last.fm Scrobbling
    static let pleaseScrobble = "pleaseScrobble"
    static let pleaseScrobbleLikes = "pleaseScrobbleLikes"
    static let onlyScrobbleLiked = "onlyScrobbleLiked"
    
    // MARK: Station Sorting
    static let sortStations = "sortStations"
    
    // MARK: Playback Settings
    static let lastStation = "lastStation"
    static let pauseOnScreensaverStart = "pauseOnScreensaverStart"
    static let playOnScreensaverStop = "playOnScreensaverStop"
    static let pauseOnScreenLock = "pauseOnScreenLock"
    static let playOnScreenUnlock = "playOnScreenUnlock"
    static let playAutomaticallyOnLaunch = "playAutomaticallyOnLaunch"
    
    // MARK: UI Settings
    static let pleaseBindMedia = "pleaseBindMedia"
    static let statusBarIcon = "statusBarIcon"
    static let dockIconAlbumArt = "dockIconAlbumArt"
    static let albumArtPlayPause = "albumArtPlayPause"
    static let alwaysOnTop = "alwaysOnTop"
    static let statusBarShowSongTitle = "statusBarShowSongTitle"
    static let statusBarIconBlackWhite = "statusBarIconBlackWhite"
    static let statusBarIconAlbumArt = "statusBarIconAlbumArt"
    
    // MARK: Notification Settings
    static let pleaseGrowl = "pleaseGrowl"
    static let notificationType = "notificationType"
    static let pleaseGrowlNew = "pleaseGrowlNew"
    static let pleaseGrowlPlay = "pleaseGrowlPlay"
}

// MARK: - Objective-C Compatibility

/// Objective-C compatible wrapper for Swift constants
/// Use this class when Objective-C code needs access to Swift-defined constants
@objc(HermesSwiftConstants)
@objcMembers
final class HermesSwiftConstants: NSObject {
    
    // MARK: Proxy Types
    static let proxyTypeSystem: Int = ProxyType.system.rawValue
    static let proxyTypeHTTP: Int = ProxyType.http.rawValue
    static let proxyTypeSOCKS: Int = ProxyType.socks.rawValue
    
    // MARK: Audio Quality
    static let audioQualityHigh: Int = AudioQuality.high.rawValue
    static let audioQualityMedium: Int = AudioQuality.medium.rawValue
    static let audioQualityLow: Int = AudioQuality.low.rawValue
    
    // MARK: Station Sort Order
    static let sortDateAscending: Int = StationSortOrder.dateAscending.rawValue
    static let sortDateDescending: Int = StationSortOrder.dateDescending.rawValue
    static let sortNameAscending: Int = StationSortOrder.nameAscending.rawValue
    static let sortNameDescending: Int = StationSortOrder.nameDescending.rawValue
    
    // MARK: UserDefaults Keys
    static let keyEnabledProxy: String = UserDefaultsKeys.enabledProxy
    static let keyHttpProxyHost: String = UserDefaultsKeys.httpProxyHost
    static let keyHttpProxyPort: String = UserDefaultsKeys.httpProxyPort
    static let keySocksProxyHost: String = UserDefaultsKeys.socksProxyHost
    static let keySocksProxyPort: String = UserDefaultsKeys.socksProxyPort
    static let keyProxyAudio: String = UserDefaultsKeys.proxyAudio
    static let keyAudioQuality: String = UserDefaultsKeys.audioQuality
    static let keyPleaseScrobble: String = UserDefaultsKeys.pleaseScrobble
    static let keyPleaseScrobbleLikes: String = UserDefaultsKeys.pleaseScrobbleLikes
    static let keyOnlyScrobbleLiked: String = UserDefaultsKeys.onlyScrobbleLiked
    static let keySortStations: String = UserDefaultsKeys.sortStations
    static let keyLastStation: String = UserDefaultsKeys.lastStation
    static let keyPauseOnScreensaverStart: String = UserDefaultsKeys.pauseOnScreensaverStart
    static let keyPlayOnScreensaverStop: String = UserDefaultsKeys.playOnScreensaverStop
    static let keyPauseOnScreenLock: String = UserDefaultsKeys.pauseOnScreenLock
    static let keyPlayOnScreenUnlock: String = UserDefaultsKeys.playOnScreenUnlock
    static let keyPlayAutomaticallyOnLaunch: String = UserDefaultsKeys.playAutomaticallyOnLaunch
    
    // MARK: UI Settings Keys
    static let keyPleaseBindMedia: String = UserDefaultsKeys.pleaseBindMedia
    static let keyStatusBarIcon: String = UserDefaultsKeys.statusBarIcon
    static let keyDockIconAlbumArt: String = UserDefaultsKeys.dockIconAlbumArt
    static let keyAlbumArtPlayPause: String = UserDefaultsKeys.albumArtPlayPause
    static let keyAlwaysOnTop: String = UserDefaultsKeys.alwaysOnTop
    static let keyStatusBarShowSongTitle: String = UserDefaultsKeys.statusBarShowSongTitle
    static let keyStatusBarIconBlackWhite: String = UserDefaultsKeys.statusBarIconBlackWhite
    static let keyStatusBarIconAlbumArt: String = UserDefaultsKeys.statusBarIconAlbumArt
    
    // MARK: Notification Settings Keys
    static let keyPleaseGrowl: String = UserDefaultsKeys.pleaseGrowl
    static let keyNotificationType: String = UserDefaultsKeys.notificationType
    static let keyPleaseGrowlNew: String = UserDefaultsKeys.pleaseGrowlNew
    static let keyPleaseGrowlPlay: String = UserDefaultsKeys.pleaseGrowlPlay
    
    private override init() {
        super.init()
    }
}
