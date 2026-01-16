//
//  PreviewMocks.swift
//  Hermes
//
//  Preview-only mock view models that don't connect to any live data
//

import SwiftUI
import Combine

// MARK: - Preview History View Model

@MainActor
final class PreviewHistoryViewModel: ObservableObject {
    @Published var historyItems: [SongModel] = []
    @Published var selectedItem: SongModel?
    
    init(items: [SongModel] = []) {
        self.historyItems = items
    }
    
    func likeSong(_ song: SongModel) {}
    func dislikeSong(_ song: SongModel) {}
    func playSong(_ song: SongModel) {}
    func openArtistOnPandora() {}
    func openSongOnPandora() {}
    func openAlbumOnPandora() {}
    func showLyrics() {}
    func likeSelected() {}
    func dislikeSelected() {}
}

// MARK: - Preview Stations View Model

@MainActor
final class PreviewStationsViewModel: ObservableObject {
    @Published var stations: [StationModel] = []
    @Published var playingStationId: String?
    @Published var selectedStationId: String?
    @Published var showDeleteConfirmation = false
    @Published var stationToDelete: StationModel?
    @Published var showRenameDialog = false
    @Published var newStationName = ""
    @Published var stationToEdit: StationModel?
    @Published var showAddStationSheet = false
    
    let pandora: Pandora
    
    init(stations: [StationModel] = [], pandora: Pandora = Pandora()) {
        self.stations = stations
        self.pandora = pandora
    }
    
    func sortedStations(by order: StationsViewModel.SortOrder) -> [StationModel] {
        stations
    }
    
    func playStation(_ station: StationModel) {}
    func editStation(_ station: StationModel) {}
    func startRenameStation(_ station: StationModel) {}
    func confirmDeleteStation(_ station: StationModel) {}
    func performDeleteStation() {}
    func performRenameStation() {}
    func showAddStation() {
        showAddStationSheet = true
    }
    func refreshStations() async {}
}

// MARK: - Preview Login View Model

@MainActor
final class PreviewLoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var canSubmit: Bool {
        !username.isEmpty && !password.isEmpty && !isLoading
    }
    
    func authenticate() async throws {}
}

// MARK: - Preview New Station View Model

@MainActor
final class PreviewNewStationViewModel: ObservableObject, StationAddViewModelProtocol {
    @Published var selectedTab: StationAddViewModel.Tab = .search
    @Published var searchQuery = ""
    @Published var searchResults: [SearchResult] = [
        SearchResult(id: "1", musicToken: "token1", name: "Radiohead", artist: nil, type: .artist),
        SearchResult(id: "2", musicToken: "token2", name: "Creep", artist: "Radiohead", type: .song),
        SearchResult(id: "3", musicToken: "token3", name: "Karma Police", artist: "Radiohead", type: .song)
    ]
    @Published var isSearching = false
    @Published var genres: [GenreCategory] = [
        GenreCategory(id: "rock", name: "Rock", genres: [
            Genre(id: "g1", name: "Classic Rock", stationToken: "t1"),
            Genre(id: "g2", name: "Alternative Rock", stationToken: "t2"),
            Genre(id: "g3", name: "Indie Rock", stationToken: "t3")
        ]),
        GenreCategory(id: "pop", name: "Pop", genres: [
            Genre(id: "g4", name: "Pop Hits", stationToken: "t4"),
            Genre(id: "g5", name: "Indie Pop", stationToken: "t5")
        ])
    ]
    @Published var isCreating = false
    @Published var errorMessage: String?
    @Published var stationCreated = false
    
    func loadGenres() {}
    func createStation(from result: SearchResult) {}
    func createStation(fromGenre genre: Genre) {}
}

// MARK: - Preview Station Editor View Model

@MainActor
final class PreviewStationEditViewModel: ObservableObject, StationEditViewModelProtocol {
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var stationName = "My Station"
    @Published var stationCreated = "January 1, 2024"
    @Published var stationGenres = "Rock, Alternative"
    @Published var artworkURL: URL?
    @Published var seeds: [Seed] = []
    @Published var likes: [FeedbackItem] = []
    @Published var dislikes: [FeedbackItem] = []
    @Published var seedSearchQuery = ""
    @Published var seedSearchResults: [SeedSearchResult] = []
    @Published var isSearchingSeeds = false
    
    func loadDetailsIfNeeded() {}
    func renameStation(to name: String) {}
    func openInPandora() {}
    func addSeed(_ result: SeedSearchResult) {}
    func deleteSeed(_ seed: Seed) {}
    func deleteFeedback(_ item: FeedbackItem) {}
}
