//
//  StationModel.swift
//  Hermes
//
//  SwiftUI-friendly wrapper for Station
//

import Foundation
import Combine

final class StationModel: ObservableObject, Identifiable, Hashable {
    let station: Station
    
    // Published properties that can change
    @Published var name: String
    @Published var isPlaying: Bool = false
    @Published var artworkURL: URL?
    
    var id: String { station.stationId }
    var token: String { station.token }
    var stationId: String { station.stationId }
    var created: Date { Date(timeIntervalSince1970: TimeInterval(station.created)) }
    var shared: Bool { station.shared }
    var allowRename: Bool { station.allowRename }
    var allowAddMusic: Bool { station.allowAddMusic }
    var isQuickMix: Bool { station.isQuickMix }
    var playingSong: Song? { station.playingSong }
    var genres: [String] { station.genres ?? [] }
    
    private var cancellables = Set<AnyCancellable>()
    
    init(station: Station) {
        self.station = station
        self.name = station.name
        // Initialize artworkURL from existing station data if available
        if let artUrl = station.artUrl, !artUrl.isEmpty {
            self.artworkURL = URL(string: artUrl)
        } else {
            self.artworkURL = nil
        }
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe artwork URL changes from StationArtworkLoader
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidLoadStationInfoNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo as? [String: Any],
                      let stationName = userInfo["name"] as? String,
                      stationName == self.station.name else {
                    return
                }
                
                // Update artwork URL when it becomes available
                if let artUrl = userInfo["art"] as? String {
                    self.artworkURL = URL(string: artUrl)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Hashable
    
    nonisolated static func == (lhs: StationModel, rhs: StationModel) -> Bool {
        lhs.stationId == rhs.stationId
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(stationId)
    }
}

// MARK: - Preview Helpers

extension StationModel {
    static func mock(
        name: String = "Today's Hits",
        token: String = "mock-token",
        stationId: String = "mock-id"
    ) -> StationModel {
        let station = Station()
        station.name = name
        station.token = token
        station.stationId = stationId
        station.created = UInt64(Date().timeIntervalSince1970)
        return StationModel(station: station)
    }
}
