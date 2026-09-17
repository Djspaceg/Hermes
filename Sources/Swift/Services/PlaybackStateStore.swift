//
//  PlaybackStateStore.swift
//  Hermes
//
//  Persistence ownership for PlaybackController station state.
//

import Foundation

protocol PlaybackStateStoring {
    func recordSelection(_ station: Station)
    func clearSelection()
    func deleteSavedState()
    func save(station: Station?) -> Bool
}

final class PlaybackStateStore: PlaybackStateStoring {
    private let userDefaults: UserDefaults
    private let resolveStatePath: (String) -> String?

    convenience init(userDefaults: UserDefaults = .standard) {
        self.init(
            userDefaults: userDefaults,
            resolveStatePath: Self.stateDirectory
        )
    }

    init(
        userDefaults: UserDefaults,
        resolveStatePath: @escaping (String) -> String?
    ) {
        self.userDefaults = userDefaults
        self.resolveStatePath = resolveStatePath
    }

    func recordSelection(_ station: Station) {
        userDefaults.set(station.stationId, forKey: UserDefaultsKeys.lastStation)

        let timestamp = Date().timeIntervalSince1970
        station.lastPlayedTimestamp = timestamp

        var timestamps = userDefaults.dictionary(forKey: UserDefaultsKeys.stationPlayTimestamps) as? [String: TimeInterval] ?? [:]
        timestamps[station.stationId] = timestamp
        userDefaults.set(timestamps, forKey: UserDefaultsKeys.stationPlayTimestamps)
    }

    func clearSelection() {
        userDefaults.removeObject(forKey: UserDefaultsKeys.lastStation)
    }

    func deleteSavedState() {
        if let path = resolveStatePath("station.savestate") {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    @discardableResult
    func save(station: Station?) -> Bool {
        guard let path = resolveStatePath("station.savestate"),
              let station else {
            return false
        }

        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: station, requiringSecureCoding: true)
            try data.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            NSLog("Failed to save state: \(error)")
            return false
        }
    }

    private static func stateDirectory(_ file: String) -> String? {
        let fileManager = FileManager.default
        let folder = NSString(string: "~/Library/Application Support/Hermes/").expandingTildeInPath

        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: folder, isDirectory: &isDirectory) {
            try? fileManager.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
        }

        return (folder as NSString).appendingPathComponent(file)
    }
}
