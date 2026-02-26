//
//  NotificationNames.swift
//  Hermes
//
//  Type-safe notification names for Hermes app
//  Migrated from Notifications.{h,m}
//

import Foundation

/// Notification names used throughout Hermes
/// Provides type-safe access to notification names with proper namespacing
extension Notification.Name {
    
    // MARK: - Distributed Notifications
    
    /// Posted when a song is played (distributed to other processes)
    static let historyDidPlaySong = Notification.Name("hermes.song")
    
    /// Apple screensaver started (system notification)
    static let screensaverDidStart = Notification.Name("com.apple.screensaver.didstart")
    
    /// Apple screensaver stopped (system notification)
    static let screensaverDidStop = Notification.Name("com.apple.screensaver.didstop")
    
    /// Screen was locked (system notification)
    static let screenIsLocked = Notification.Name("com.apple.screenIsLocked")
    
    /// Screen was unlocked (system notification)
    static let screenIsUnlocked = Notification.Name("com.apple.screenIsUnlocked")
    
    // MARK: - Pandora API Notifications
    
    /// Pandora API returned an error (userInfo contains error)
    static let pandoraDidError = Notification.Name("PandoraDidErrorNotification")
    
    /// User successfully authenticated with Pandora
    static let pandoraDidAuthenticate = Notification.Name("PandoraDidAuthenticateNotification")
    
    /// User logged out of Pandora
    static let pandoraDidLogOut = Notification.Name("PandoraDidLogOutNotification")
    
    /// Song was rated (object contains Song)
    static let pandoraDidRateSong = Notification.Name("PandoraDidRateSongNotification")
    
    /// Song was marked as "tired" (object contains Song)
    static let pandoraDidTireSong = Notification.Name("PandoraDidTireSongNotification")
    
    /// Station list was loaded
    static let pandoraDidLoadStations = Notification.Name("PandoraDidLoadStationsNotification")
    
    /// New station was created (userInfo contains result)
    static let pandoraDidCreateStation = Notification.Name("PandoraDidCreateStationNotification")
    
    /// Station was deleted (object contains Station)
    static let pandoraDidDeleteStation = Notification.Name("PandoraDidDeleteStationNotification")
    
    /// Station was renamed
    static let pandoraDidRenameStation = Notification.Name("PandoraDidRenameStationNotification")
    
    /// Station info was loaded (userInfo contains info)
    static let pandoraDidLoadStationInfo = Notification.Name("PandoraDidLoadStationInfoNotification")
    
    /// Seed was added to station (userInfo contains result)
    static let pandoraDidAddSeed = Notification.Name("PandoraDidAddSeedNotification")
    
    /// Seed was deleted from station
    static let pandoraDidDeleteSeed = Notification.Name("PandoraDidDeleteSeedNotification")
    
    /// Feedback was deleted (object contains feedbackId string)
    static let pandoraDidDeleteFeedback = Notification.Name("PandoraDidDeleteFeedbackNotification")
    
    /// Search results were loaded (object: search string, userInfo: result)
    static let pandoraDidLoadSearchResults = Notification.Name("PandoraDidLoadSearchResultsNotification")
    
    /// Genre stations were loaded (userInfo contains result)
    static let pandoraDidLoadGenreStations = Notification.Name("PandoraDidLoadGenreStationsNotification")
    
    // MARK: - Playback Notifications
    
    /// Station started playing a song
    static let stationDidPlaySong = Notification.Name("StationDidPlaySongNotification")
    
    /// Playback state changed (playing/paused/stopped)
    static let playbackStateDidChange = Notification.Name("PlaybackStateDidChangeNotification")
    
    /// A new song started playing
    static let playbackSongDidChange = Notification.Name("PlaybackSongDidChangeNotification")
    
    /// Song progress updated
    static let playbackProgressDidChange = Notification.Name("PlaybackProgressDidChangeNotification")
    
    /// Album art was loaded
    static let playbackArtDidLoad = Notification.Name("PlaybackArtDidLoadNotification")
    
    /// Playback controller is ready
    static let playbackControllerReady = Notification.Name("PlaybackControllerReady")
    
    // MARK: - Audio Streamer Notifications
    
    /// Audio streamer bitrate is available
    static let audioBitrateReady = Notification.Name("ASBitrateReadyNotification")
    
    /// Audio streamer status changed
    static let audioStatusChanged = Notification.Name("ASStatusChangedNotification")
    
    /// Audio streamer state changed (distributed notification)
    static let audioStateDistributed = Notification.Name("hermes.state")
    
    /// New song started playing in playlist
    static let audioNewSongPlaying = Notification.Name("ASNewSongPlaying")
    
    /// No songs left in queue
    static let audioNoSongsLeft = Notification.Name("ASNoSongsLeft")
    
    /// Queue is running low on songs
    static let audioRunningOutOfSongs = Notification.Name("ASRunningOutOfSongs")
    
    /// New audio stream was created
    static let audioCreatedNewStream = Notification.Name("ASCreatedNewStream")
    
    /// Stream error occurred
    static let audioStreamError = Notification.Name("ASStreamError")
    
    /// Attempting to play a new song
    static let audioAttemptingNewSong = Notification.Name("ASAttemptingNewSong")
    
    // MARK: - Network Notifications
    
    /// Proxy validity changed
    static let proxyValidityChanged = Notification.Name("URLConnectionProxyValidityChangedNotification")
    
    // MARK: - UI Notifications
    
    /// Request to open settings window
    static let openSettingsRequested = Notification.Name("OpenSettingsRequested")
    
    /// Request to refresh stations list
    static let stationsRefreshRequested = Notification.Name("StationsRefreshRequested")
    
    // MARK: - Update Notifications

    /// Update check completed (userInfo: ["updateAvailable": Bool])
    static let updateCheckDidComplete = Notification.Name("HermesUpdateCheckDidCompleteNotification")

    /// Update check failed (userInfo: ["error": Error])
    static let updateCheckDidFail = Notification.Name("HermesUpdateCheckDidFailNotification")

    // MARK: - Preference Change Notifications
    
    /// "Always on top" preference changed
    static let preferenceAlwaysOnTopChanged = Notification.Name("PreferenceAlwaysOnTopChangedNotification")
    
    /// Media keys preference changed
    static let preferenceMediaKeysChanged = Notification.Name("PreferenceMediaKeysChangedNotification")
    
    /// Dock icon preference changed
    static let preferenceDockIconChanged = Notification.Name("PreferenceDockIconChangedNotification")
    
    /// Status bar preference changed
    static let preferenceStatusBarChanged = Notification.Name("PreferenceStatusBarChangedNotification")
}

// MARK: - Objective-C Compatibility

/// Provides Objective-C compatible notification name constants
/// These allow Objective-C code to continue using the same notification names
@objc public class HermesNotifications: NSObject {
    
    // MARK: - Distributed Notifications
    
    @objc public static let historyDidPlaySong = Notification.Name.historyDidPlaySong.rawValue
    @objc public static let screensaverDidStart = Notification.Name.screensaverDidStart.rawValue
    @objc public static let screensaverDidStop = Notification.Name.screensaverDidStop.rawValue
    @objc public static let screenIsLocked = Notification.Name.screenIsLocked.rawValue
    @objc public static let screenIsUnlocked = Notification.Name.screenIsUnlocked.rawValue
    
    // MARK: - Pandora API Notifications
    
    @objc public static let pandoraDidError = Notification.Name.pandoraDidError.rawValue
    @objc public static let pandoraDidAuthenticate = Notification.Name.pandoraDidAuthenticate.rawValue
    @objc public static let pandoraDidLogOut = Notification.Name.pandoraDidLogOut.rawValue
    @objc public static let pandoraDidRateSong = Notification.Name.pandoraDidRateSong.rawValue
    @objc public static let pandoraDidTireSong = Notification.Name.pandoraDidTireSong.rawValue
    @objc public static let pandoraDidLoadStations = Notification.Name.pandoraDidLoadStations.rawValue
    @objc public static let pandoraDidCreateStation = Notification.Name.pandoraDidCreateStation.rawValue
    @objc public static let pandoraDidDeleteStation = Notification.Name.pandoraDidDeleteStation.rawValue
    @objc public static let pandoraDidRenameStation = Notification.Name.pandoraDidRenameStation.rawValue
    @objc public static let pandoraDidLoadStationInfo = Notification.Name.pandoraDidLoadStationInfo.rawValue
    @objc public static let pandoraDidAddSeed = Notification.Name.pandoraDidAddSeed.rawValue
    @objc public static let pandoraDidDeleteSeed = Notification.Name.pandoraDidDeleteSeed.rawValue
    @objc public static let pandoraDidDeleteFeedback = Notification.Name.pandoraDidDeleteFeedback.rawValue
    @objc public static let pandoraDidLoadSearchResults = Notification.Name.pandoraDidLoadSearchResults.rawValue
    @objc public static let pandoraDidLoadGenreStations = Notification.Name.pandoraDidLoadGenreStations.rawValue
    
    // MARK: - Playback Notifications
    
    @objc public static let stationDidPlaySong = Notification.Name.stationDidPlaySong.rawValue
    @objc public static let playbackStateDidChange = Notification.Name.playbackStateDidChange.rawValue
    @objc public static let playbackSongDidChange = Notification.Name.playbackSongDidChange.rawValue
    @objc public static let playbackProgressDidChange = Notification.Name.playbackProgressDidChange.rawValue
    @objc public static let playbackArtDidLoad = Notification.Name.playbackArtDidLoad.rawValue
    @objc public static let playbackControllerReady = Notification.Name.playbackControllerReady.rawValue
    
    // MARK: - Audio Streamer Notifications
    
    @objc public static let audioBitrateReady = Notification.Name.audioBitrateReady.rawValue
    @objc public static let audioStatusChanged = Notification.Name.audioStatusChanged.rawValue
    @objc public static let audioStateDistributed = Notification.Name.audioStateDistributed.rawValue
    @objc public static let audioNewSongPlaying = Notification.Name.audioNewSongPlaying.rawValue
    @objc public static let audioNoSongsLeft = Notification.Name.audioNoSongsLeft.rawValue
    @objc public static let audioRunningOutOfSongs = Notification.Name.audioRunningOutOfSongs.rawValue
    @objc public static let audioCreatedNewStream = Notification.Name.audioCreatedNewStream.rawValue
    @objc public static let audioStreamError = Notification.Name.audioStreamError.rawValue
    @objc public static let audioAttemptingNewSong = Notification.Name.audioAttemptingNewSong.rawValue
    
    // MARK: - Network Notifications
    
    @objc public static let proxyValidityChanged = Notification.Name.proxyValidityChanged.rawValue
    
    // MARK: - UI Notifications
    
    @objc public static let openSettingsRequested = Notification.Name.openSettingsRequested.rawValue
    @objc public static let stationsRefreshRequested = Notification.Name.stationsRefreshRequested.rawValue
    
    // MARK: - Update Notifications

    @objc public static let updateCheckDidComplete = Notification.Name.updateCheckDidComplete.rawValue
    @objc public static let updateCheckDidFail = Notification.Name.updateCheckDidFail.rawValue

    // MARK: - Preference Change Notifications
    
    @objc public static let preferenceAlwaysOnTopChanged = Notification.Name.preferenceAlwaysOnTopChanged.rawValue
    @objc public static let preferenceMediaKeysChanged = Notification.Name.preferenceMediaKeysChanged.rawValue
    @objc public static let preferenceDockIconChanged = Notification.Name.preferenceDockIconChanged.rawValue
    @objc public static let preferenceStatusBarChanged = Notification.Name.preferenceStatusBarChanged.rawValue
}
