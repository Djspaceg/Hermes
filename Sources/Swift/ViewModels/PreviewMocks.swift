//
//  PreviewMocks.swift
//  Hermes
//
//  Preview-only mock view models that don't connect to any live data
//

import SwiftUI
import Combine
import Observation

// MARK: - Preview History View Model

@MainActor
@Observable
final class PreviewHistoryViewModel {
    var historyItems: [Song] = []
    var selectedItem: Song?
    
    init(items: [Song] = []) {
        self.historyItems = items
    }
    
    func likeSong(_ song: Song) {}
    func dislikeSong(_ song: Song) {}
    func playSong(_ song: Song) {}
    func openArtistOnPandora() {}
    func openSongOnPandora() {}
    func openAlbumOnPandora() {}
    func showLyrics() {}
    func likeSelected() {}
    func dislikeSelected() {}
}

// MARK: - Preview Stations View Model

@MainActor
@Observable
final class PreviewStationsViewModel {
    var stations: [Station] = []
    var playingStationId: String?
    var selectedStationId: String?
    var showDeleteConfirmation = false
    var stationToDelete: Station?
    var showRenameDialog = false
    var newStationName = ""
    var stationToEdit: Station?
    var showAddStationSheet = false
    
    @ObservationIgnored
    let pandora: PandoraClient
    let artworkLoader = StationArtworkLoader.shared
    
    init(stations: [Station] = [], pandora: PandoraClient = PandoraClient()) {
        self.stations = stations
        self.pandora = pandora
    }
    
    func sortedStations(by order: StationsViewModel.SortOrder) -> [Station] {
        stations
    }
    
    func playStation(_ station: Station) {}
    func editStation(_ station: Station) {}
    func startRenameStation(_ station: Station) {}
    func confirmDeleteStation(_ station: Station) {}
    func performDeleteStation() {}
    func performRenameStation() {}
    func showAddStation() {
        showAddStationSheet = true
    }
    func refreshStations() async {}
}

// MARK: - Preview Login View Model

@MainActor
@Observable
final class PreviewLoginViewModel {
    var username = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?
    
    var canSubmit: Bool {
        !username.isEmpty && !password.isEmpty && !isLoading
    }
    
    func authenticate() async throws {}
}

// MARK: - Preview New Station View Model

@MainActor
@Observable
final class PreviewNewStationViewModel: StationAddViewModelProtocol {
    var selectedTab: StationAddViewModel.Tab = .search
    var searchQuery = ""
    var searchResults: [SearchResult] = [
        SearchResult(id: "1", musicToken: "token1", name: "Radiohead", artist: nil, type: .artist),
        SearchResult(id: "2", musicToken: "token2", name: "Creep", artist: "Radiohead", type: .song),
        SearchResult(id: "3", musicToken: "token3", name: "Karma Police", artist: "Radiohead", type: .song)
    ]
    var isSearching = false
    var genres: [GenreCategory] = [
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
    var isCreating = false
    var errorMessage: String?
    var stationCreated = false
    
    func loadGenres() {}
    func createStation(from result: SearchResult) {}
    func createStation(fromGenre genre: Genre) {}
    func searchQueryChanged(_ query: String) {}
}

// MARK: - Preview Station Editor View Model

@MainActor
@Observable
final class PreviewStationEditViewModel: StationEditViewModelProtocol {
    var isLoading = false
    var isSaving = false
    var stationName = "My Station"
    var stationCreated = "January 1, 2024"
    var stationGenres = "Rock, Alternative"
    var artworkURL: URL?
    var seeds: [Seed] = []
    var likes: [FeedbackItem] = []
    var dislikes: [FeedbackItem] = []
    var seedSearchQuery = ""
    var seedSearchResults: [SeedSearchResult] = []
    var isSearchingSeeds = false
    
    func loadDetailsIfNeeded() {}
    func renameStation(to name: String) {}
    func openInPandora() {}
    func addSeed(_ result: SeedSearchResult) {}
    func deleteSeed(_ seed: Seed) {}
    func deleteFeedback(_ item: FeedbackItem) {}
    func seedSearchQueryChanged(_ query: String) {}
}
