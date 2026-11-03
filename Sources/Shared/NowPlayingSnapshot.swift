//
//  NowPlayingSnapshot.swift
//  Hermes
//

import Foundation

enum NowPlayingWidgetConfiguration {
    static let appGroupIdentifier = "4D22XL743H.com.alexcrichton.hermes"
    static let kind = "HermesNowPlayingWidget"
    static let snapshotFilename = "now-playing.json"
    static let artworkFilenamePrefix = "now-playing-artwork-"
}

enum NowPlayingPlaybackState: String, Codable, Equatable, Sendable {
    case playing
    case paused
    case idle
}

struct NowPlayingSnapshot: Codable, Equatable, Sendable {
    let title: String
    let artist: String
    let album: String
    let stationName: String
    let playbackState: NowPlayingPlaybackState
    let rating: Int
    let duration: TimeInterval
    let elapsedTime: TimeInterval
    let playbackStartDate: Date?
    let artworkFilename: String?

    static let idle = NowPlayingSnapshot(
        title: "",
        artist: "",
        album: "",
        stationName: "",
        playbackState: .idle,
        rating: 0,
        duration: 0,
        elapsedTime: 0,
        playbackStartDate: nil,
        artworkFilename: nil
    )
}
