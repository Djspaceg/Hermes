//
//  SongModel.swift
//  Hermes
//
//  SwiftUI-friendly view model for Song
//

import Foundation
import Combine

final class SongModel: ObservableObject, Identifiable, Hashable {
    let song: Song
    
    // Published properties that can change
    @Published var rating: Int
    
    nonisolated var id: String { song.token ?? UUID().uuidString }
    var title: String { song.title }
    var artist: String { song.artist }
    var album: String { song.album }
    var artworkURL: URL? {
        guard let art = song.art else { return nil }
        return URL(string: art)
    }
    
    // Pandora web URLs
    var titleUrl: String? { song.titleUrl }
    var artistUrl: String? { song.artistUrl }
    var albumUrl: String? { song.albumUrl }
    
    // Audio quality and feedback
    var trackGain: String? { song.trackGain }
    var allowFeedback: Bool { song.allowFeedback }
    
    private var cancellables = Set<AnyCancellable>()
    
    init(song: Song) {
        self.song = song
        self.rating = song.nrating?.intValue ?? 0
        setupRatingObserver()
    }
    
    private func setupRatingObserver() {
        // Observe rating changes from Objective-C layer
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidRateSongNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let ratedSong = notification.object as? Song else { return }
                
                // Match by token (song ID) instead of object identity
                // This allows rating updates to propagate to all SongModel instances
                // representing the same song
                if let myToken = self.song.token,
                   let ratedToken = ratedSong.token,
                   myToken == ratedToken {
                    self.rating = ratedSong.nrating?.intValue ?? 0
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Hashable
    
    nonisolated static func == (lhs: SongModel, rhs: SongModel) -> Bool {
        lhs.song === rhs.song
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(song))
    }
}

// MARK: - Preview Helpers

extension SongModel {
    /// Creates a mock SongModel for SwiftUI previews and testing
    static func mock(
        title: String = "Bohemian Rhapsody",
        artist: String = "Queen",
        album: String = "A Night at the Opera",
        artworkURL: String? = "https://example.com/art.jpg",
        rating: Int = 0
    ) -> SongModel {
        let song = Song()
        song.title = title
        song.artist = artist
        song.album = album
        song.art = artworkURL
        song.nrating = NSNumber(value: rating)
        song.token = UUID().uuidString
        return SongModel(song: song)
    }
}


