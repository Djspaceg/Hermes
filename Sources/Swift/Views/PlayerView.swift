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
    var currentSong: SongModel? { get }
    var isPlaying: Bool { get }
    var playbackPosition: TimeInterval { get }
    var duration: TimeInterval { get }
    var volume: Double { get set }
    var isLiked: Bool { get }
    var artworkImage: NSImage? { get }
    
    func playPause()
    func next()
    func like()
    func dislike()
    func tired()
    func setVolume(_ newVolume: Double)
}

struct PlayerView<ViewModel: PlayerViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    @State private var isHovering = false
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if let song = viewModel.currentSong {
                // Album art - extends to bottom of player area
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
                
                // Overlay controls - fade in/out based on hover
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Song info
                    SongInfoView(song: song)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    
                    // Bottom controls (progress and volume)
                    PlaybackControlsView(
                        playbackPosition: viewModel.playbackPosition,
                        duration: viewModel.duration,
                        volume: $viewModel.volume,
                        onVolumeChange: { viewModel.setVolume($0) }
                    )
                    .background(.ultraThinMaterial)
                }
                .compositingGroup() // Render as single layer before applying opacity
                .opacity(isHovering ? 1 : 0)
                .animation(
                    isHovering 
                        ? .easeIn(duration: 0.2)  // Slightly slower fade in to let material render
                        : .easeOut(duration: 2), // Slow fade out
                    value: isHovering
                )
                .allowsHitTesting(isHovering) // Only allow interaction when visible
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
            Group {
                if let image = artworkImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    AsyncImage(url: song.artworkURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            PlaceholderArtworkView()
                        @unknown default:
                            PlaceholderArtworkView()
                        }
                    }
                }
            }
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
}

// MARK: - Placeholder Artwork View

struct PlaceholderArtworkView: View {
    let size: CGFloat?
    
    init(size: CGFloat? = nil) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.3)
            Image(systemName: "music.note")
                .font(.system(size: (size ?? 200) * 0.3))
                .foregroundColor(.gray)
        }
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

// MARK: - Playback Controls View

struct PlaybackControlsView: View {
    let playbackPosition: TimeInterval
    let duration: TimeInterval
    @Binding var volume: Double
    let onVolumeChange: (Double) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            ProgressBarView(
                currentTime: playbackPosition,
                totalTime: duration
            )
            
            // Volume control
            VolumeControlView(
                volume: $volume,
                onVolumeChange: onVolumeChange
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

// MARK: - Progress Bar View

struct ProgressBarView: View {
    let currentTime: TimeInterval
    let totalTime: TimeInterval
    
    var body: some View {
        VStack(spacing: 4) {
            ProgressView(value: currentTime, total: max(totalTime, 1))
                .tint(.accentColor)

            HStack {
                Text(formatTime(currentTime))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                Spacer()
                Text(formatTime(totalTime))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Volume Control View

struct VolumeControlView: View {
    @Binding var volume: Double
    let onVolumeChange: (Double) -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            Slider(value: $volume, in: 0...1)
                .onChange(of: volume) { oldValue, newValue in
                    onVolumeChange(newValue)
                }
            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundColor(.secondary)
        }
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

#Preview("Playback Controls") {
    PlaybackControlsView(
        playbackPosition: 125.5,
        duration: 245.0,
        volume: .constant(0.7),
        onVolumeChange: { _ in }
    )
    .frame(width: 500)
}

#Preview("Progress Bar - Mid Song") {
    ProgressBarView(
        currentTime: 125.5,
        totalTime: 245.0
    )
    .padding()
    .frame(width: 400)
}

#Preview("Progress Bar - Starting") {
    ProgressBarView(
        currentTime: 5.0,
        totalTime: 180.0
    )
    .padding()
    .frame(width: 400)
}

#Preview("Volume Control") {
    VolumeControlView(
        volume: .constant(0.5),
        onVolumeChange: { _ in }
    )
    .padding()
    .frame(width: 300)
}

#Preview("Empty State") {
    EmptyPlayerStateView()
        .frame(width: 600, height: 400)
}
