//
//  SongInfoView.swift
//  Hermes
//
//  Reusable song metadata display component
//

import SwiftUI

// MARK: - Song Info View

/// Displays song title, artist, and album with glass effect styling
struct SongInfoView: View {
  // MARK: - Properties
  
  let song: Song
  
  // MARK: - Body
  
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

// MARK: - Previews

#Preview("Song Info") {
  SongInfoView(
    song: .mock(
      title: "Bohemian Rhapsody",
      artist: "Queen",
      album: "A Night at the Opera"
    )
  )
  .padding()
  .frame(width: 300)
  .background(.black)
}

#Preview("Long Text") {
  SongInfoView(
    song: .mock(
      title: "This Is A Very Long Song Title That Should Truncate",
      artist: "An Artist With A Really Long Name",
      album: "An Album With An Extremely Long Title That Goes On Forever"
    )
  )
  .padding()
  .frame(width: 300)
  .background(.black)
}
