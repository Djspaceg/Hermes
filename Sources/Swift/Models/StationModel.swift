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
    
    var id: String { station.stationId }
    var token: String { station.token }
    var stationId: String { station.stationId }
    var created: Date { Date(timeIntervalSince1970: TimeInterval(station.created)) }
    var shared: Bool { station.shared }
    var allowRename: Bool { station.allowRename }
    var allowAddMusic: Bool { station.allowAddMusic }
    var isQuickMix: Bool { station.isQuickMix }
    var playingSong: Song? { station.playingSong }
    
    private var cancellables = Set<AnyCancellable>()
    
    init(station: Station) {
        self.station = station
        self.name = station.name
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe station name changes
        // Note: If Station properties become observable in the future, add observers here
    }
    
    // MARK: - Hashable
    
    nonisolated static func == (lhs: StationModel, rhs: StationModel) -> Bool {
        lhs.station === rhs.station
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(station))
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
