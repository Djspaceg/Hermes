//
//  NowPlayingSnapshotStoreTests.swift
//  HermesTests
//

import Foundation
import Testing
@testable import Hermes

@Suite("Now Playing Snapshot Store")
struct NowPlayingSnapshotStoreTests {
    @Test("writes a complete atomic snapshot and artwork to the injected container")
    func writesSnapshotAndArtwork() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = NowPlayingSnapshotStore(containerURL: directory)
        let snapshot = NowPlayingSnapshot(
            title: "The Chain",
            artist: "Fleetwood Mac",
            album: "Rumours",
            stationName: "Classic Rock Radio",
            playbackState: .playing,
            rating: 1,
            duration: 268,
            elapsedTime: 32,
            playbackStartDate: Date(timeIntervalSince1970: 1_700_000_000),
            artworkFilename: nil
        )
        let artwork = Data([0x89, 0x50, 0x4E, 0x47])

        try store.write(snapshot: snapshot, artworkData: artwork)

        let decoded = try JSONDecoder().decode(
            NowPlayingSnapshot.self,
            from: Data(contentsOf: store.snapshotURL)
        )
        #expect(decoded.title == "The Chain")
        #expect(decoded.artist == "Fleetwood Mac")
        #expect(decoded.album == "Rumours")
        #expect(decoded.stationName == "Classic Rock Radio")
        #expect(decoded.playbackState == .playing)
        #expect(decoded.rating == 1)
        #expect(decoded.duration == 268)
        #expect(decoded.elapsedTime == 32)
        #expect(decoded.playbackStartDate == Date(timeIntervalSince1970: 1_700_000_000))
        let firstArtworkFilename = try #require(decoded.artworkFilename)
        #expect(
            firstArtworkFilename.hasPrefix(
                NowPlayingWidgetConfiguration.artworkFilenamePrefix
            )
        )
        #expect(try Data(contentsOf: store.artworkURL(for: firstArtworkFilename)) == artwork)

        let nextArtwork = Data([0xFF, 0xD8, 0xFF])
        try store.write(
            snapshot: NowPlayingSnapshot(
                title: "Dreams",
                artist: "Fleetwood Mac",
                album: "Rumours",
                stationName: "Classic Rock Radio",
                playbackState: .playing,
                rating: 0,
                duration: 258,
                elapsedTime: 5,
                playbackStartDate: Date(timeIntervalSince1970: 1_700_000_100),
                artworkFilename: nil
            ),
            artworkData: nextArtwork
        )
        let nextSnapshot = try JSONDecoder().decode(
            NowPlayingSnapshot.self,
            from: Data(contentsOf: store.snapshotURL)
        )
        let nextArtworkFilename = try #require(nextSnapshot.artworkFilename)
        #expect(nextArtworkFilename != firstArtworkFilename)
        #expect(
            try Data(contentsOf: store.artworkURL(for: firstArtworkFilename)) == artwork
        )
        #expect(
            try Data(contentsOf: store.artworkURL(for: nextArtworkFilename)) == nextArtwork
        )
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: directory.path)
                .allSatisfy { !$0.hasPrefix(".now-playing") }
        )
    }

    @Test("idle writes replace playback data and clear artwork")
    func writesIdleSnapshot() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = NowPlayingSnapshotStore(containerURL: directory)
        try store.write(
            snapshot: NowPlayingSnapshot(
                title: "Song",
                artist: "Artist",
                album: "Album",
                stationName: "Station",
                playbackState: .paused,
                rating: -1,
                duration: 120,
                elapsedTime: 48,
                playbackStartDate: Date(),
                artworkFilename: nil
            ),
            artworkData: Data([1, 2, 3])
        )

        try store.writeIdleSnapshot()

        #expect(store.readSnapshot() == .idle)
        #expect(store.readSnapshot().artworkFilename == nil)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HermesNowPlayingSnapshotTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false
        )
        return directory
    }
}
