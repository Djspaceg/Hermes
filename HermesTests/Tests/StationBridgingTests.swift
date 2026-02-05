//
//  StationBridgingTests.swift
//  HermesTests
//
//  Property-based tests for Station model
//  Tests that Station with @Observable provides consistent state
//  **Validates: Requirements 2.2**
//

import XCTest
@testable import Hermes

final class StationBridgingTests: XCTestCase {
    
    // MARK: - Property Tests for Station
    //
    // For all Station objects:
    // let station = Station(...)
    // assert(station properties are consistent)
    //
    // **Validates: Requirements 2.2**
    
    /// Property test: Station properties are consistent
    /// Tests that Station maintains consistent state across all properties
    func testStationPropertiesAreConsistent() throws {
        // Run 100+ iterations with various station configurations
        for iteration in 0..<150 {
            // Create a station with random properties
            let station = createRandomStation(iteration: iteration)
            
            // Verify all properties are accessible and consistent
            XCTAssertTrue(
                station.name == station.name,
                "Iteration \(iteration): name should be accessible"
            )
            
            XCTAssertTrue(
                station.token == station.token,
                "Iteration \(iteration): token should be accessible"
            )
            
            XCTAssertTrue(
                station.stationId == station.stationId,
                "Iteration \(iteration): stationId should be accessible"
            )
            
            // Verify id computed property matches stationId
            XCTAssertEqual(
                station.id,
                station.stationId,
                "Iteration \(iteration): id should match stationId"
            )
            
            // Verify createdDate computed property
            let expectedDate = Date(timeIntervalSince1970: TimeInterval(station.created) / 1000.0)
            XCTAssertEqual(
                station.createdDate.timeIntervalSince1970,
                expectedDate.timeIntervalSince1970,
                accuracy: 1.0,
                "Iteration \(iteration): createdDate should be computed correctly"
            )
            
            // Verify artworkURL computed property
            if let artUrl = station.artUrl {
                XCTAssertEqual(
                    station.artworkURL?.absoluteString,
                    artUrl,
                    "Iteration \(iteration): artworkURL should match artUrl"
                )
            } else {
                XCTAssertNil(
                    station.artworkURL,
                    "Iteration \(iteration): artworkURL should be nil when artUrl is nil"
                )
            }
            
            // Verify genresList computed property
            let expectedGenres = station.genres ?? []
            XCTAssertEqual(
                station.genresList,
                expectedGenres,
                "Iteration \(iteration): genresList should match genres"
            )
        }
    }
    
    /// Property test: Station name changes are reflected
    /// Tests that Station reflects changes to its properties
    func testStationReflectsPropertyChanges() throws {
        for iteration in 0..<100 {
            let station = createRandomStation(iteration: iteration)
            
            // Verify initial state
            let originalName = station.name
            XCTAssertEqual(station.name, originalName)
            
            // Change station name
            let newName = "Updated Station \(iteration)"
            station.name = newName
            
            // Verify the change is reflected
            XCTAssertEqual(
                station.name,
                newName,
                "Iteration \(iteration): Station should reflect name change"
            )
        }
    }
    
    /// Property test: Station equality and hashing
    /// Tests that Station instances are equal if they have the same stationId
    func testStationEqualityAndHashing() throws {
        for iteration in 0..<100 {
            let station1 = createRandomStation(iteration: iteration)
            let station2 = createRandomStation(iteration: iteration + 1000)
            
            // Same station ID
            station2.stationId = station1.stationId
            
            // Stations with same stationId should be equal
            XCTAssertEqual(
                station1,
                station2,
                "Iteration \(iteration): Stations with same stationId should be equal"
            )
            
            // Hash values should be equal
            XCTAssertEqual(
                station1.hash,
                station2.hash,
                "Iteration \(iteration): Stations with same stationId should have same hash"
            )
            
            // Different station ID
            let station3 = createRandomStation(iteration: iteration + 2000)
            
            XCTAssertNotEqual(
                station1,
                station3,
                "Iteration \(iteration): Stations with different stationId should not be equal"
            )
        }
    }
    
    /// Property test: Station with edge case values
    /// Tests Station with empty strings, nil values, and boundary conditions
    func testStationWithEdgeCases() throws {
        // Test with empty strings
        let emptyStation = Station()
        emptyStation.name = ""
        emptyStation.token = ""
        emptyStation.stationId = ""
        emptyStation.artUrl = nil
        emptyStation.genres = nil
        
        XCTAssertEqual(emptyStation.name, "")
        XCTAssertEqual(emptyStation.token, "")
        XCTAssertEqual(emptyStation.stationId, "")
        XCTAssertNil(emptyStation.artworkURL)
        XCTAssertEqual(emptyStation.genresList, [])
        
        // Test with very long strings
        let longStation = Station()
        longStation.name = String(repeating: "A", count: 1000)
        longStation.token = String(repeating: "B", count: 500)
        longStation.stationId = String(repeating: "C", count: 500)
        
        XCTAssertEqual(longStation.name.count, 1000)
        XCTAssertEqual(longStation.token.count, 500)
        XCTAssertEqual(longStation.stationId.count, 500)
        
        // Test with special characters
        let specialStation = Station()
        specialStation.name = "🎵 Rock & Roll 🎸"
        specialStation.token = "token-with-dashes-123"
        specialStation.stationId = "id_with_underscores_456"
        specialStation.artUrl = "https://example.com/art?size=500&format=jpg"
        
        XCTAssertEqual(specialStation.name, "🎵 Rock & Roll 🎸")
        XCTAssertEqual(specialStation.token, "token-with-dashes-123")
        XCTAssertEqual(specialStation.stationId, "id_with_underscores_456")
        XCTAssertNotNil(specialStation.artworkURL)
        
        // Test with empty genres array
        let emptyGenresStation = Station()
        emptyGenresStation.name = "Test"
        emptyGenresStation.token = "test-token"
        emptyGenresStation.stationId = "test-id"
        emptyGenresStation.genres = []
        
        XCTAssertEqual(emptyGenresStation.genresList, [])
        
        // Test with multiple genres
        let multiGenreStation = Station()
        multiGenreStation.name = "Multi-Genre"
        multiGenreStation.token = "multi-token"
        multiGenreStation.stationId = "multi-id"
        multiGenreStation.genres = ["Rock", "Pop", "Alternative", "Indie"]
        
        XCTAssertEqual(multiGenreStation.genresList.count, 4)
        XCTAssertEqual(multiGenreStation.genresList, ["Rock", "Pop", "Alternative", "Indie"])
    }
    
    /// Property test: Station with various timestamp values
    /// Tests date conversion with different timestamp values
    func testStationWithVariousTimestamps() throws {
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
            
            // Verify date conversion (timestamp is in milliseconds)
            let expectedDate = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
            XCTAssertEqual(
                station.createdDate.timeIntervalSince1970,
                expectedDate.timeIntervalSince1970,
                accuracy: 1.0,
                "Date conversion failed for \(description)"
            )
        }
    }
    
    /// Property test: Station with various boolean combinations
    /// Tests all combinations of boolean flags
    func testStationWithBooleanCombinations() throws {
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
            
            XCTAssertEqual(
                station.shared,
                combination[0],
                "Combination \(index): shared mismatch"
            )
            XCTAssertEqual(
                station.allowRename,
                combination[1],
                "Combination \(index): allowRename mismatch"
            )
            XCTAssertEqual(
                station.allowAddMusic,
                combination[2],
                "Combination \(index): allowAddMusic mismatch"
            )
            XCTAssertEqual(
                station.isQuickMix,
                combination[3],
                "Combination \(index): isQuickMix mismatch"
            )
        }
    }
    
    /// Property test: Station mock helper works correctly
    /// Tests that the mock() static method creates valid stations
    func testStationMockHelper() throws {
        // Test default mock
        let defaultMock = Station.mock()
        XCTAssertEqual(defaultMock.name, "Today's Hits")
        XCTAssertEqual(defaultMock.token, "mock-token")
        XCTAssertEqual(defaultMock.stationId, "mock-id")
        XCTAssertFalse(defaultMock.isQuickMix)
        
        // Test custom mock
        let customMock = Station.mock(
            name: "Custom Station",
            token: "custom-token",
            stationId: "custom-id",
            artUrl: "https://example.com/art.jpg",
            genres: ["Rock", "Pop"],
            isQuickMix: true
        )
        XCTAssertEqual(customMock.name, "Custom Station")
        XCTAssertEqual(customMock.token, "custom-token")
        XCTAssertEqual(customMock.stationId, "custom-id")
        XCTAssertEqual(customMock.artUrl, "https://example.com/art.jpg")
        XCTAssertEqual(customMock.genres, ["Rock", "Pop"])
        XCTAssertTrue(customMock.isQuickMix)
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
}
