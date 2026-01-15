//
//  SongModel.swift
//  Hermes
//
//  Swift wrapper for Objective-C Song class
//

import Foundation

struct SongModel: Identifiable, Hashable {
    let objcSong: Song
    
    var id: String { objcSong.token ?? UUID().uuidString }
    var title: String { objcSong.title ?? "Unknown" }
    var artist: String { objcSong.artist ?? "Unknown Artist" }
    var album: String { objcSong.album ?? "Unknown Album" }
    var artworkURL: URL? { 
        guard let art = objcSong.art else { return nil }
        return URL(string: art)
    }
    var rating: Int { objcSong.nrating?.intValue ?? 0 }
    
    // Pandora web URLs
    var titleUrl: String? { objcSong.titleUrl }
    var artistUrl: String? { objcSong.artistUrl }
    var albumUrl: String? { objcSong.albumUrl }
    
    init(song: Song) {
        self.objcSong = song
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
