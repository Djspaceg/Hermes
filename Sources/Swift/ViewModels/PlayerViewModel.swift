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
    @Published var streamError: StreamError?
    @Published var isRetrying: Bool = false
    
    // MARK: - Stream Error Type
    
    struct StreamError: Identifiable {
        let id = UUID()
        let message: String
        let isNetworkError: Bool
        let timestamp: Date
        
        init(message: String, isNetworkError: Bool = false) {
            self.message = message
            self.isNetworkError = isNetworkError
            self.timestamp = Date()
        }
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var retryCount = 0
    private let maxAutoRetries = 2
    private var periodicRetryTask: Task<Void, Never>?
    
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
        
        // New song started - deduplicate rapid notifications
        center.publisher(for: Notification.Name("StationDidPlaySongNotification"))
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCurrentSong()
            }
            .store(in: &cancellables)
        
        // Song rating changed - update like state
        center.publisher(for: Notification.Name("PandoraDidRateSongNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleSongRatingChanged(notification)
            }
            .store(in: &cancellables)
        
        // Playback state changed (play/pause/stop) - deduplicate rapid changes
        center.publisher(for: Notification.Name("PlaybackStateDidChangeNotification"))
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
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
        
        // Album art loaded - this is the proper time to update artwork
        center.publisher(for: Notification.Name("PlaybackArtDidLoadNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateArtwork()
            }
            .store(in: &cancellables)
        
        // Stream error - network failure or timeout
        center.publisher(for: Notification.Name("ASStreamError"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleStreamError(notification)
            }
            .store(in: &cancellables)
        
        // New song attempting - clear error state
        center.publisher(for: Notification.Name("ASAttemptingNewSong"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.clearStreamError()
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
            artworkImage = nil
            return
        }
        
        print("PlayerViewModel: Song changed - \(song.title) by \(song.artist)")
        let previousSong = currentSong
        currentSong = SongModel(song: song)
        isLiked = (song.nrating?.intValue ?? 0) == 1
        
        // Don't call updateArtwork() here - it will be called when PlaybackArtDidLoadNotification fires
        // This prevents showing stale artwork from the previous song
        
        // Show notification for new song (artwork will be updated via PlaybackArtDidLoadNotification)
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
            if isPlaying != false {
                isPlaying = false
                print("PlayerViewModel: State updated - isPlaying: false")
            }
            return
        }
        
        let newState = station.isPlaying()
        if isPlaying != newState {
            isPlaying = newState
            print("PlayerViewModel: State updated - isPlaying: \(isPlaying)")
        }
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
    
    private func handleSongRatingChanged(_ notification: Notification) {
        // Update isLiked state when song rating changes
        guard let ratedSong = notification.object as? Song else { return }
        
        // Check if this is the currently playing song
        if let currentSongToken = currentSong?.song.token,
           let ratedSongToken = ratedSong.token,
           currentSongToken == ratedSongToken {
            let newRating = ratedSong.nrating?.intValue ?? 0
            isLiked = (newRating == 1)
            print("PlayerViewModel: Rating changed for current song - isLiked: \(isLiked)")
            
            // Update the current song model's rating too
            currentSong?.song.nrating = ratedSong.nrating
        }
    }
    
    private func updateArtwork() {
        let previousArtwork = artworkImage
        artworkImage = playbackController?.artImage
        
        // If artwork just loaded and we have a current song, update the notification with artwork
        if previousArtwork == nil && artworkImage != nil, 
           let song = playbackController?.playing?.playingSong {
            NotificationManager.shared.showSongNotification(
                song: song,
                image: artworkImage,
                isNewSong: false // Don't play sound again, just update the notification
            )
        }
    }
    
    // MARK: - Error Handling
    
    private func handleStreamError(_ notification: Notification) {
        // Get error details from the station
        let errorMessage: String
        if let station = playbackController?.playing {
            errorMessage = station.streamNetworkError() ?? "Connection failed"
        } else {
            errorMessage = "Stream connection failed"
        }
        
        print("PlayerViewModel: Stream error - \(errorMessage)")
        
        // Check if we should auto-retry
        if retryCount < maxAutoRetries {
            retryCount += 1
            isRetrying = true
            print("PlayerViewModel: Auto-retrying (\(retryCount)/\(maxAutoRetries))...")
            
            // Delay retry slightly to allow network to recover
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    self.isRetrying = false
                    self.retryPlayback()
                }
            }
        } else {
            // Show error to user after max retries
            streamError = StreamError(
                message: errorMessage,
                isNetworkError: true
            )
            isRetrying = false
            
            // Start periodic retry in background
            startPeriodicRetry()
        }
    }
    
    private func startPeriodicRetry() {
        // Cancel any existing periodic retry
        periodicRetryTask?.cancel()
        
        periodicRetryTask = Task {
            while !Task.isCancelled {
                // Wait 60 seconds before retrying
                try? await Task.sleep(for: .seconds(60))
                
                guard !Task.isCancelled else { break }
                
                await MainActor.run {
                    // Only retry if we're still in error state
                    if self.streamError != nil {
                        print("PlayerViewModel: Periodic retry attempt...")
                        self.isRetrying = true
                        self.retryPlayback()
                    }
                }
            }
        }
    }
    
    private func stopPeriodicRetry() {
        periodicRetryTask?.cancel()
        periodicRetryTask = nil
    }
    
    private func clearStreamError() {
        streamError = nil
        retryCount = 0
        isRetrying = false
        stopPeriodicRetry()
    }
    
    func retryPlayback() {
        print("PlayerViewModel: Retrying playback...")
        streamError = nil
        stopPeriodicRetry()
        
        // Call retry on the station's playlist
        if let station = playbackController?.playing {
            station.retry()
        }
    }
    
    func dismissError() {
        streamError = nil
        retryCount = 0
        stopPeriodicRetry()
    }
    
    // MARK: - Playback Controls
    
    func playPause() {
        print("PlayerViewModel: playPause called")
        
        // If we're in an error state, retry instead of normal play/pause
        if let station = playbackController?.playing, station.isError() {
            print("PlayerViewModel: Stream in error state, retrying...")
            clearStreamError()
            station.retry()
            return
        }
        
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
        artworkImage: NSImage? = nil,
        streamError: StreamError? = nil,
        isRetrying: Bool = false
    ) -> PlayerViewModel {
        let viewModel = PlayerViewModel()
        viewModel.currentSong = song
        viewModel.isPlaying = isPlaying
        viewModel.playbackPosition = playbackPosition
        viewModel.duration = duration
        viewModel.volume = volume
        viewModel.isLiked = isLiked
        viewModel.artworkImage = artworkImage
        viewModel.streamError = streamError
        viewModel.isRetrying = isRetrying
        return viewModel
    }
}

// MARK: - Preview-Only Mock

/// A completely isolated mock for previews that doesn't connect to any live data
@MainActor
final class PreviewPlayerViewModel: ObservableObject, PlayerViewModelProtocol {
    struct PreviewError: Identifiable {
        let id = UUID()
        let message: String
    }
    
    @Published var currentSong: SongModel?
    @Published var isPlaying: Bool = false
    @Published var playbackPosition: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Double = 1.0
    @Published var isLiked: Bool = false
    @Published var artworkImage: NSImage?
    @Published var streamError: PreviewError?
    @Published var isRetrying: Bool = false
    
    init(
        song: SongModel? = .mock(),
        isPlaying: Bool = true,
        playbackPosition: TimeInterval = 125.5,
        duration: TimeInterval = 245.0,
        volume: Double = 0.7,
        isLiked: Bool = false,
        artworkImage: NSImage? = nil,
        streamError: PreviewError? = nil,
        isRetrying: Bool = false
    ) {
        self.currentSong = song
        self.isPlaying = isPlaying
        self.playbackPosition = playbackPosition
        self.duration = duration
        self.volume = volume
        self.isLiked = isLiked
        self.artworkImage = artworkImage
        self.streamError = streamError
        self.isRetrying = isRetrying
    }
    
    // No-op methods for preview compatibility
    func playPause() {}
    func next() {}
    func like() {}
    func dislike() {}
    func tired() {}
    func setVolume(_ newVolume: Double) { volume = newVolume }
    func retryPlayback() { isRetrying = true }
    func dismissError() { streamError = nil }
}
