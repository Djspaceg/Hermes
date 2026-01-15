//
//  PlayerViewModel.swift
//  Hermes
//
//  Manages playback state and controls
//

import Foundation
import Combine
import AppKit

@MainActor
final class PlayerViewModel: ObservableObject, PlayerViewModelProtocol {
    
    // MARK: - Published Properties
    
    @Published var currentSong: SongModel?
    @Published var isPlaying: Bool = false
    @Published var playbackPosition: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Double = 1.0
    @Published var isLiked: Bool = false
    @Published var artworkImage: NSImage?
    @Published var showingArtworkPreview: Bool = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    private var playbackController: PlaybackController? {
        MinimalAppDelegate.shared?.playbackController
    }
    
    // MARK: - Initialization
    
    init() {
        setupNotificationSubscriptions()
        
        // Request notification authorization on init
        Task {
            await NotificationManager.shared.requestAuthorization()
        }
    }
    
    // MARK: - Setup
    
    private func setupNotificationSubscriptions() {
        // Listen for playback controller ready to load initial volume
        NotificationCenter.default.publisher(for: Notification.Name("PlaybackControllerReady"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadInitialVolume()
            }
            .store(in: &cancellables)
        
        // Also try loading volume when state changes (fallback)
        NotificationCenter.default.publisher(for: Notification.Name("PlaybackStateDidChangeNotification"))
            .first() // Only need to do this once
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadInitialVolumeIfNeeded()
            }
            .store(in: &cancellables)
        
        let center = NotificationCenter.default
        
        // New song started
        center.publisher(for: Notification.Name("StationDidPlaySongNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCurrentSong()
            }
            .store(in: &cancellables)
        
        // Playback state changed (play/pause/stop)
        center.publisher(for: Notification.Name("PlaybackStateDidChangeNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePlaybackState()
            }
            .store(in: &cancellables)
        
        // Progress update
        center.publisher(for: Notification.Name("PlaybackProgressDidChangeNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleProgressUpdate(notification)
            }
            .store(in: &cancellables)
        
        // Album art loaded
        center.publisher(for: Notification.Name("PlaybackArtDidLoadNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateArtwork()
            }
            .store(in: &cancellables)
        
        // Legacy song playing notification (from Station)
        center.songPlayingPublisher
            .sink { [weak self] song in
                print("PlayerViewModel: Received legacy song notification - \(song.title ?? "Unknown")")
                self?.currentSong = SongModel(song: song)
                self?.isLiked = (song.nrating?.intValue ?? 0) == 1
            }
            .store(in: &cancellables)
        
        // Legacy playback state
        center.playbackStatePublisher
            .sink { [weak self] playing in
                print("PlayerViewModel: Legacy playback state - playing: \(playing)")
                self?.isPlaying = playing
            }
            .store(in: &cancellables)
    }
    
    private var volumeLoaded = false
    
    private func loadInitialVolume() {
        guard !volumeLoaded, let controller = playbackController else { return }
        volume = Double(controller.volume) / 100.0
        volumeLoaded = true
        print("PlayerViewModel: Loaded initial volume: \(volume)")
    }
    
    private func loadInitialVolumeIfNeeded() {
        if !volumeLoaded {
            loadInitialVolume()
        }
    }
    
    // MARK: - State Updates
    
    private func updateCurrentSong() {
        guard let controller = playbackController,
              let station = controller.playing,
              let song = station.playingSong else {
            currentSong = nil
            isLiked = false
            return
        }
        
        print("PlayerViewModel: Song changed - \(song.title ?? "Unknown") by \(song.artist ?? "Unknown")")
        let previousSong = currentSong
        currentSong = SongModel(song: song)
        isLiked = (song.nrating?.intValue ?? 0) == 1
        updateArtwork()
        
        // Show notification for new song
        let isNewSong = previousSong?.title != song.title
        NotificationManager.shared.showSongNotification(
            song: song,
            image: artworkImage,
            isNewSong: isNewSong
        )
    }
    
    private func updatePlaybackState() {
        guard let controller = playbackController,
              let station = controller.playing else {
            isPlaying = false
            return
        }
        
        isPlaying = station.isPlaying()
        print("PlayerViewModel: State updated - isPlaying: \(isPlaying)")
    }
    
    private func handleProgressUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let progress = userInfo["progress"] as? Double,
              let dur = userInfo["duration"] as? Double else {
            return
        }
        
        playbackPosition = progress
        duration = dur
    }
    
    private func updateArtwork() {
        artworkImage = playbackController?.artImage
    }
    
    // MARK: - Playback Controls
    
    func playPause() {
        print("PlayerViewModel: playPause called")
        playbackController?.playpause()
    }
    
    func next() {
        print("PlayerViewModel: next called")
        playbackController?.next()
    }
    
    func like() {
        print("PlayerViewModel: like called")
        playbackController?.likeCurrent()
        isLiked = true
    }
    
    func dislike() {
        print("PlayerViewModel: dislike called")
        playbackController?.dislikeCurrent()
    }
    
    func tired() {
        print("PlayerViewModel: tired called")
        playbackController?.tiredOfCurrent()
    }
    
    func setVolume(_ newVolume: Double) {
        volume = newVolume
        playbackController?.volume = Int(newVolume * 100)
    }
    
    // MARK: - Album Art Preview
    
    func toggleArtworkPreview() {
        showingArtworkPreview.toggle()
    }
}

// MARK: - Preview Helpers

extension PlayerViewModel {
    /// Creates a mock PlayerViewModel for SwiftUI previews
    /// This creates a real instance but with mock data - still subscribes to notifications
    static func mock(
        song: SongModel? = .mock(),
        isPlaying: Bool = true,
        playbackPosition: TimeInterval = 125.5,
        duration: TimeInterval = 245.0,
        volume: Double = 0.7,
        isLiked: Bool = false,
        artworkImage: NSImage? = nil
    ) -> PlayerViewModel {
        let viewModel = PlayerViewModel()
        viewModel.currentSong = song
        viewModel.isPlaying = isPlaying
        viewModel.playbackPosition = playbackPosition
        viewModel.duration = duration
        viewModel.volume = volume
        viewModel.isLiked = isLiked
        viewModel.artworkImage = artworkImage
        return viewModel
    }
}

// MARK: - Preview-Only Mock

/// A completely isolated mock for previews that doesn't connect to any live data
@MainActor
final class PreviewPlayerViewModel: ObservableObject, PlayerViewModelProtocol {
    @Published var currentSong: SongModel?
    @Published var isPlaying: Bool = false
    @Published var playbackPosition: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Double = 1.0
    @Published var isLiked: Bool = false
    @Published var artworkImage: NSImage?
    @Published var showingArtworkPreview: Bool = false
    
    init(
        song: SongModel? = .mock(),
        isPlaying: Bool = true,
        playbackPosition: TimeInterval = 125.5,
        duration: TimeInterval = 245.0,
        volume: Double = 0.7,
        isLiked: Bool = false,
        artworkImage: NSImage? = nil
    ) {
        self.currentSong = song
        self.isPlaying = isPlaying
        self.playbackPosition = playbackPosition
        self.duration = duration
        self.volume = volume
        self.isLiked = isLiked
        self.artworkImage = artworkImage
    }
    
    // No-op methods for preview compatibility
    func playPause() {}
    func next() {}
    func like() {}
    func dislike() {}
    func tired() {}
    func setVolume(_ newVolume: Double) { volume = newVolume }
    func toggleArtworkPreview() { showingArtworkPreview.toggle() }
}
