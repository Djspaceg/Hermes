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
    var showingArtworkPreview: Bool { get set }
    
    func playPause()
    func next()
    func like()
    func dislike()
    func tired()
    func setVolume(_ newVolume: Double)
    func toggleArtworkPreview()
}

struct PlayerView<ViewModel: PlayerViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
      ZStack(alignment: .bottom) {
        if let song = viewModel.currentSong {
          // Album art - fills available space
          GeometryReader { geometry in
            AlbumArtView(
              song: song,
              artworkImage: viewModel.artworkImage,
              availableSize: geometry.size,
              onTap: { viewModel.toggleArtworkPreview() }
            )
          }
        }

        VStack(spacing: 0) {
          if let song = viewModel.currentSong {
            // Song info - anchored above bottom controls
            SongInfoView(song: song)
              .padding(.vertical, 16)
              .frame(maxWidth: .infinity)
              .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

            // Bottom controls - anchored to bottom
            PlaybackControlsView(
              playbackPosition: viewModel.playbackPosition,
              duration: viewModel.duration,
              volume: $viewModel.volume,
              onVolumeChange: { viewModel.setVolume($0) }
            )
          } else {
            EmptyPlayerStateView()
          }
        }}
        .sheet(isPresented: $viewModel.showingArtworkPreview) {
            AlbumArtPreviewView(
                song: viewModel.currentSong,
                artworkImage: viewModel.artworkImage,
                isPresented: $viewModel.showingArtworkPreview
            )
            .frame(minWidth: 500, minHeight: 500)
            .onAppear {
                WindowTracker.shared.windowOpened("artworkPreview")
            }
            .onDisappear {
                WindowTracker.shared.windowClosed("artworkPreview")
            }
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
                        .onTapGesture(count: 1) { onTap() }
                        .help("Click to view album art")
                } else {
                    AsyncImage(url: song.artworkURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .onTapGesture(count: 1) { onTap() }
                                .help("Click to view album art")
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
        }
        .padding(.horizontal, 16)
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
        .background(.ultraThinMaterial)
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
