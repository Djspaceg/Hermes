//
//  HistoryViewModel.swift
//  Hermes
//
//  Manages playback history
//

import Foundation
import AppKit
import Combine

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var historyItems: [SongModel] = []
    @Published var selectedItem: SongModel? {
        didSet {
            // When selection changes, observe the new item's rating changes
            selectedItemRatingCancellable?.cancel()
            if let selectedItem = selectedItem {
                selectedItemRatingCancellable = selectedItem.$rating
                    .sink { [weak self] _ in
                        // Trigger view update by reassigning selectedItem
                        // This forces SwiftUI to re-evaluate the footer buttons
                        self?.objectWillChange.send()
                    }
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var selectedItemRatingCancellable: AnyCancellable?
    private let maxHistoryItems = 20 // Match Objective-C HISTORY_LIMIT
    private let saveStatePath: String
    
    // Distributed notification name (matches Objective-C constant)
    private let distributedNotificationName = "hermes.song"
    
    init() {
        // Set up save state path (matches Objective-C stateDirectory)
        let folder = ("~/Library/Application Support/Hermes/" as NSString).expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        saveStatePath = (folder as NSString).appendingPathComponent("history.savestate")
        
        setupNotificationSubscriptions()
        loadSavedHistory()
    }
    
    private func setupNotificationSubscriptions() {
        NotificationCenter.default.songPlayingPublisher
            .sink { [weak self] song in
                self?.addToHistory(SongModel(song: song))
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Persistence
    
    private func loadSavedHistory() {
        guard FileManager.default.fileExists(atPath: saveStatePath) else { return }
        
        Task {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: saveStatePath))
                
                // Use NSKeyedUnarchiver to read archived Song objects
                if let songs = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, Song.self], from: data) as? [Song] {
                    historyItems = songs.map { SongModel(song: $0) }
                }
            } catch {
                print("HistoryViewModel: Failed to load saved history (likely old format): \(error)")
                print("HistoryViewModel: Deleting old history file and starting fresh")
                
                // Delete the old incompatible history file
                try? FileManager.default.removeItem(atPath: saveStatePath)
            }
        }
    }
    
    func saveHistory() -> Bool {
        // Convert SongModel back to Song objects for NSKeyedArchiver
        let songs = historyItems.map { $0.song }
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: songs, requiringSecureCoding: false)
            try data.write(to: URL(fileURLWithPath: saveStatePath))
            return true
        } catch {
            print("HistoryViewModel: Failed to save history: \(error)")
            return false
        }
    }
    
    // MARK: - History Management
    
    func addToHistory(_ song: SongModel) {
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
    
    private func postDistributedNotification(for song: SongModel) {
        // Create dictionary matching Song's toDictionary format
        let userInfo: [String: Any] = [
            "artist": song.artist,
            "title": song.title,
            "album": song.album,
            "art": song.song.art ?? "",
            "stationId": song.song.stationId ?? "",
            "nrating": song.song.nrating ?? NSNumber(value: 0),
            "albumUrl": song.song.albumUrl ?? "",
            "artistUrl": song.song.artistUrl ?? "",
            "titleUrl": song.song.titleUrl ?? "",
            "token": song.song.token ?? ""
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
        if let urlString = song.song.titleUrl,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openArtistOnPandora() {
        guard let song = selectedItem else { return }
        if let urlString = song.song.artistUrl,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openAlbumOnPandora() {
        guard let song = selectedItem else { return }
        if let urlString = song.song.albumUrl,
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
        MinimalAppDelegate.shared?.playbackController?.rate(song.song, as: true)
    }
    
    func dislikeSelected() {
        guard let song = selectedItem else { return }
        MinimalAppDelegate.shared?.playbackController?.rate(song.song, as: false)
    }
    
    // MARK: - Song Actions (for context menu and double-click)
    
    func playSong(_ song: SongModel) {
        // History items can't be directly played - they're past songs
        // But we can create a station from the song
        print("HistoryViewModel: playSong called for '\(song.title)' - creating station")
        // For now, just select it
        selectedItem = song
    }
    
    func likeSong(_ song: SongModel) {
        MinimalAppDelegate.shared?.playbackController?.rate(song.song, as: true)
    }
    
    func dislikeSong(_ song: SongModel) {
        MinimalAppDelegate.shared?.playbackController?.rate(song.song, as: false)
    }
}

// MARK: - Preview Helpers

extension HistoryViewModel {
    /// Creates a mock HistoryViewModel for SwiftUI previews
    static func mock(items: [SongModel] = []) -> HistoryViewModel {
        let viewModel = HistoryViewModel()
        viewModel.historyItems = items
        return viewModel
    }
}
