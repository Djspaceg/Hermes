//
//  NewStationViewModel.swift
//  Hermes
//
//  View model for creating new Pandora stations
//

import Foundation
import Combine
import Observation

// MARK: - Protocol

@MainActor
protocol StationAddViewModelProtocol: AnyObject, Observable {
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
    func searchQueryChanged(_ query: String)
}

// MARK: - View Model

@MainActor
@Observable
final class StationAddViewModel: StationAddViewModelProtocol {
    // MARK: - Observable Properties
    var searchQuery: String = ""
    var searchResults: [SearchResult] = []
    var genres: [GenreCategory] = []
    var isSearching: Bool = false
    var isCreating: Bool = false
    var errorMessage: String?
    var selectedTab: Tab = .search
    var stationCreated: Bool = false
    
    enum Tab: String, CaseIterable {
        case search = "Search"
        case genres = "Genres"
    }
    
    // MARK: - Dependencies
    @ObservationIgnored
    private let pandora: PandoraProtocol
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored
    private var searchDebounceTask: Task<Void, Never>?
    
    @MainActor
    init(pandora: PandoraProtocol? = nil) {
        self.pandora = pandora ?? AppState.shared.pandora
        setupSearchDebounce()
        setupNotificationObservers()
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        // Search results
        NotificationCenter.default.publisher(for: .pandoraDidLoadSearchResults)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                Task { @MainActor in
                    self?.handleSearchResults(notification)
                }
            }
            .store(in: &cancellables)
        
        // Genre stations loaded
        NotificationCenter.default.publisher(for: .pandoraDidLoadGenreStations)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                Task { @MainActor in
                    self?.handleGenreStations(notification)
                }
            }
            .store(in: &cancellables)
        
        // Station created
        NotificationCenter.default.publisher(for: .pandoraDidCreateStation)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleStationCreated()
                }
            }
            .store(in: &cancellables)
        
        // Errors
        NotificationCenter.default.publisher(for: .pandoraDidError)
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
        // With @Observable, we use withObservationTracking or manual debouncing
        // The debouncing will be handled in the view using onChange
    }
    
    func searchQueryChanged(_ query: String) {
        // Cancel any existing debounce task
        searchDebounceTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        // Create a new debounce task
        searchDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            performSearch(query)
        }
    }
    
    func performSearch(_ query: String) {
        isSearching = true
        errorMessage = nil
        searchResults = []
        _ = pandora.search(query)
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
                let artistName = artist.name
                guard !artistName.isEmpty else { continue }
                
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
                let songFullName = song.name
                guard !songFullName.isEmpty else { continue }
                
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
        _ = pandora.createStation(result.musicToken)
    }
    
    func createStation(fromGenre genre: Genre) {
        isCreating = true
        errorMessage = nil
        _ = pandora.createStation(genre.stationToken)
    }
    
    private func handleStationCreated() {
        isCreating = false
        stationCreated = true
    }
    
    // MARK: - Genres
    func loadGenres() {
        guard genres.isEmpty else { return }
        _ = pandora.fetchGenreStations()
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
