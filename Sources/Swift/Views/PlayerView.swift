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

struct PlayerView<ViewModel: PlayerViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    @State private var isHovering = false
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        ZStack {
            if let song = viewModel.currentSong {
                // Album art background
                GeometryReader { geometry in
                    AlbumArtView(
                        song: song,
                        artworkImage: viewModel.artworkImage,
                        availableSize: geometry.size,
                        onTap: { 
                            print("PlayerView: Album art tapped, opening window")
                            openWindow(id: "artworkPreview")
                        }
                    )
                }
                
                // Stream error overlay
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
                
                // Overlay controls
                ZStack {
                    // Main column layout
                    VStack(spacing: 0) {
                        // Upper box: expands, centers play button
                        // Song info is overlaid (absolutely positioned) at bottom-left
                        ZStack(alignment: .bottomLeading) {
                            // Play button centered in full area
                            CenteredPlayPauseButton(
                                isPlaying: viewModel.isPlaying,
                                onTap: { viewModel.playPause() }
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
                            // Song info - absolutely positioned, doesn't affect centering
                            CompactSongInfoView(song: song)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)
                        }
                        .frame(maxHeight: .infinity)
                        
                        // Progress bar at bottom
                        ProgressBarView(
                            currentTime: viewModel.playbackPosition,
                            totalTime: viewModel.duration
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)
                        .padding(.top,8)
                        .glassEffect()
                    }
                    
                    // Volume slider - top right corner, absolutely positioned
                    VStack {
                        HStack {
                            Spacer()
                            VerticalVolumeControl(
                                volume: $viewModel.volume,
                                onVolumeChange: { viewModel.setVolume($0) }
                            )
                            .padding(4)
                            .glassEffect(.regular.interactive())
                            .padding(8)
                        }
                        Spacer()
                    }
                }
                .compositingGroup()
                .opacity(isHovering && viewModel.streamError == nil ? 1 : 0)
                .animation(
                    isHovering 
                        ? .easeIn(duration: 0.2)
                        : .easeOut(duration: 2),
                    value: isHovering
                )
                .allowsHitTesting(isHovering && viewModel.streamError == nil)
            } else {
                EmptyPlayerStateView()
            }
        }
        .background(WindowHoverTracker(isHovering: $isHovering))
    }
}

// MARK: - Window Hover Tracker

struct WindowHoverTracker: NSViewRepresentable {
    @Binding var isHovering: Bool
    
    func makeNSView(context: Context) -> WindowHoverView {
        let view = WindowHoverView()
        view.onHoverChanged = { hovering in
            DispatchQueue.main.async {
                isHovering = hovering
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: WindowHoverView, context: Context) {}
}

class WindowHoverView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    private var windowObserver: NSObjectProtocol?
    private var trackingArea: NSTrackingArea?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupWindowTracking()
    }
    
    private func setupWindowTracking() {
        guard let window = window, let contentView = window.contentView else { return }
        
        // Remove any existing tracking area
        if let existing = trackingArea {
            contentView.removeTrackingArea(existing)
        }
        
        // Create tracking area on the window's content view
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect
        ]
        
        trackingArea = NSTrackingArea(
            rect: .zero, // inVisibleRect handles the rect
            options: options,
            owner: self,
            userInfo: nil
        )
        
        if let area = trackingArea {
            contentView.addTrackingArea(area)
        }
        
        // Check initial mouse position
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
        // Clean up tracking area from window's content view
        if let area = trackingArea, let contentView = window?.contentView {
            contentView.removeTrackingArea(area)
        }
    }
}

// MARK: - Album Art View

struct AlbumArtView: View {
    let song: SongModel
    let artworkImage: NSImage?
    let availableSize: CGSize
    let onTap: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            artworkContent
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }
                .help("Click to view album art")
        }
    }
    
    @ViewBuilder
    private var artworkContent: some View {
        if let image = artworkImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            AsyncImage(url: song.artworkURL) { phase in
                switch phase {
                case .empty:
                    PlaceholderArtworkContent()
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    PlaceholderArtworkContent()
                @unknown default:
                    PlaceholderArtworkContent()
                }
            }
        }
    }
}

// MARK: - Placeholder Artwork View

// MARK: - Placeholder Artwork Content

struct PlaceholderArtworkContent: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Vibrant multi-dimensional gradient background
                MeshGradient(
                    width: 2,
                    height: 2,
                    points: [
                        [0.0, 0.0], [0.0, 1.0], [1.0, 0.0], [1.0, 1.0]
                    ],
                    colors: [
                        .purple, .indigo, .blue, .cyan,
                    ]
                )
                
                Image(systemName: "music.note")
                    .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.25))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
    }
}

// MARK: - Placeholder Artwork View (Standalone)

struct PlaceholderArtworkView: View {
    let size: CGFloat?
    
    init(size: CGFloat? = nil) {
        self.size = size
    }
    
    var body: some View {
        PlaceholderArtworkContent()
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(12)
            .if(size != nil) { view in
                view.frame(width: size, height: size)
            }
    }
}

// MARK: - Conditional View Modifier Helper

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Centered Play/Pause Button

struct CenteredPlayPauseButton: View {
    let isPlaying: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 54, weight: .medium))
                .foregroundColor(.white)
                // Offset play icon slightly right to appear visually centered
                .offset(x: isPlaying ? 0 : 4)
                .frame(width: 96, height: 96)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .help(isPlaying ? "Pause" : "Play")
    }
}

// MARK: - Compact Song Info View (Bottom Left)

struct CompactSongInfoView: View {
    let song: SongModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(song.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .foregroundColor(.white)
            
            Text(song.artist)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
            
            Text(song.album)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
        }
        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Song Info View

struct SongInfoView: View {
    let song: SongModel
    
    var body: some View {
        VStack(spacing: 8) {
            Text(song.title)
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            Text(song.artist)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
            
            Text(song.album)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
            
            // Track gain indicator (for power users/debugging)
            if let gainString = song.trackGain,
               let gainValue = Double(gainString) {
                HStack(spacing: 4) {
                    Image(systemName: gainValue > 0 ? "speaker.wave.3" : "speaker.wave.1")
                        .font(.caption2)
                    Text(String(format: "%+.1f dB", gainValue))
                        .font(.caption2)
                        .monospacedDigit()
                }
                .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Playback Buttons View

struct PlaybackButtonsView<ViewModel: PlayerViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        HStack(spacing: 20) {
            // Like button - reactive to current song rating
            Button(action: { viewModel.like() }) {
                Image(systemName: viewModel.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.title2)
                    .foregroundColor(viewModel.isLiked ? .green : .white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!(viewModel.currentSong?.allowFeedback ?? true))
            .opacity((viewModel.currentSong?.allowFeedback ?? true) ? 1.0 : 0.5)
            .help(viewModel.isLiked ? "Unlike" : "Like")
            
            Spacer()
            
            // Play/Pause button (larger, centered)
            Button(action: { viewModel.playPause() }) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.plain)
            .help(viewModel.isPlaying ? "Pause" : "Play")
            
            // Next button
            Button(action: { viewModel.next() }) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .help("Next")
            
            Spacer()
            
            // More actions menu
            Menu {
                Button(action: { viewModel.dislike() }) {
                    Label("Dislike", systemImage: "hand.thumbsdown")
                }
                .disabled(!(viewModel.currentSong?.allowFeedback ?? true))
                
                Button(action: { viewModel.tired() }) {
                    Label("Tired of this song", systemImage: "moon.zzz")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            .menuStyle(.borderlessButton)
            .help("More actions")
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Empty Player State View

struct ProgressBarView: View {
    let currentTime: TimeInterval
    let totalTime: TimeInterval
    
    var body: some View {
        VStack(spacing: 0) {
            // Times above the bar
            HStack {
                Text(formatTime(currentTime))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                Spacer()
                Text(formatTime(totalTime))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }
            
            // Progress bar
            ProgressView(value: currentTime, total: max(totalTime, 1))
                .tint(.white)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Vertical Volume Control

struct VerticalVolumeControl: View {
    @Binding var volume: Double
    let onVolumeChange: (Double) -> Void
    
    private let sliderLength: CGFloat = 80
    private let containerWidth: CGFloat = 32
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            
            // Slider rotated, then clipped to narrow width
            Slider(value: $volume, in: 0...1)
                .rotationEffect(.degrees(-90))
                .frame(width: sliderLength, height: sliderLength)
                .frame(width: containerWidth, height: sliderLength)
                .clipped()
                .onChange(of: volume) { oldValue, newValue in
                    onVolumeChange(newValue)
                }
            
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Empty Player State View

struct EmptyPlayerStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Song Playing")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Select a station to start listening")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stream Error Overlay

struct StreamErrorOverlay<E: Identifiable>: View {
    let error: E
    let isRetrying: Bool
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
            
            VStack(spacing: 20) {
                // Error icon
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                // Error message
                Text("Connection Lost")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Unable to stream audio. Check your network connection.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                // Action buttons
                HStack(spacing: 16) {
                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .frame(minWidth: 80)
                    }
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
                        .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRetrying)
                }
                .padding(.top, 8)
            }
            .padding(32)
        }
        .transition(.opacity)
    }
}

// MARK: - Retrying Overlay

struct RetryingOverlay: View {
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Reconnecting...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
        }
        .transition(.opacity)
    }
}

// MARK: - Previews

#Preview("Player View - Playing") {
    PlayerView(viewModel: PreviewPlayerViewModel(
        song: .mock(
            title: "Bohemian Rhapsody",
            artist: "Queen",
            album: "A Night at the Opera",
            rating: 1
        ),
        isPlaying: true,
        playbackPosition: 125.5,
        duration: 245.0
    ))
    .frame(width: 600, height: 400)
}

#Preview("Player View - Paused") {
    PlayerView(viewModel: PreviewPlayerViewModel(
        song: .mock(
            title: "Stairway to Heaven",
            artist: "Led Zeppelin",
            album: "Led Zeppelin IV"
        ),
        isPlaying: false,
        playbackPosition: 45.0,
        duration: 482.0
    ))
    .frame(width: 600, height: 400)
}

#Preview("Player View - Long Title") {
    PlayerView(viewModel: PreviewPlayerViewModel(
        song: .mock(
            title: "The Battle of Evermore: A Very Long Song Title That Should Wrap to Multiple Lines",
            artist: "Led Zeppelin",
            album: "Led Zeppelin IV (Deluxe Remaster Edition)"
        ),
        isPlaying: true
    ))
    .frame(width: 600, height: 400)
}

#Preview("Player View - Empty") {
    PlayerView(viewModel: PreviewPlayerViewModel(song: nil))
        .frame(width: 600, height: 400)
}

#Preview("Player View - Stream Error") {
    PlayerView(viewModel: PreviewPlayerViewModel(
        song: .mock(
            title: "The Fabric of Time",
            artist: "Audiomachine",
            album: "Phenomena"
        ),
        isPlaying: false,
        streamError: PreviewPlayerViewModel.PreviewError(message: "Connection reset by peer"),
        isRetrying: false
    ))
    .frame(width: 600, height: 400)
}

#Preview("Player View - Retrying") {
    PlayerView(viewModel: PreviewPlayerViewModel(
        song: .mock(
            title: "The Fabric of Time",
            artist: "Audiomachine",
            album: "Phenomena"
        ),
        isPlaying: false,
        isRetrying: true
    ))
    .frame(width: 600, height: 400)
}

// MARK: - Component Previews

#Preview("Album Art - Loaded") {
    AlbumArtView(
        song: .mock(
            title: "Bohemian Rhapsody",
            artist: "Queen",
            album: "A Night at the Opera",
            rating: 1
        ),
        artworkImage: nil,
        availableSize: CGSize(width: 600, height: 400),
        onTap: { print("Tapped") }
    )
    .frame(width: 600, height: 400)
}

#Preview("Album Art - Placeholder") {
    PlaceholderArtworkView(size: 200)
        .frame(width: 300, height: 300)
}

#Preview("Song Info - Long Title") {
    SongInfoView(
        song: .mock(
            title: "Bohemian Rhapsody: A Very Long Song Title That Should Wrap",
            artist: "Queen",
            album: "A Night at the Opera",
            rating: 1
        )
    )
    .frame(width: 400)
    .padding()
}

#Preview("Song Info - Short Title") {
    SongInfoView(
        song: .mock(
            title: "Yesterday",
            artist: "The Beatles",
            album: "Help!",
            rating: 0
        )
    )
    .frame(width: 400)
    .padding()
}

#Preview("Progress Bar - Mid Song") {
    ProgressBarView(
        currentTime: 125.5,
        totalTime: 245.0
    )
    .padding()
    .frame(width: 400)
    .background(.black)
}

#Preview("Progress Bar - Starting") {
    ProgressBarView(
        currentTime: 5.0,
        totalTime: 180.0
    )
    .padding()
    .frame(width: 400)
    .background(.black)
}

#Preview("Vertical Volume Control") {
    VerticalVolumeControl(
        volume: .constant(0.5),
        onVolumeChange: { _ in }
    )
    .padding()
    .frame(width: 100, height: 200)
    .background(.gray)
}

#Preview("Empty State") {
    EmptyPlayerStateView()
        .frame(width: 600, height: 400)
}
