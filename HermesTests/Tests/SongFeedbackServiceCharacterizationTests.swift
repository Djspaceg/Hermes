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
        #expect(Station.station(forToken: station.token) === station)
        #expect(song.station() === station)
        #expect(Station.responds(to: NSSelectorFromString("stationForToken:")))
        #expect(Station.instancesRespond(to: NSSelectorFromString("initForToken:")))
        #expect(Song.instancesRespond(to: NSSelectorFromString("station")))

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

        song.rating = 1
        controller.rate(song, as: true)

        #expect(
            !mockPandora.calls.contains {
                $0.method == .deleteRating(songToken: "shared-song-token")
            },
            "A shared-station song must be rejected before deleteRating is called."
        )
        #expect(mockPandora.calls.isEmpty)
    }

    @Test("unresolved history song retains feedback behavior")
    func unresolvedHistorySongRetainsFeedbackBehavior() {
        let mockPandora = MockPandora()
        let service = SongFeedbackService(pandoraProvider: { mockPandora })
        let song = Song()
        song.token = "history-song-token"
        song.stationId = "legacy-station-id"

        _ = service.rate(song, as: true, songIsPlaying: false)

        #expect(
            mockPandora.calls.contains {
                $0.method == .rateSong(songToken: "history-song-token", liked: true)
            }
        )

        song.rating = 1
        _ = service.rate(song, as: true, songIsPlaying: false)

        #expect(
            mockPandora.calls.contains {
                $0.method == .deleteRating(songToken: "history-song-token")
            }
        )
    }

    @Test("active dislike requests one advance")
    func activeDislikeRequestsOneAdvance() {
        let mockPandora = MockPandora()
        let service = SongFeedbackService(pandoraProvider: { mockPandora })
        let song = Song()
        song.token = "active-song-token"

        let result = service.rate(song, as: false, songIsPlaying: true)

        switch result {
        case .rejectedSharedStation:
            Issue.record("An unresolved song must not be rejected as shared.")
        case .rated(let shouldSkipSong):
            #expect(shouldSkipSong)
        }

        #expect(
            mockPandora.calls.filter {
                $0.method == .rateSong(songToken: "active-song-token", liked: false)
            }.count == 1
        )
    }
}
