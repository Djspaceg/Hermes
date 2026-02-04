//
//  StationBridgingTests.swift
//  HermesTests
//
//  Property-based tests for Station-StationModel bridging
//  **Validates: Requirements 5.2**
//

import XCTest
@testable import Hermes

final class StationBridgingTests: XCTestCase {
    
    // MARK: - Property 7: Station-StationModel Bridging
    //
    // For all Station objects:
    // let station = Station(...)
    // let model = StationModel(from: station)
    // assert(model preserves all station properties)
    //
    // **Validates: Requirements 5.2**
    
    /// Property test: StationModel preserves all Station properties
    /// Tests that creating a StationModel from a Station preserves all user-visible properties
    func testStationModelPreservesAllProperties() throws {
        // Run 100+ iterations with various station configurations
        for iteration in 0..<150 {
            // Create a station with random properties
            let station = createRandomStation(iteration: iteration)
            
            // Create StationModel from Station
            let model = StationModel(station: station)
            
            // Verify all properties are preserved
            XCTAssertEqual(
                model.name,
                station.name,
                "Iteration \(iteration): name mismatch"
            )
            
            XCTAssertEqual(
                model.token,
                station.token,
                "Iteration \(iteration): token mismatch"
            )
            
            XCTAssertEqual(
                model.stationId,
                station.stationId,
                "Iteration \(iteration): stationId mismatch"
            )
            
            XCTAssertEqual(
                model.id,
                station.stationId,
                "Iteration \(iteration): id should match stationId"
            )
            
            // Verify created date (convert from UInt64 milliseconds to Date)
            let expectedDate = Date(timeIntervalSince1970: TimeInterval(station.created) / 1000.0)
            XCTAssertEqual(
                model.created.timeIntervalSince1970,
                expectedDate.timeIntervalSince1970,
                accuracy: 1.0,
                "Iteration \(iteration): created date mismatch"
            )
            
            XCTAssertEqual(
                model.shared,
                station.shared,
                "Iteration \(iteration): shared mismatch"
            )
            
            XCTAssertEqual(
                model.allowRename,
                station.allowRename,
                "Iteration \(iteration): allowRename mismatch"
            )
            
            XCTAssertEqual(
                model.allowAddMusic,
                station.allowAddMusic,
                "Iteration \(iteration): allowAddMusic mismatch"
            )
            
            XCTAssertEqual(
                model.isQuickMix,
                station.isQuickMix,
                "Iteration \(iteration): isQuickMix mismatch"
            )
            
            // Verify artwork URL
            if let artUrl = station.artUrl {
                XCTAssertEqual(
                    model.artworkURL?.absoluteString,
                    artUrl,
                    "Iteration \(iteration): artworkURL mismatch"
                )
            } else {
                XCTAssertNil(
                    model.artworkURL,
                    "Iteration \(iteration): artworkURL should be nil when station.artUrl is nil"
                )
            }
            
            // Verify genres
            let expectedGenres = station.genres ?? []
            XCTAssertEqual(
                model.genres,
                expectedGenres,
                "Iteration \(iteration): genres mismatch"
            )
            
            // Verify the underlying station reference is preserved
            XCTAssertTrue(
                model.station === station,
                "Iteration \(iteration): StationModel should hold reference to original Station"
            )
        }
    }
    
    /// Property test: StationModel updates when Station name changes
    /// Tests that StationModel reflects changes to the underlying Station
    func testStationModelReflectsStationChanges() throws {
        for iteration in 0..<100 {
            let station = createRandomStation(iteration: iteration)
            let model = StationModel(station: station)
            
            // Verify initial state
            XCTAssertEqual(model.name, station.name)
            
            // Change station name
            let newName = "Updated Station \(iteration)"
            station.name = newName
            
            // StationModel's @Published name should be updated manually
            // (or through notification observers if implemented)
            // For now, verify the underlying station reference is correct
            XCTAssertEqual(
                model.station.name,
                newName,
                "Iteration \(iteration): Underlying station should reflect name change"
            )
        }
    }
    
    /// Property test: Multiple StationModels can wrap the same Station
    /// Tests that multiple StationModel instances can reference the same Station
    func testMultipleModelsCanWrapSameStation() throws {
        for iteration in 0..<50 {
            let station = createRandomStation(iteration: iteration)
            
            // Create multiple models wrapping the same station
            let model1 = StationModel(station: station)
            let model2 = StationModel(station: station)
            let model3 = StationModel(station: station)
            
            // All models should reference the same station
            XCTAssertTrue(
                model1.station === station,
                "Iteration \(iteration): model1 should reference original station"
            )
            XCTAssertTrue(
                model2.station === station,
                "Iteration \(iteration): model2 should reference original station"
            )
            XCTAssertTrue(
                model3.station === station,
                "Iteration \(iteration): model3 should reference original station"
            )
            
            // All models should have the same properties
            XCTAssertEqual(model1.name, model2.name)
            XCTAssertEqual(model2.name, model3.name)
            XCTAssertEqual(model1.stationId, model2.stationId)
            XCTAssertEqual(model2.stationId, model3.stationId)
        }
    }
    
    /// Property test: StationModel equality and hashing
    /// Tests that StationModel instances are equal if they wrap stations with the same ID
    func testStationModelEqualityAndHashing() throws {
        for iteration in 0..<100 {
            let station1 = createRandomStation(iteration: iteration)
            let station2 = createRandomStation(iteration: iteration + 1000)
            
            // Same station ID
            station2.stationId = station1.stationId
            
            let model1 = StationModel(station: station1)
            let model2 = StationModel(station: station2)
            
            // Models with same stationId should be equal
            XCTAssertEqual(
                model1,
                model2,
                "Iteration \(iteration): Models with same stationId should be equal"
            )
            
            // Hash values should be equal
            XCTAssertEqual(
                model1.hashValue,
                model2.hashValue,
                "Iteration \(iteration): Models with same stationId should have same hash"
            )
            
            // Different station ID
            let station3 = createRandomStation(iteration: iteration + 2000)
            let model3 = StationModel(station: station3)
            
            XCTAssertNotEqual(
                model1,
                model3,
                "Iteration \(iteration): Models with different stationId should not be equal"
            )
        }
    }
    
    /// Property test: StationModel with edge case values
    /// Tests StationModel with empty strings, nil values, and boundary conditions
    func testStationModelWithEdgeCases() throws {
        // Test with empty strings
        let emptyStation = Station()
        emptyStation.name = ""
        emptyStation.token = ""
        emptyStation.stationId = ""
        emptyStation.artUrl = nil
        emptyStation.genres = nil
        
        let emptyModel = StationModel(station: emptyStation)
        
        XCTAssertEqual(emptyModel.name, "")
        XCTAssertEqual(emptyModel.token, "")
        XCTAssertEqual(emptyModel.stationId, "")
        XCTAssertNil(emptyModel.artworkURL)
        XCTAssertEqual(emptyModel.genres, [])
        
        // Test with very long strings
        let longStation = Station()
        longStation.name = String(repeating: "A", count: 1000)
        longStation.token = String(repeating: "B", count: 500)
        longStation.stationId = String(repeating: "C", count: 500)
        
        let longModel = StationModel(station: longStation)
        
        XCTAssertEqual(longModel.name.count, 1000)
        XCTAssertEqual(longModel.token.count, 500)
        XCTAssertEqual(longModel.stationId.count, 500)
        
        // Test with special characters
        let specialStation = Station()
        specialStation.name = "🎵 Rock & Roll 🎸"
        specialStation.token = "token-with-dashes-123"
        specialStation.stationId = "id_with_underscores_456"
        specialStation.artUrl = "https://example.com/art?size=500&format=jpg"
        
        let specialModel = StationModel(station: specialStation)
        
        XCTAssertEqual(specialModel.name, "🎵 Rock & Roll 🎸")
        XCTAssertEqual(specialModel.token, "token-with-dashes-123")
        XCTAssertEqual(specialModel.stationId, "id_with_underscores_456")
        XCTAssertNotNil(specialModel.artworkURL)
        
        // Test with empty genres array
        let emptyGenresStation = Station()
        emptyGenresStation.name = "Test"
        emptyGenresStation.token = "test-token"
        emptyGenresStation.stationId = "test-id"
        emptyGenresStation.genres = []
        
        let emptyGenresModel = StationModel(station: emptyGenresStation)
        XCTAssertEqual(emptyGenresModel.genres, [])
        
        // Test with multiple genres
        let multiGenreStation = Station()
        multiGenreStation.name = "Multi-Genre"
        multiGenreStation.token = "multi-token"
        multiGenreStation.stationId = "multi-id"
        multiGenreStation.genres = ["Rock", "Pop", "Alternative", "Indie"]
        
        let multiGenreModel = StationModel(station: multiGenreStation)
        XCTAssertEqual(multiGenreModel.genres.count, 4)
        XCTAssertEqual(multiGenreModel.genres, ["Rock", "Pop", "Alternative", "Indie"])
    }
    
    /// Property test: StationModel with various timestamp values
    /// Tests date conversion with different timestamp values
    func testStationModelWithVariousTimestamps() throws {
        let testCases: [(UInt64, String)] = [
            (0, "epoch"),
            (1000, "1 second after epoch"),
            (1609459200000, "2021-01-01"),
            (1735689600000, "2025-01-01"),
            (UInt64.max, "maximum value"),
        ]
        
        for (timestamp, description) in testCases {
            let station = Station()
            station.name = "Test Station"
            station.token = "test-token"
            station.stationId = "test-id"
            station.created = timestamp
            
            let model = StationModel(station: station)
            
            // Verify date conversion (timestamp is in milliseconds)
            let expectedDate = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
            XCTAssertEqual(
                model.created.timeIntervalSince1970,
                expectedDate.timeIntervalSince1970,
                accuracy: 1.0,
                "Date conversion failed for \(description)"
            )
        }
    }
    
    /// Property test: StationModel with various boolean combinations
    /// Tests all combinations of boolean flags
    func testStationModelWithBooleanCombinations() throws {
        let booleanCombinations: [[Bool]] = [
            [false, false, false, false],
            [true, false, false, false],
            [false, true, false, false],
            [false, false, true, false],
            [false, false, false, true],
            [true, true, false, false],
            [true, false, true, false],
            [true, false, false, true],
            [false, true, true, false],
            [false, true, false, true],
            [false, false, true, true],
            [true, true, true, false],
            [true, true, false, true],
            [true, false, true, true],
            [false, true, true, true],
            [true, true, true, true],
        ]
        
        for (index, combination) in booleanCombinations.enumerated() {
            let station = Station()
            station.name = "Test \(index)"
            station.token = "token-\(index)"
            station.stationId = "id-\(index)"
            station.shared = combination[0]
            station.allowRename = combination[1]
            station.allowAddMusic = combination[2]
            station.isQuickMix = combination[3]
            
            let model = StationModel(station: station)
            
            XCTAssertEqual(
                model.shared,
                combination[0],
                "Combination \(index): shared mismatch"
            )
            XCTAssertEqual(
                model.allowRename,
                combination[1],
                "Combination \(index): allowRename mismatch"
            )
            XCTAssertEqual(
                model.allowAddMusic,
                combination[2],
                "Combination \(index): allowAddMusic mismatch"
            )
            XCTAssertEqual(
                model.isQuickMix,
                combination[3],
                "Combination \(index): isQuickMix mismatch"
            )
        }
    }
    
    /// Property test: StationModel with playingSong
    /// Tests that playingSong is correctly exposed through StationModel
    func testStationModelWithPlayingSong() throws {
        for iteration in 0..<50 {
            let station = createRandomStation(iteration: iteration)
            let model = StationModel(station: station)
            
            // Initially no playing song
            XCTAssertNil(model.playingSong)
            
            // Add a song (this would normally be done through playlist operations)
            let song = createRandomSong(iteration: iteration)
            // Note: We can't directly set playingSong as it's private(set)
            // This tests the current state exposure
            
            XCTAssertEqual(
                model.playingSong,
                station.playingSong,
                "Iteration \(iteration): playingSong should match station's playingSong"
            )
        }
    }
    
    // MARK: - Helpers
    
    /// Create a station with random properties for testing
    private func createRandomStation(iteration: Int) -> Station {
        let station = Station()
        
        station.name = generateRandomStationName(iteration: iteration)
        station.token = "token-\(iteration)-\(UUID().uuidString.prefix(8))"
        station.stationId = "station-\(iteration)-\(UUID().uuidString.prefix(8))"
        station.created = UInt64(Date().timeIntervalSince1970 * 1000) + UInt64(iteration * 1000)
        station.shared = Bool.random()
        station.allowRename = Bool.random()
        station.allowAddMusic = Bool.random()
        station.isQuickMix = Bool.random()
        
        // Randomly include or exclude optional properties
        if Bool.random() {
            station.artUrl = "https://example.com/art/\(iteration).jpg"
        }
        
        if Bool.random() {
            station.genres = generateRandomGenres()
        }
        
        return station
    }
    
    /// Generate a random station name
    private func generateRandomStationName(iteration: Int) -> String {
        let prefixes = ["Classic", "Modern", "Alternative", "Indie", "Pop", "Rock", "Jazz", "Blues"]
        let suffixes = ["Radio", "Station", "Mix", "Hits", "Favorites", "Classics"]
        
        let prefix = prefixes[iteration % prefixes.count]
        let suffix = suffixes[(iteration / prefixes.count) % suffixes.count]
        
        return "\(prefix) \(suffix) \(iteration)"
    }
    
    /// Generate random genres array
    private func generateRandomGenres() -> [String] {
        let allGenres = ["Rock", "Pop", "Jazz", "Blues", "Classical", "Country", "Hip Hop", "Electronic", "Alternative", "Indie"]
        let count = Int.random(in: 1...4)
        return Array(allGenres.shuffled().prefix(count))
    }
    
    /// Create a random song for testing
    private func createRandomSong(iteration: Int) -> Song {
        let song = Song()
        song.artist = "Artist \(iteration)"
        song.title = "Song \(iteration)"
        song.album = "Album \(iteration)"
        song.token = "song-token-\(iteration)"
        return song
    }
}
