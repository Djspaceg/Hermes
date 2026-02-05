//
//  HistoryViewModel.swift
//  Hermes
//
//  Manages playback history
//

import Foundation
import AppKit
import Combine
import Observation

@MainActor
@Observable
final class HistoryViewModel {
    var historyItems: [Song] = []
    var selectedItem: Song?
    
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored
    private let maxHistoryItems = 20 // Maximum number of history items to retain
    @ObservationIgnored
    private let saveStatePath: String
    
    // Distributed notification name for external app integration
    @ObservationIgnored
    private let distributedNotificationName = "hermes.song"
    
    init() {
        // Set up save state path in application support directory
        let folder = ("~/Library/Application Support/Hermes/" as NSString).expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        saveStatePath = (folder as NSString).appendingPathComponent("history.savestate")
        
        setupNotificationSubscriptions()
        loadSavedHistory()
    }
    
    private func setupNotificationSubscriptions() {
        NotificationCenter.default.songPlayingPublisher
            .sink { [weak self] song in
                self?.addToHistory(song)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Persistence
    
    private func loadSavedHistory() {
        guard FileManager.default.fileExists(atPath: saveStatePath) else { return }
        
        Task.detached(priority: .utility) {
            do {
                let url = URL(fileURLWithPath: self.saveStatePath)
                let data = try Data(contentsOf: url)
                
                // Use NSKeyedUnarchiver to read archived Song objects
                if let songs = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, Song.self], from: data) as? [Song] {
                    await MainActor.run {
                        self.historyItems = songs
                    }
                }
            } catch {
                print("HistoryViewModel: Failed to load saved history (likely old format): \(error)")
                print("HistoryViewModel: Deleting old history file and starting fresh")
                
                // Delete the old incompatible history file
                try? FileManager.default.removeItem(atPath: self.saveStatePath)
            }
        }
    }
    
    func saveHistory() -> Bool {
        // Song objects are directly archivable via NSSecureCoding
        let songs = historyItems
        let path = saveStatePath
        
        // Save asynchronously on background thread
        Task.detached(priority: .utility) {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: songs, requiringSecureCoding: false)
                try data.write(to: URL(fileURLWithPath: path))
            } catch {
                print("HistoryViewModel: Failed to save history: \(error)")
            }
        }
        
        return true
    }
    
    // MARK: - History Management
    
    func addToHistory(_ song: Song) {
        // Avoid duplicates
        if let existingIndex = historyItems.firstIndex(where: { $0.id == song.id }) {
            historyItems.remove(at: existingIndex)
        }
        
        historyItems.insert(song, at: 0)
        
        // Post distributed notification (for external apps/scripts)
        postDistributedNotification(for: song)
        
        // Trim to limit
        if historyItems.count > maxHistoryItems {
            historyItems = Array(historyItems.prefix(maxHistoryItems))
        }
        
        // Save to disk
        _ = saveHistory()
    }
    
    private func postDistributedNotification(for song: Song) {
        // Create dictionary matching Song's toDictionary format
        let userInfo: [String: Any] = [
            "artist": song.artist,
            "title": song.title,
            "album": song.album,
            "art": song.art ?? "",
            "stationId": song.stationId ?? "",
            "nrating": song.nrating ?? NSNumber(value: 0),
            "albumUrl": song.albumUrl ?? "",
            "artistUrl": song.artistUrl ?? "",
            "titleUrl": song.titleUrl ?? "",
            "token": song.token ?? ""
        ]
        
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(distributedNotificationName),
            object: "hermes",
            userInfo: userInfo,
            deliverImmediately: true
        )
    }
    
    func clearHistory() {
        historyItems.removeAll()
        _ = saveHistory()
    }
    
    // MARK: - History Actions
    
    func openSongOnPandora() {
        guard let song = selectedItem else { return }
        if let urlString = song.titleUrl,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openArtistOnPandora() {
        guard let song = selectedItem else { return }
        if let urlString = song.artistUrl,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openAlbumOnPandora() {
        guard let song = selectedItem else { return }
        if let urlString = song.albumUrl,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func showLyrics() {
        guard let song = selectedItem else { return }
        let searchQuery = "\(song.title) \(song.artist) lyrics"
        if let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://www.google.com/search?q=\(encodedQuery)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func likeSelected() {
        guard let song = selectedItem else { return }
        MinimalAppDelegate.shared?.playbackController?.rate(song, as: true)
    }
    
    func dislikeSelected() {
        guard let song = selectedItem else { return }
        MinimalAppDelegate.shared?.playbackController?.rate(song, as: false)
    }
    
    // MARK: - Song Actions (for context menu and double-click)
    
    func playSong(_ song: Song) {
        // History items can't be directly played - they're past songs
        // But we can create a station from the song
        print("HistoryViewModel: playSong called for '\(song.title)' - creating station")
        // For now, just select it
        selectedItem = song
    }
    
    func likeSong(_ song: Song) {
        MinimalAppDelegate.shared?.playbackController?.rate(song, as: true)
    }
    
    func dislikeSong(_ song: Song) {
        MinimalAppDelegate.shared?.playbackController?.rate(song, as: false)
    }
}

// MARK: - Preview Helpers

extension HistoryViewModel {
    /// Creates a mock HistoryViewModel for SwiftUI previews
    static func mock(items: [Song] = []) -> HistoryViewModel {
        let viewModel = HistoryViewModel()
        viewModel.historyItems = items
        return viewModel
    }
}
