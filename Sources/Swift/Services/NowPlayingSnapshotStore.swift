//
//  NowPlayingSnapshotStore.swift
//  Hermes
//

import Foundation

struct NowPlayingSnapshotStore {
    let containerURL: URL
    private let fileManager: FileManager

    var snapshotURL: URL {
        containerURL.appendingPathComponent(NowPlayingWidgetConfiguration.snapshotFilename)
    }

    func artworkURL(for filename: String) -> URL {
        containerURL.appendingPathComponent(filename)
    }

    init(
        containerURL: URL,
        fileManager: FileManager = .default
    ) {
        self.containerURL = containerURL
        self.fileManager = fileManager
    }

    static func appGroupStore() -> NowPlayingSnapshotStore? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: NowPlayingWidgetConfiguration.appGroupIdentifier
        ) else {
            return nil
        }

        return NowPlayingSnapshotStore(containerURL: containerURL)
    }

    func write(
        snapshot: NowPlayingSnapshot,
        artworkData: Data?
    ) throws {
        try fileManager.createDirectory(
            at: containerURL,
            withIntermediateDirectories: true
        )

        let artworkFilename: String?
        if let artworkData {
            let filename = NowPlayingWidgetConfiguration.artworkFilenamePrefix
                + UUID().uuidString
            try artworkData.write(to: artworkURL(for: filename), options: .atomic)
            artworkFilename = filename
        } else {
            artworkFilename = nil
        }

        let snapshot = snapshot.replacingArtworkFilename(with: artworkFilename)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: snapshotURL, options: .atomic)
        removeStaleArtwork(excluding: artworkFilename)
    }

    func writeIdleSnapshot() throws {
        try write(snapshot: .idle, artworkData: nil)
    }

    func readSnapshot() -> NowPlayingSnapshot {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(NowPlayingSnapshot.self, from: data) else {
            return .idle
        }

        return snapshot
    }

    private func removeStaleArtwork(excluding artworkFilename: String?) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: containerURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return
        }

        let earliestRemovalDate = Date().addingTimeInterval(-24 * 60 * 60)
        for fileURL in files where
            fileURL.lastPathComponent.hasPrefix(
                NowPlayingWidgetConfiguration.artworkFilenamePrefix
            ) &&
            fileURL.lastPathComponent != artworkFilename {
            let modificationDate = try? fileURL.resourceValues(
                forKeys: [.contentModificationDateKey]
            ).contentModificationDate
            if (modificationDate ?? .distantPast) < earliestRemovalDate {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}

private extension NowPlayingSnapshot {
    func replacingArtworkFilename(with artworkFilename: String?) -> NowPlayingSnapshot {
        NowPlayingSnapshot(
            title: title,
            artist: artist,
            album: album,
            stationName: stationName,
            playbackState: playbackState,
            rating: rating,
            duration: duration,
            elapsedTime: elapsedTime,
            playbackStartDate: playbackStartDate,
            artworkFilename: artworkFilename
        )
    }
}
