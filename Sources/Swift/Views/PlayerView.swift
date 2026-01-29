//
//  PlayerView.swift
//  Hermes
//
//  Player view with responsive album art and anchored controls
//

import SwiftUI

// MARK: - Player View Model Protocol

@MainActor
protocol PlayerViewModelProtocol: ObservableObject {
    associatedtype ErrorType: Identifiable
    
    var currentSong: SongModel? { get }
    var isPlaying: Bool { get }
    var playbackPosition: TimeInterval { get }
    var duration: TimeInterval { get }
    var volume: Double { get set }
    var isLiked: Bool { get }
    var artworkImage: NSImage? { get }
    var streamError: ErrorType? { get }
    var isRetrying: Bool { get }
    
    func playPause()
    func next()
    func like()
    func dislike()
    func tired()
    func setVolume(_ newVolume: Double)
    func retryPlayback()
    func dismissError()
}

// MARK: - Player View

struct PlayerView<ViewModel: PlayerViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    @State private var isHovering = false
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        ZStack {
            if let song = viewModel.currentSong {
                AlbumArtView(
                    song: song,
                    artworkImage: viewModel.artworkImage,
                    onTap: { openWindow(id: "artworkPreview") }
                )
                .ignoresSafeArea()
                
                errorOverlay
                
                controlsOverlay(for: song)
            } else {
                EmptyPlayerStateView()
            }
        }
        .background(WindowHoverTracker(isHovering: $isHovering))
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var errorOverlay: some View {
        if let error = viewModel.streamError {
            StreamErrorOverlay(
                error: error,
                isRetrying: viewModel.isRetrying,
                onRetry: { viewModel.retryPlayback() },
                onDismiss: { viewModel.dismissError() }
            )
        } else if viewModel.isRetrying {
            RetryingOverlay()
        }
    }
    
    private func controlsOverlay(for song: SongModel) -> some View {
        PlayerControlsOverlay(
            song: song,
            isPlaying: viewModel.isPlaying,
            playbackPosition: viewModel.playbackPosition,
            duration: viewModel.duration,
            volume: $viewModel.volume,
            onPlayPause: { viewModel.playPause() },
            onVolumeChange: { viewModel.setVolume($0) }
        )
        .opacity(shouldShowControls ? 1 : 0)
        .animation(controlsAnimation, value: isHovering)
        .allowsHitTesting(shouldShowControls)
    }
    
    private var shouldShowControls: Bool {
        isHovering && viewModel.streamError == nil
    }
    
    private var controlsAnimation: Animation {
        isHovering ? .easeIn(duration: 0.2) : .easeOut(duration: 2)
    }
}

// MARK: - Player Controls View (for ContentView integration)

struct PlayerControlsView<ViewModel: PlayerViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    var onBackgroundTap: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            if let song = viewModel.currentSong {
                // Background tap catcher
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onBackgroundTap?()
                    }
                
                // Main column layout
                VStack(spacing: 0) {
                    // Upper box: expands, centers play button
                    ZStack {
                        // Play button centered in full area
                        PlayPauseButton(
                            isPlaying: viewModel.isPlaying,
                            action: { viewModel.playPause() }
                        ).padding(.horizontal, 8)

                        // Song info - bottom leading
                        SongInfoView(song: song)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 8)
                            .allowsHitTesting(false)
                    }
                    .frame(maxHeight: .infinity)
                    
                    // Progress bar at bottom
                    ProgressBarView(
                        currentTime: viewModel.playbackPosition,
                        totalTime: viewModel.duration
                    )
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                    .glassEffect()
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                    .allowsHitTesting(false)
                }
                
                // Volume slider - top right corner
                VolumeControl(
                    volume: $viewModel.volume,
                    onVolumeChange: { viewModel.setVolume($0) }
                )
                .padding(4)
                .glassEffect(.regular.interactive())
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            } else {
                EmptyPlayerStateView()
            }
        }
    }
}

// MARK: - Controls Overlay (shared layout)

private struct PlayerControlsOverlay: View {
    let song: SongModel
    let isPlaying: Bool
    let playbackPosition: TimeInterval
    let duration: TimeInterval
    @Binding var volume: Double
    let onPlayPause: () -> Void
    let onVolumeChange: (Double) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Main area - play button centered, song info bottom-left
            ZStack {
                PlayPauseButton(isPlaying: isPlaying, action: onPlayPause)
                
                SongInfoView(song: song)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 12)
                    .padding(.bottom, 8)
                
                VolumeControl(volume: $volume, onVolumeChange: onVolumeChange)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .frame(maxHeight: .infinity)
            
            // Progress bar anchored to bottom
            ProgressBarView(currentTime: playbackPosition, totalTime: duration)
        }
    }
}

// MARK: - Album Art

struct AlbumArtView: View {
    let song: SongModel
    let artworkImage: NSImage?
    let onTap: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image = artworkImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    AsyncImage(url: song.artworkURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .empty, .failure:
                            PlaceholderArtwork()
                        @unknown default:
                            PlaceholderArtwork()
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .help("Click to view album art")
        }
    }
}

struct PlaceholderArtwork: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                MeshGradient(
                    width: 2,
                    height: 2,
                    points: [[0, 0], [0, 1], [1, 0], [1, 1]],
                    colors: [.purple.opacity(0.4), .indigo.opacity(0.3), .blue.opacity(0.3), .cyan.opacity(0.5)]
                )
                
                Image(systemName: "music.note")
                    .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.25))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 4)
            }
        }
    }
}

// MARK: - Playback Controls

struct PlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void
    
    private let size: CGFloat = 96
    private let iconSize: CGFloat = 54
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.clear)
                
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundColor(.primary)
                    .offset(x: isPlaying ? 0 : 4)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .help(isPlaying ? "Pause" : "Play")
    }
}

struct ProgressBarView: View {
    let currentTime: TimeInterval
    let totalTime: TimeInterval
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(formatTime(currentTime))
                Spacer()
                Text(formatTime(totalTime))
            }
            .font(.caption2)
            .monospacedDigit()
            .foregroundColor(.primary)
            .contentOnGlass()
            
            ProgressView(value: currentTime, total: max(totalTime, 1))
                .tint(.primary)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VolumeControl: View {
    @Binding var volume: Double
    let onVolumeChange: (Double) -> Void
    
    private let sliderHeight: CGFloat = 80
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "speaker.wave.3.fill")
            
            Slider(value: $volume, in: 0...1)
                .rotationEffect(.degrees(-90))
                .frame(width: sliderHeight, height: sliderHeight)
                .frame(width: 32, height: sliderHeight)
                .clipped()
                .onChange(of: volume) { _, newValue in
                    onVolumeChange(newValue)
                }
            
            Image(systemName: "speaker.fill")
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .padding(.vertical, 8)
    }
}

// MARK: - Song Info

struct SongInfoView: View {
    let song: SongModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(song.title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(song.artist)
                .font(.subheadline)
                .opacity(0.9)
            
            Text(song.album)
                .font(.caption)
                .opacity(0.8)
        }
        .lineLimit(1)
        .foregroundColor(.primary)
        .contentOnGlass()
    }
}

// MARK: - Empty State

struct EmptyPlayerStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Song Playing")
                .font(.title2)
            
            Text("Select a station to start listening")
                .font(.body)
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error Overlays

struct StreamErrorOverlay<E: Identifiable>: View {
    let error: E
    let isRetrying: Bool
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
            
            VStack(spacing: 20) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Connection Lost")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Unable to stream audio. Check your network connection.")
                    .font(.body)
                    .opacity(0.8)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    Button("Dismiss", action: onDismiss)
                        .buttonStyle(.bordered)
                    
                    Button(action: onRetry) {
                        HStack {
                            if isRetrying {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                            }
                            Text(isRetrying ? "Retrying..." : "Retry")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRetrying)
                }
            }
            .foregroundColor(.primary)
            .padding(32)
        }
        .transition(.opacity)
    }
}

struct RetryingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.primary)
                
                Text("Reconnecting...")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Window Hover Tracking

struct WindowHoverTracker: NSViewRepresentable {
    @Binding var isHovering: Bool
    
    func makeNSView(context: Context) -> WindowHoverView {
        let view = WindowHoverView()
        view.onHoverChanged = { [weak view] hovering in
            DispatchQueue.main.async {
                isHovering = hovering
                if let window = view?.window, isMainHermesWindow(window) {
                    setWindowControlsHidden(!hovering, for: window)
                }
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: WindowHoverView, context: Context) {
        if let window = nsView.window, isMainHermesWindow(window) {
            setWindowControlsHidden(!isHovering, for: window)
        }
    }
    
    private func isMainHermesWindow(_ window: NSWindow) -> Bool {
        window.identifier?.rawValue == "main" ||
        (window.title == "Hermes" && !window.title.isEmpty)
    }
    
    private func setWindowControlsHidden(_ hidden: Bool, for window: NSWindow) {
        let duration = hidden ? 2.0 : 0.2
        
        if let titlebarContainer = window.standardWindowButton(.closeButton)?.superview?.superview {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                titlebarContainer.animator().alphaValue = hidden ? 0 : 1
            }
        }
    }
}

class WindowHoverView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupWindowTracking()
    }
    
    private func setupWindowTracking() {
        guard let window = window, let contentView = window.contentView else { return }
        
        if let existing = trackingArea {
            contentView.removeTrackingArea(existing)
        }
        
        trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        
        if let area = trackingArea {
            contentView.addTrackingArea(area)
        }
        
        let mouseLocation = window.mouseLocationOutsideOfEventStream
        let isInWindow = contentView.bounds.contains(contentView.convert(mouseLocation, from: nil))
        onHoverChanged?(isInWindow)
    }
    
    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }
    
    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }
    
    deinit {
        if let area = trackingArea, let contentView = window?.contentView {
            contentView.removeTrackingArea(area)
        }
    }
}

// MARK: - Window Size Reader

struct WindowSizeReader: NSViewRepresentable {
    let onWidthChange: (CGFloat) -> Void
    
    func makeNSView(context: Context) -> WindowSizeView {
        let view = WindowSizeView()
        view.onWidthChange = onWidthChange
        return view
    }
    
    func updateNSView(_ nsView: WindowSizeView, context: Context) {
        nsView.onWidthChange = onWidthChange
    }
}

class WindowSizeView: NSView {
    var onWidthChange: ((CGFloat) -> Void)?
    private var windowObserver: NSObjectProtocol?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        windowObserver = nil
        
        guard let window = window else { return }
        
        // Report initial size
        onWidthChange?(window.frame.width)
        
        // Observe window resize
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            self?.onWidthChange?(window.frame.width)
        }
    }
    
    deinit {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Previews

#Preview("Player - Playing") {
    PlayerView(viewModel: PreviewPlayerViewModel(
        song: .mock(title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera", rating: 1),
        isPlaying: true,
        playbackPosition: 125.5,
        duration: 245.0
    ))
    .frame(width: 600, height: 400)
}

#Preview("Player - Empty") {
    PlayerView(viewModel: PreviewPlayerViewModel(song: nil))
        .frame(width: 600, height: 400)
}

#Preview("Player - Error") {
    PlayerView(viewModel: PreviewPlayerViewModel(
        song: .mock(title: "Test Song", artist: "Test Artist", album: "Test Album"),
        isPlaying: false,
        streamError: PreviewPlayerViewModel.PreviewError(message: "Connection lost"),
        isRetrying: false
    ))
    .frame(width: 600, height: 400)
}
