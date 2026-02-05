//
//  AlbumArtPreviewView.swift
//  Hermes
//
//  Full-screen album art preview with song details
//

import SwiftUI

struct AlbumArtPreviewView: View {
    
    // MARK: - Properties
    
    // Song is optional - we can't use @Bindable with optionals
    // The parent view should handle observation of the Song
    let song: Song?
    let artworkImage: NSImage?
    @Binding var isPresented: Bool
    
    @State private var showingDetails = false

    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Album art
            artworkView
            
            // Song details overlay
            if showingDetails, let song = song {
                detailsOverlay(for: song)
            }
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(.ultraThinMaterial)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingDetails.toggle()
            }
        }
        .onExitCommand {
            isPresented = false
        }
    }
    
    // MARK: - Subviews
    
    private var artworkView: some View {
        Group {
            if let image = artworkImage {
                Image(nsImage: image)
                    .resizable()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                    .padding(8)
            } else {
                placeholderArtwork
            }
        }
    }
    
    private var placeholderArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
            
            Image(systemName: "music.note")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(8)
    }
    
    private func detailsOverlay(for song: Song) -> some View {
        // Use SongDetailsOverlay to properly observe the song's rating changes
        SongDetailsOverlay(song: song)
    }
}

// MARK: - Song Details Overlay

/// Separate view to properly observe @Observable Song changes
private struct SongDetailsOverlay: View {
    @Bindable var song: Song
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 8) {
                HStack {
                    if song.rating == 1 {
                        Image(systemName: "hand.thumbsup.fill")
                            .foregroundColor(.green)
                    } else if song.rating == -1 {
                        Image(systemName: "hand.thumbsdown.fill")
                            .foregroundColor(.red)
                    }
                    
                    Text(song.title)
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                Text(song.artist)
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.9))
                
                Text(song.album)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 0)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .foregroundColor(.white)
        .transition(.opacity)
    }
}

// MARK: - Preview Window

struct AlbumArtPreviewWindow: View {
    // Use @Bindable to properly observe @Observable PlayerViewModel changes
    @Bindable var playerViewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if let song = playerViewModel.currentSong {
                AlbumArtPreviewView(
                    song: song,
                    artworkImage: playerViewModel.artworkImage,
                    isPresented: .constant(true)
                )
                .frame(minWidth: 600, minHeight: 600)
                .ignoresSafeArea()
                .onAppear {
                    configureWindowForFullscreen()
                }
            } else {
                // No song - close the window
                Color.clear
                    .frame(width: 0, height: 0)
                    .onAppear {
                        dismiss()
                    }
            }
        }
    }
    
    private func configureWindowForFullscreen() {
        // Use DispatchQueue to ensure window is fully initialized
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: { 
                $0.title == "Album Art" || $0.identifier?.rawValue == WindowID.artworkPreview
            }) else { return }
            
            // Enable fullscreen support - .managed is required for SwiftUI windows
            window.collectionBehavior = [.fullScreenPrimary, .managed]
            
            // Hide title but keep traffic lights visible
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            
            // Make content extend under titlebar
            window.styleMask.insert(.fullSizeContentView)
        }
    }
}

// MARK: - Preview

#Preview("Album Art Preview") {
    AlbumArtPreviewView(
        song: .mock(title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera"),
        artworkImage: nil,
        isPresented: .constant(true)
    )
}
