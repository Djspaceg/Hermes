//
//  AlbumArtworkView.swift
//  Hermes
//
//  Reusable album artwork display component with tap interaction
//

import SwiftUI

// MARK: - Album Artwork View

/// Displays album artwork with fallback placeholder and tap interaction
struct AlbumArtworkView: View {
  // MARK: - Properties
  
  let song: Song
  let artworkImage: NSImage?
  let onTap: () -> Void
  
  // MARK: - Body
  
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

// MARK: - Placeholder Artwork

/// Placeholder artwork with gradient background and music note icon
struct PlaceholderArtwork: View {
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        MeshGradient(
          width: 2,
          height: 2,
          points: [[0, 0], [0, 1], [1, 0], [1, 1]],
          colors: [
            .purple.opacity(0.4), .indigo.opacity(0.3), .blue.opacity(0.3),
            .cyan.opacity(0.5),
          ]
        )

        Image(systemName: "music.note")
          .font(
            .system(size: min(geometry.size.width, geometry.size.height) * 0.25)
          )
          .foregroundStyle(.white.opacity(0.9))
          .shadow(color: .black.opacity(0.3), radius: 4)
      }
    }
  }
}

// MARK: - Previews

#Preview("With Artwork") {
  AlbumArtworkView(
    song: .mock(
      title: "Bohemian Rhapsody",
      artist: "Queen",
      album: "A Night at the Opera"
    ),
    artworkImage: NSImage(systemSymbolName: "music.note", accessibilityDescription: nil),
    onTap: { print("Tapped") }
  )
  .frame(width: 400, height: 400)
}

#Preview("Placeholder") {
  AlbumArtworkView(
    song: .mock(
      title: "Test Song",
      artist: "Test Artist",
      album: "Test Album"
    ),
    artworkImage: nil,
    onTap: { print("Tapped") }
  )
  .frame(width: 400, height: 400)
}
