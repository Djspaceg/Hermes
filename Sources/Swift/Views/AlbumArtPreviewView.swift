//
//  AlbumArtPreviewView.swift
//  Hermes
//
//  Full-screen album art preview with song details
//

import SwiftUI

struct AlbumArtPreviewView: View {
    
    // MARK: - Properties
    
    let song: SongModel?
    let artworkImage: NSImage?
    @Binding var isPresented: Bool
    
    @State private var showingDetails = false

    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            backgroundView
            
            // Album art
            artworkView
            
            // Song details overlay
            if showingDetails {
                detailsOverlay
            }
            
            // Close button
            closeButton
        }
        .frame(minWidth: 400, minHeight: 400)
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
    
    private var backgroundView: some View {
        Group {
            if let image = artworkImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 50)
                    .overlay(Color.black.opacity(0.5))
            } else {
                Color.black
            }
        }
        .ignoresSafeArea()
    }
    
    private var artworkView: some View {
        Group {
            if let image = artworkImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                    .padding(40)
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
        .aspectRatio(1, contentMode: .fit)
        .padding(10)
    }
    
    private var detailsOverlay: some View {
        VStack {
            VStack(spacing: 8) {
                if let song = song {
                    HStack {
                        if song.rating == 1 {
                            Image(systemName: "hand.thumbsup.fill")
                                .foregroundColor(.green)
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
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
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
    
    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .padding()
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview Window

struct AlbumArtPreviewWindow: View {
    
    @ObservedObject var playerViewModel: PlayerViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        AlbumArtPreviewView(
            song: playerViewModel.currentSong,
            artworkImage: playerViewModel.artworkImage,
            isPresented: $isPresented
        )
    }
}

// MARK: - Preview

#Preview {
    AlbumArtPreviewView(
        song: .mock(title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera"),
        artworkImage: nil,
        isPresented: .constant(true)
    )
}
