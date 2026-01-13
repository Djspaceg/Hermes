//
//  HistoryListView.swift
//  Hermes
//
//  List of history items for sidebar
//

import SwiftUI

struct HistoryListView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @Binding var selectedItem: SongModel?
    
    var body: some View {
        List(viewModel.historyItems, id: \.id, selection: $selectedItem) { song in
            HistoryRow(song: song)
                .tag(song)
                .contextMenu {
                    Button("Like") {
                        viewModel.likeSong(song)
                    }
                    Button("Dislike", role: .destructive) {
                        viewModel.dislikeSong(song)
                    }
                    
                    Divider()
                    
                    Button("Open Artist in Pandora") {
                        selectedItem = song
                        viewModel.openArtistOnPandora()
                    }
                    Button("Open Song in Pandora") {
                        selectedItem = song
                        viewModel.openSongOnPandora()
                    }
                    Button("Open Album in Pandora") {
                        selectedItem = song
                        viewModel.openAlbumOnPandora()
                    }
                    
                    Divider()
                    
                    Button("Search Lyrics...") {
                        selectedItem = song
                        viewModel.showLyrics()
                    }
                }
                .onDoubleClick {
                    viewModel.playSong(song)
                }
        }
        .listStyle(.sidebar)
    }
}

struct HistoryRow: View {
    let song: SongModel
    
    var body: some View {
        HStack(spacing: 8) {
            AsyncImage(url: song.artworkURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 40, height: 40)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .cornerRadius(4)
                case .failure:
                    Image(systemName: "music.note")
                        .foregroundColor(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(4)
                @unknown default:
                    EmptyView()
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Text(song.artist)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if song.rating == 1 {
                Image(systemName: "hand.thumbsup.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .contentShape(Rectangle())
    }
}


// MARK: - Preview

#Preview {
    // Create a wrapper that doesn't use real view models
    HistoryListPreview()
        .frame(width: 250, height: 400)
}

private struct HistoryListPreview: View {
    @StateObject private var viewModel: PreviewHistoryViewModel = {
        let items: [SongModel] = [
            .mock(title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera", rating: 1),
            .mock(title: "Stairway to Heaven", artist: "Led Zeppelin", album: "Led Zeppelin IV"),
            .mock(title: "Hotel California", artist: "Eagles", album: "Hotel California", rating: 1)
        ]
        return PreviewHistoryViewModel(items: items)
    }()
    @State private var selectedItem: SongModel?
    
    var body: some View {
        List(viewModel.historyItems, id: \.id, selection: $selectedItem) { song in
            HistoryRow(song: song)
                .tag(song)
        }
        .listStyle(.sidebar)
    }
}
