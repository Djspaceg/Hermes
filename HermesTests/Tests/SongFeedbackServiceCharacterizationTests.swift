//
//  SongFeedbackServiceCharacterizationTests.swift
//  HermesTests
//

import Foundation
import Testing
@testable import Hermes

@MainActor
@Suite("Song Feedback Service Characterization", .serialized)
struct SongFeedbackServiceCharacterizationTests {
    @Test("sharedStationRejection")
    func sharedStationRejection() {
        let suiteName = "com.hermes.tests.song-feedback.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
            Station.clearAllStations()
        }

        Station.clearAllStations()
        let station = Station()
        station.token = "shared-station-token"
        station.stationId = "shared-station-id"
        station.shared = true
        Station.addStation(station)

        let song = Song()
        song.token = "shared-song-token"
        song.stationId = station.stationId
        song.stationToken = station.token

        let compatibilityLookup = Station(forToken: station.token)
        #expect(compatibilityLookup?.stationId == station.stationId)
        #expect(compatibilityLookup?.shared == true)
        #expect(song.station() === station)

        let mockPandora = MockPandora()
        let controller = PlaybackController(
            userDefaults: userDefaults,
            pandoraProvider: { mockPandora }
        )
        controller.rate(song, as: true)

        #expect(
            song.rating == 0,
            "A shared-station song must be rejected before rateSong mutates its local rating."
        )
        #expect(
            !mockPandora.calls.contains {
                $0.method == .rateSong(songToken: "shared-song-token", liked: true)
            },
            "A shared-station song must be rejected before rateSong is called."
        )
    }
}
