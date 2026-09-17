//
//  SongFeedbackService.swift
//  Hermes
//

import Foundation

@MainActor
final class SongFeedbackService {
    enum RatingResult {
        case rejectedSharedStation
        case rated(shouldSkipSong: Bool)
    }

    private let pandoraProvider: @MainActor () -> PandoraProtocol?

    init(pandoraProvider: @escaping @MainActor () -> PandoraProtocol?) {
        self.pandoraProvider = pandoraProvider
    }

    func rate(_ song: Song, as liked: Bool, songIsPlaying: Bool) -> RatingResult {
        if let station = song.station(), station.shared {
            return .rejectedSharedStation
        }

        var rating = liked ? 1 : -1

        if song.nrating?.intValue == rating {
            rating = 0
        }

        if rating == -1 {
            _ = pandoraProvider()?.rateSong(song, as: false)
            return .rated(shouldSkipSong: songIsPlaying)
        }

        if rating == 0 {
            _ = pandoraProvider()?.deleteRating(song)
        } else {
            _ = pandoraProvider()?.rateSong(song, as: true)
        }

        return .rated(shouldSkipSong: false)
    }
}
