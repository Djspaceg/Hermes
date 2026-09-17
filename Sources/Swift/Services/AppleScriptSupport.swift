//
//  AppleScriptSupport.swift
//  Hermes
//
//  Modern Swift implementation of AppleScript command handlers
//  Provides scripting bridge compatibility for automation
//

import Cocoa

// MARK: - Playback State Enum

/// Playback states matching iTunes conventions (4-char codes)
@objc enum PlaybackState: Int {
    case stopped = 0x73746F70  // 'stop'
    case playing = 0x706C6179  // 'play'
    case paused  = 0x70617573  // 'paus'
}

/// Application presentation modes exposed to AppleScript.
@objc enum InterfaceMode: Int {
    case windowed = 0x77696E64  // 'wind'
    case menuBar = 0x6D626172  // 'mbar'
}

// MARK: - Command Classes

/// Play command - Resume playing the current song
@MainActor
@objc(PlayCommand)
class PlayCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let playback = MinimalAppDelegate.shared?.playbackController else {
            return NSNumber(value: false)
        }
        return AppleScriptSupport.onMainThread {
            NSNumber(value: playback.play())
        }
    }
}

/// Pause command - Pause the currently playing song
@MainActor
@objc(PauseCommand)
class PauseCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let playback = MinimalAppDelegate.shared?.playbackController else {
            return NSNumber(value: false)
        }
        return AppleScriptSupport.onMainThread {
            NSNumber(value: playback.pause())
        }
    }
}

/// Play/Pause toggle command
@MainActor
@objc(PlayPauseCommand)
class PlayPauseCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let playback = MinimalAppDelegate.shared?.playbackController else {
            return self
        }
        AppleScriptSupport.onMainThread {
            playback.playpause()
        }
        return self
    }
}

/// Skip command - Skip to the next song
@MainActor
@objc(SkipCommand)
class SkipCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let playback = MinimalAppDelegate.shared?.playbackController else {
            return self
        }
        AppleScriptSupport.onMainThread {
            playback.next()
        }
        return self
    }
}

/// Thumbs up command - Like the current song
@MainActor
@objc(ThumbsUpCommand)
class ThumbsUpCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let playback = MinimalAppDelegate.shared?.playbackController else {
            return self
        }
        AppleScriptSupport.onMainThread {
            playback.likeCurrent()
        }
        return self
    }
}

/// Thumbs down command - Dislike the current song
@MainActor
@objc(ThumbsDownCommand)
class ThumbsDownCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let playback = MinimalAppDelegate.shared?.playbackController else {
            return self
        }
        AppleScriptSupport.onMainThread {
            playback.dislikeCurrent()
        }
        return self
    }
}

/// Raise volume command - Increase playback volume
@MainActor
@objc(RaiseVolumeCommand)
class RaiseVolumeCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let playback = MinimalAppDelegate.shared?.playbackController else {
            return self
        }
        AppleScriptSupport.onMainThread {
            let currentVolume = playback.volume
            playback.volume = currentVolume + 7
            print("Raised volume to: \(playback.volume)")
        }
        return self
    }
}

/// Lower volume command - Decrease playback volume
@MainActor
@objc(LowerVolumeCommand)
class LowerVolumeCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let playback = MinimalAppDelegate.shared?.playbackController else {
            return self
        }
        AppleScriptSupport.onMainThread {
            let currentVolume = playback.volume
            playback.volume = currentVolume - 7
            print("Lowered volume to: \(playback.volume)")
        }
        return self
    }
}

/// Full volume command - Set volume to maximum
@MainActor
@objc(FullVolumeCommand)
class FullVolumeCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let playback = MinimalAppDelegate.shared?.playbackController else {
            return self
        }
        AppleScriptSupport.onMainThread {
            playback.volume = 100
            print("Changed volume to: \(playback.volume)")
        }
        return self
    }
}

/// Mute command - Mute playback, saving current volume
@MainActor
@objc(MuteCommand)
class MuteCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let playback = MinimalAppDelegate.shared?.playbackController else {
            return self
        }
        AppleScriptSupport.onMainThread {
            AppleScriptSupport.savedVolume = playback.volume
            playback.volume = 0
            print("Changed volume to: \(playback.volume)")
        }
        return self
    }
}

/// Unmute command - Restore volume to pre-mute level
@MainActor
@objc(UnmuteCommand)
class UnmuteCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let playback = MinimalAppDelegate.shared?.playbackController else {
            return self
        }
        AppleScriptSupport.onMainThread {
            playback.volume = AppleScriptSupport.savedVolume
            print("Changed volume to: \(playback.volume)")
        }
        return self
    }
}

/// Tired command - Mark current song as "tired of this song"
@MainActor
@objc(TiredCommand)
class TiredCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let playback = MinimalAppDelegate.shared?.playbackController else {
            return self
        }
        AppleScriptSupport.onMainThread {
            playback.tiredOfCurrent()
        }
        return self
    }
}

/// Select station command - Switch playback to a station from the station list.
@MainActor
@objc(SelectStationCommand)
class SelectStationCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let station = directParameter as? Station,
              let playback = MinimalAppDelegate.shared?.playbackController else {
            return NSNumber(value: false)
        }

        return AppleScriptSupport.onMainThread {
            NSNumber(value: AppleScriptSupport.selectStation(station, playback: playback))
        }
    }
}

/// Reveal main window command - Bring Hermes's primary window to the foreground.
@MainActor
@objc(RevealMainWindowCommand)
class RevealMainWindowCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        AppleScriptSupport.onMainThread {
            NSNumber(value: AppleScriptSupport.revealMainWindow())
        }
    }
}

// MARK: - AppleScript Support Helper

/// Helper class for AppleScript support
@objc class AppleScriptSupport: NSObject {
    /// Saved volume for mute/unmute functionality
    static var savedVolume: Int = 0

    /// Runs a synchronous scripting operation on AppKit's main thread.
    ///
    /// Apple events arrive on the main thread, so dispatching synchronously from
    /// that handler would trap in libdispatch. Calls already on the main thread
    /// execute inline; off-main callers synchronously marshal their read or
    /// command so AppleScript still receives an immediate reply.
    static func onMainThread<T>(_ operation: () -> T) -> T {
        if Thread.isMainThread {
            return operation()
        }

        return DispatchQueue.main.sync(execute: operation)
    }

    /// Switches playback and the SwiftUI station selection to the given station.
    static func selectStation(_ station: Station, playback: PlaybackController) -> Bool {
        MainActor.assumeIsolated {
            playback.playStation(station)
            AppState.shared.stationsViewModel.playingStationId = station.id
            AppState.shared.stationsViewModel.selectedStationId = station.id

            NotificationCenter.default.post(name: .stationsRefreshRequested, object: nil)
        }
        return true
    }

    /// Returns Hermes's primary application window when it has been created.
    static func mainWindow() -> NSWindow? {
        NSApp.windows.first {
            $0.identifier?.rawValue == "main" || $0.title == "Hermes"
        }
    }

    /// Makes Hermes's primary window visible and key without changing preferences.
    static func revealMainWindow() -> Bool {
        MainActor.assumeIsolated {
            MainWindowPresenter.shared.revealMainWindow()
        }
    }
}

// MARK: - History Entry Scripting Model

/// Immutable AppleScript snapshot of an item visible in Hermes's History list.
@objc(HistoryEntry)
final class HistoryEntry: NSObject {
    @objc let title: String
    @objc let artist: String
    @objc let album: String
    @objc let stationID: String
    @objc let rating: Int

    private let index: Int

    init(song: Song, index: Int) {
        title = song.title
        artist = song.artist
        album = song.album
        stationID = song.stationId ?? ""
        rating = song.rating
        self.index = index
        super.init()
    }

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let appDescription = NSScriptClassDescription(for: type(of: NSApp)) else {
            return nil
        }

        return NSIndexSpecifier(
            containerClassDescription: appDescription,
            containerSpecifier: nil,
            key: "historyEntries",
            index: index
        )
    }
}

// MARK: - NSApplication Scripting Extension

/// Extension to NSApplication providing AppleScript properties and methods
extension NSApplication {
    
    // MARK: - Volume
    
    @objc var volume: NSNumber {
        get {
            guard let playback = MinimalAppDelegate.shared?.playbackController else {
                return NSNumber(value: 0)
            }
            return AppleScriptSupport.onMainThread {
                NSNumber(value: playback.volume)
            }
        }
        set {
            guard let playback = MinimalAppDelegate.shared?.playbackController else {
                return
            }
            AppleScriptSupport.onMainThread {
                playback.volume = newValue.intValue
            }
        }
    }
    
    // MARK: - Playback State
    
    @objc var playbackState: Int {
        get {
            guard let playback = MinimalAppDelegate.shared?.playbackController else {
                return PlaybackState.stopped.rawValue
            }
            return AppleScriptSupport.onMainThread {
                guard let playing = playback.playing else {
                    return PlaybackState.stopped.rawValue
                }
                
                if playing.isPaused() {
                    return PlaybackState.paused.rawValue
                }
                
                return PlaybackState.playing.rawValue
            }
        }
        set {
            guard let playback = MinimalAppDelegate.shared?.playbackController else {
                return
            }
            
            AppleScriptSupport.onMainThread {
                switch newValue {
                case PlaybackState.stopped.rawValue, PlaybackState.paused.rawValue:
                    _ = playback.pause()
                case PlaybackState.playing.rawValue:
                    _ = playback.play()
                default:
                    print("Invalid playback state: \(newValue)")
                }
            }
        }
    }
    
    // MARK: - Playback Position & Duration
    
    @objc var playbackPosition: NSNumber {
        guard let playback = MinimalAppDelegate.shared?.playbackController else {
            return NSNumber(value: 0.0)
        }
        
        return AppleScriptSupport.onMainThread {
            guard let playing = playback.playing else {
                return NSNumber(value: 0.0)
            }
            
            let progress = playing.progress() ?? 0.0
            return NSNumber(value: progress)
        }
    }
    
    @objc var currentSongDuration: NSNumber {
        guard let playback = MinimalAppDelegate.shared?.playbackController else {
            return NSNumber(value: 0.0)
        }
        
        return AppleScriptSupport.onMainThread {
            guard let playing = playback.playing else {
                return NSNumber(value: 0.0)
            }
            
            let duration = playing.duration() ?? 0.0
            return NSNumber(value: duration)
        }
    }
    
    // MARK: - Current Station
    
    @objc var currentStation: Station? {
        get {
            guard let playback = MinimalAppDelegate.shared?.playbackController else {
                return nil
            }
            return AppleScriptSupport.onMainThread {
                playback.playing
            }
        }
        set {
            guard let station = newValue,
                  let playback = MinimalAppDelegate.shared?.playbackController else {
                return
            }
            
            AppleScriptSupport.onMainThread {
                _ = AppleScriptSupport.selectStation(station, playback: playback)
            }
        }
    }
    
    // MARK: - Stations Array
    
    @objc var stations: [Station] {
        AppleScriptSupport.onMainThread {
            guard let delegate = MinimalAppDelegate.shared else {
                return []
            }

            var result = delegate.pandora().stations as? [Station] ?? []
            if let currentStation = delegate.playbackController?.playing,
               !result.contains(where: {
                   $0 === currentStation || $0.stationId == currentStation.stationId
               }) {
                result.insert(currentStation, at: 0)
            }
            return result
        }
    }

    /// Explicit station count for scripts that need a scalar account summary.
    @objc var stationCount: Int {
        stations.count
    }
    
    // MARK: - Current Song
    
    @objc var currentSong: Song? {
        guard let playback = MinimalAppDelegate.shared?.playbackController else {
            return nil
        }
        return AppleScriptSupport.onMainThread {
            guard let playing = playback.playing else {
                return nil
            }
            return playing.playingSong
        }
    }

    // MARK: - History

    /// Immutable snapshots of the entries currently shown in Hermes's History list.
    @objc var historyEntries: [HistoryEntry] {
        AppleScriptSupport.onMainThread {
            MainActor.assumeIsolated {
                AppState.shared.historyViewModel.historyItems.enumerated().map {
                    HistoryEntry(song: $0.element, index: $0.offset)
                }
            }
        }
    }

    /// Explicit count of History entries exposed to AppleScript.
    @objc var historyEntryCount: Int {
        historyEntries.count
    }

    // MARK: - Window State

    /// Whether Hermes is currently running as a regular windowed app or accessory menu-bar app.
    @objc var interfaceMode: Int {
        AppleScriptSupport.onMainThread {
            NSApp.activationPolicy() == .accessory
                ? InterfaceMode.menuBar.rawValue
                : InterfaceMode.windowed.rawValue
        }
    }

    /// Whether Hermes has created its primary application window.
    @objc var mainWindowExists: Bool {
        AppleScriptSupport.onMainThread {
            AppleScriptSupport.mainWindow() != nil
        }
    }
}
