//
//  StationEditorViewModel.swift
//  Hermes
//
//  View model for editing station details, seeds, and feedback
//

import Foundation
import AppKit
import Combine

// MARK: - Protocol

@MainActor
protocol StationEditViewModelProtocol: ObservableObject {
    var stationName: String { get set }
    var stationCreated: String { get set }
    var stationGenres: String { get set }
    var artworkURL: URL? { get set }
    var seeds: [Seed] { get set }
    var likes: [FeedbackItem] { get set }
    var dislikes: [FeedbackItem] { get set }
    var seedSearchQuery: String { get set }
    var seedSearchResults: [SeedSearchResult] { get set }
    var isSearchingSeeds: Bool { get set }
    var isLoading: Bool { get set }
    var isSaving: Bool { get set }
    
    func loadDetailsIfNeeded()
    func renameStation(to name: String)
    func openInPandora()
    func addSeed(_ result: SeedSearchResult)
    func deleteSeed(_ seed: Seed)
    func deleteFeedback(_ item: FeedbackItem)
}

// MARK: - View Model

@MainActor
final class StationEditViewModel: ObservableObject, StationEditViewModelProtocol {
    // MARK: - Published Properties
    
    @Published var stationName: String = ""
    @Published var stationCreated: String = ""
    @Published var stationGenres: String = ""
    @Published var artworkURL: URL?
    @Published var stationURL: String = ""
    
    @Published var seeds: [Seed] = []
    @Published var likes: [FeedbackItem] = []
    @Published var dislikes: [FeedbackItem] = []
    
    @Published var seedSearchQuery: String = ""
    @Published var seedSearchResults: [SeedSearchResult] = []
    @Published var isSearchingSeeds: Bool = false
    
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let station: Station
    private let pandora: PandoraClient
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(station: Station, pandora: PandoraClient) {
        self.station = station
        self.pandora = pandora
        self.stationName = station.name ?? ""
        setupSeedSearchDebounce()
        setupNotificationObservers()
        // Don't load details immediately - wait for explicit call
    }
    
    // MARK: - Public Methods
    
    /// Call this when the view appears to load station details
    func loadDetailsIfNeeded() {
        guard seeds.isEmpty && likes.isEmpty && dislikes.isEmpty else { return }
        loadStationDetails()
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Station info loaded
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidLoadStationInfoNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleStationInfo(notification)
            }
            .store(in: &cancellables)
        
        // Station renamed
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidRenameStationNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleStationRenamed()
            }
            .store(in: &cancellables)
        
        // Seed search results
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidLoadSearchResultsNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleSeedSearchResults(notification)
            }
            .store(in: &cancellables)
        
        // Seed added
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidAddSeedNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleSeedAdded(notification)
            }
            .store(in: &cancellables)
        
        // Seed deleted
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidDeleteSeedNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleSeedDeleted()
            }
            .store(in: &cancellables)
        
        // Feedback deleted
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidDeleteFeedbackNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleFeedbackDeleted(notification)
            }
            .store(in: &cancellables)
        
        // Errors
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidErrorNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleError(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Load Station Details
    
    private func loadStationDetails() {
        isLoading = true
        stationName = station.name ?? ""
        pandora.fetchStationInfo(station)
    }
    
    private func handleStationInfo(_ notification: Notification) {
        isLoading = false
        
        guard let userInfo = notification.userInfo as? [String: Any] else {
            return
        }
        
        // Basic info
        if let name = userInfo["name"] as? String {
            stationName = name
        }
        
        if let created = userInfo["created"] as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            stationCreated = formatter.string(from: created)
        }
        
        if let genres = userInfo["genres"] as? [String] {
            stationGenres = genres.joined(separator: ", ")
        }
        
        if let artURLString = userInfo["art"] as? String {
            artworkURL = URL(string: artURLString)
        }
        
        if let url = userInfo["url"] as? String {
            stationURL = url
        }
        
        // Parse seeds
        parseSeeds(userInfo)
        
        // Parse feedback
        parseFeedback(userInfo)
    }
    
    private func parseSeeds(_ userInfo: [String: Any]) {
        var seedList: [Seed] = []
        
        if let seedsDict = userInfo["seeds"] as? [String: Any] {
            // Artist seeds
            if let artists = seedsDict["artists"] as? [[String: Any]] {
                for artist in artists {
                    if let seedId = artist["seedId"] as? String,
                       let artistName = artist["artistName"] as? String {
                        seedList.append(Seed(
                            id: seedId,
                            seedId: seedId,
                            name: artistName,
                            artist: nil,
                            type: .artist
                        ))
                    }
                }
            }
            
            // Song seeds
            if let songs = seedsDict["songs"] as? [[String: Any]] {
                for song in songs {
                    if let seedId = song["seedId"] as? String,
                       let songName = song["songName"] as? String,
                       let artistName = song["artistName"] as? String {
                        seedList.append(Seed(
                            id: seedId,
                            seedId: seedId,
                            name: songName,
                            artist: artistName,
                            type: .song
                        ))
                    }
                }
            }
        }
        
        seeds = seedList
    }
    
    private func parseFeedback(_ userInfo: [String: Any]) {
        var likesList: [FeedbackItem] = []
        var dislikesList: [FeedbackItem] = []
        
        // Likes
        if let likesArray = userInfo["likes"] as? [[String: Any]] {
            for like in likesArray {
                if let feedbackId = like["feedbackId"] as? String,
                   let songName = like["songName"] as? String,
                   let artistName = like["artistName"] as? String {
                    likesList.append(FeedbackItem(
                        id: feedbackId,
                        feedbackId: feedbackId,
                        name: songName,
                        artist: artistName,
                        isPositive: true
                    ))
                }
            }
        }
        
        // Dislikes
        if let dislikesArray = userInfo["dislikes"] as? [[String: Any]] {
            for dislike in dislikesArray {
                if let feedbackId = dislike["feedbackId"] as? String,
                   let songName = dislike["songName"] as? String,
                   let artistName = dislike["artistName"] as? String {
                    dislikesList.append(FeedbackItem(
                        id: feedbackId,
                        feedbackId: feedbackId,
                        name: songName,
                        artist: artistName,
                        isPositive: false
                    ))
                }
            }
        }
        
        likes = likesList
        dislikes = dislikesList
    }
    
    // MARK: - Rename Station
    
    func renameStation(to newName: String) {
        guard !newName.isEmpty, newName != stationName else { return }
        isSaving = true
        pandora.renameStation(station.token, to: newName)
    }
    
    private func handleStationRenamed() {
        isSaving = false
        // Station name will be updated via the notification
        loadStationDetails()
    }
    
    // MARK: - Seed Search
    
    private func setupSeedSearchDebounce() {
        $seedSearchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .sink { [weak self] query in
                self?.searchSeeds(query)
            }
            .store(in: &cancellables)
    }
    
    func searchSeeds(_ query: String) {
        isSearchingSeeds = true
        seedSearchResults = []
        pandora.search(query)
    }
    
    private func handleSeedSearchResults(_ notification: Notification) {
        isSearchingSeeds = false
        
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        
        var results: [SeedSearchResult] = []
        
        // Parse artists
        if let artists = userInfo["Artists"] as? [PandoraSearchResult] {
            for artist in artists {
                let artistName = artist.name
                guard !artistName.isEmpty else { continue }
                results.append(SeedSearchResult(
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
                let components = songFullName.components(separatedBy: " - ")
                let artistName = components.first ?? ""
                let songName = components.count > 1 ? components.dropFirst().joined(separator: " - ") : songFullName
                
                results.append(SeedSearchResult(
                    id: UUID().uuidString,
                    musicToken: song.value,
                    name: songName,
                    artist: artistName,
                    type: .song
                ))
            }
        }
        
        seedSearchResults = results
    }
    
    // MARK: - Seed Management
    
    func addSeed(_ result: SeedSearchResult) {
        pandora.addSeed(result.musicToken, to: station)
        seedSearchQuery = ""
        seedSearchResults = []
    }
    
    private func handleSeedAdded(_ notification: Notification) {
        // Reload station info to get updated seeds
        loadStationDetails()
    }
    
    func deleteSeed(_ seed: Seed) {
        pandora.removeSeed(seed.seedId)
    }
    
    private func handleSeedDeleted() {
        // Reload station info to get updated seeds
        loadStationDetails()
    }
    
    // MARK: - Feedback Management
    
    func deleteFeedback(_ item: FeedbackItem) {
        pandora.deleteFeedback(item.feedbackId)
    }
    
    private func handleFeedbackDeleted(_ notification: Notification) {
        guard let feedbackId = notification.object as? String else { return }
        likes.removeAll { $0.feedbackId == feedbackId }
        dislikes.removeAll { $0.feedbackId == feedbackId }
    }
    
    // MARK: - External Links
    
    func openInPandora() {
        guard let url = URL(string: stationURL), !stationURL.isEmpty else { return }
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ notification: Notification) {
        isSearchingSeeds = false
        isLoading = false
        isSaving = false
        
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

struct Seed: Identifiable {
    let id: String
    let seedId: String
    let name: String
    let artist: String?
    let type: SeedType
    
    enum SeedType: String {
        case artist, song
    }
}

struct SeedSearchResult: Identifiable {
    let id: String
    let musicToken: String
    let name: String
    let artist: String?
    let type: Seed.SeedType
}

struct FeedbackItem: Identifiable {
    let id: String
    let feedbackId: String
    let name: String
    let artist: String
    let isPositive: Bool
}
