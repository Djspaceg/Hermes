//
//  StationModel.swift
//  Hermes
//
//  Swift wrapper for Objective-C Station class
//

import Foundation

final class StationModel: ObservableObject, Identifiable, Hashable {
    let objcStation: Station
    
    var id: String { objcStation.stationId }
    @Published var name: String
    var isQuickMix: Bool { objcStation.isQuickMix }
    var created: Date { Date(timeIntervalSince1970: TimeInterval(objcStation.created)) }
    
    init(station: Station) {
        self.objcStation = station
        self.name = station.name
    }
    
    static func == (lhs: StationModel, rhs: StationModel) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Preview Helpers

extension StationModel {
    /// Creates a mock StationModel for SwiftUI previews
    static func mock(
        name: String = "Rock Classics",
        stationId: String = UUID().uuidString,
        isQuickMix: Bool = false
    ) -> StationModel {
        let station = Station()
        station.stationId = stationId
        station.name = name
        station.isQuickMix = isQuickMix
        station.created = UInt64(Date().timeIntervalSince1970)
        return StationModel(station: station)
    }
}
