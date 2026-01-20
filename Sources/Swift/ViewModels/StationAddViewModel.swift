//
//  NewStationViewModel.swift
//  Hermes
//
//  View model for creating new Pandora stations
//

import Foundation
import Combine

// MARK: - Protocol

@MainActor
protocol StationAddViewModelProtocol: ObservableObject {
    var searchQuery: String { get set }
    var searchResults: [SearchResult] { get set }
    var genres: [GenreCategory] { get set }
    var isSearching: Bool { get set }
    var isCreating: Bool { get set }
    var errorMessage: String? { get set }
    var selectedTab: StationAddViewModel.Tab { get set }
    var stationCreated: Bool { get set }
    
    func loadGenres()
    func createStation(from result: SearchResult)
    func createStation(fromGenre genre: Genre)
}

// MARK: - View Model

@MainActor
final class StationAddViewModel: ObservableObject, StationAddViewModelProtocol {
    // MARK: - Published Properties
    @Published var searchQuery: String = ""
    @Published var searchResults: [SearchResult] = []
    @Published var genres: [GenreCategory] = []
    @Published var isSearching: Bool = false
    @Published var isCreating: Bool = false
    @Published var errorMessage: String?
    @Published var selectedTab: Tab = .search
    @Published var stationCreated: Bool = false
    
    enum Tab: String, CaseIterable {
        case search = "Search"
        case genres = "Genres"
    }
    
    // MARK: - Dependencies
    private let pandora: Pandora
    private var cancellables = Set<AnyCancellable>()
    
    init(pandora: Pandora) {
        self.pandora = pandora
        setupSearchDebounce()
        setupNotificationObservers()
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        // Search results
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidLoadSearchResultsNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                Task { @MainActor in
                    self?.handleSearchResults(notification)
                }
            }
            .store(in: &cancellables)
        
        // Genre stations loaded
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidLoadGenreStationsNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                Task { @MainActor in
                    self?.handleGenreStations(notification)
                }
            }
            .store(in: &cancellables)
        
        // Station created
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidCreateStationNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleStationCreated()
                }
            }
            .store(in: &cancellables)
        
        // Errors
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidErrorNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                Task { @MainActor in
                    self?.handleError(notification)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Search
    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .sink { [weak self] query in
                self?.performSearch(query)
            }
            .store(in: &cancellables)
    }
    
    func performSearch(_ query: String) {
        isSearching = true
        errorMessage = nil
        searchResults = []
        pandora.search(query)
    }
    
    private func handleSearchResults(_ notification: Notification) {
        isSearching = false
        
        guard let userInfo = notification.userInfo as? [String: Any] else {
            return
        }
        
        var results: [SearchResult] = []
        
        // Parse artists
        if let artists = userInfo["Artists"] as? [PandoraSearchResult] {
            for artist in artists {
                guard let artistName = artist.name else { continue }
                
                results.append(SearchResult(
                    id: UUID().uuidString,
                    musicToken: artist.value,
                    name: artistName,
                    artist: nil,
                    type: .artist
                ))
            }
        }
        
        // Parse songs
        if let songs = userInfo["Songs"] as? [PandoraSearchResult] {
            for song in songs {
                guard let songFullName = song.name else { continue }
                
                // Song names from Pandora are in format "Artist - Song"
                let components = songFullName.components(separatedBy: " - ")
                let artistName = components.first ?? ""
                let songName = components.count > 1 ? components.dropFirst().joined(separator: " - ") : songFullName
                
                results.append(SearchResult(
                    id: UUID().uuidString,
                    musicToken: song.value,
                    name: songName,
                    artist: artistName,
                    type: .song
                ))
            }
        }
        
        searchResults = results
    }
    
    // MARK: - Station Creation
    func createStation(from result: SearchResult) {
        isCreating = true
        errorMessage = nil
        pandora.createStation(result.musicToken)
    }
    
    func createStation(fromGenre genre: Genre) {
        isCreating = true
        errorMessage = nil
        pandora.createStation(genre.stationToken)
    }
    
    private func handleStationCreated() {
        isCreating = false
        stationCreated = true
    }
    
    // MARK: - Genres
    func loadGenres() {
        guard genres.isEmpty else { return }
        pandora.fetchGenreStations()
    }
    
    private func handleGenreStations(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any],
              let categories = userInfo["categories"] as? [[String: Any]] else {
            return
        }
        
        var genreCategories: [GenreCategory] = []
        
        for category in categories {
            guard let categoryName = category["categoryName"] as? String,
                  let stations = category["stations"] as? [[String: Any]] else {
                continue
            }
            
            var genreList: [Genre] = []
            for station in stations {
                if let stationName = station["stationName"] as? String,
                   let stationToken = station["stationToken"] as? String {
                    genreList.append(Genre(
                        id: stationToken,
                        name: stationName,
                        stationToken: stationToken
                    ))
                }
            }
            
            if !genreList.isEmpty {
                genreCategories.append(GenreCategory(
                    id: categoryName,
                    name: categoryName,
                    genres: genreList
                ))
            }
        }
        
        self.genres = genreCategories
    }
    
    // MARK: - Error Handling
    private func handleError(_ notification: Notification) {
        isSearching = false
        isCreating = false
        
        // Pandora.m uses "err" key for error message
        if let error = notification.userInfo?["err"] as? String {
            errorMessage = error
        } else if let error = notification.userInfo?["error"] as? String {
            errorMessage = error
        } else {
            errorMessage = "An unknown error occurred"
        }
    }
}

// MARK: - Models

struct SearchResult: Identifiable {
    let id: String
    let musicToken: String
    let name: String
    let artist: String?
    let type: ResultType
    
    enum ResultType: String {
        case artist, song, genre
    }
}

struct GenreCategory: Identifiable {
    let id: String
    let name: String
    let genres: [Genre]
}

struct Genre: Identifiable {
    let id: String
    let name: String
    let stationToken: String
}
