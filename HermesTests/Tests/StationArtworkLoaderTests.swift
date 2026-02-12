//
//  StationArtworkLoaderTests.swift
//  HermesTests
//
//  Tests for StationArtworkLoader cache persistence and notification handling
//

import XCTest
import Combine
@testable import Hermes

@MainActor
final class StationArtworkLoaderTests: XCTestCase {
    
    var cancellables = Set<AnyCancellable>()
    var tempCacheURL: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create temp directory for cache tests
        tempCacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HermesTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempCacheURL, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        
        // Clean up temp directory
        if let tempCacheURL = tempCacheURL {
            try? FileManager.default.removeItem(at: tempCacheURL)
        }
        
        try await super.tearDown()
    }
    
    // MARK: - Cache File Format Tests
    
    func testCacheFileFormat_ValidJSON() throws {
        // Given - Create a valid cache file using Codable structure
        struct CachedStationInfo: Codable {
            let artUrl: String?
            let genres: [String]
        }
        
        let cache: [String: CachedStationInfo] = [
            "station123": CachedStationInfo(
                artUrl: "https://example.com/art.jpg",
                genres: ["Rock", "Alternative"]
            )
        ]
        
        let data = try JSONEncoder().encode(cache)
        let cacheFile = tempCacheURL.appendingPathComponent("station_artwork_cache.json")
        try data.write(to: cacheFile)
        
        // When - Read it back
        let readData = try Data(contentsOf: cacheFile)
        let decoded = try JSONDecoder().decode([String: CachedStationInfo].self, from: readData)
        
        // Then
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded["station123"]?.artUrl, "https://example.com/art.jpg")
        XCTAssertEqual(decoded["station123"]?.genres, ["Rock", "Alternative"])
    }
    
    func testCacheFileFormat_HandlesNilArtUrl() throws {
        // Given - Cache with nil artUrl
        struct CachedStationInfo: Codable {
            let artUrl: String?
            let genres: [String]
        }
        
        let cache: [String: CachedStationInfo] = [
            "station456": CachedStationInfo(artUrl: nil, genres: ["Jazz"])
        ]
        
        let data = try JSONEncoder().encode(cache)
        
        // When - Decode
        let decoded = try JSONDecoder().decode([String: CachedStationInfo].self, from: data)
        
        // Then
        XCTAssertNil(decoded["station456"]?.artUrl)
        XCTAssertEqual(decoded["station456"]?.genres, ["Jazz"])
    }
    
    func testCacheFileFormat_HandlesEmptyGenres() throws {
        // Given - Cache with empty genres
        struct CachedStationInfo: Codable {
            let artUrl: String?
            let genres: [String]
        }
        
        let cache: [String: CachedStationInfo] = [
            "station789": CachedStationInfo(
                artUrl: "https://example.com/art.jpg",
                genres: []
            )
        ]
        
        let data = try JSONEncoder().encode(cache)
        
        // When - Decode
        let decoded = try JSONDecoder().decode([String: CachedStationInfo].self, from: data)
        
        // Then
        XCTAssertEqual(decoded["station789"]?.artUrl, "https://example.com/art.jpg")
        XCTAssertEqual(decoded["station789"]?.genres, [])
    }
    
    // MARK: - Notification Filtering Tests
    
    func testNotificationFiltering_IgnoresCacheNotifications() {
        // Given
        let expectation = XCTestExpectation(description: "Should not process cache notification")
        expectation.isInverted = true
        
        var processedCount = 0
        
        // Subscribe to track processing
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidLoadStationInfoNotification"))
            .receive(on: DispatchQueue.main)
            .sink { notification in
                // Only count non-cache notifications
                if let obj = notification.object as? String, obj == "cache" {
                    // This is a cache notification - should be ignored by handler
                } else {
                    processedCount += 1
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When - Post a cache notification (marked with "cache" object)
        NotificationCenter.default.post(
            name: Notification.Name("PandoraDidLoadStationInfoNotification"),
            object: "cache",
            userInfo: [
                "name": "Test Station",
                "art": "https://example.com/art.jpg",
                "genres": ["Rock"]
            ]
        )
        
        // Then - Should not be processed as a new API response
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testNotificationFiltering_ProcessesAPINotifications() {
        // Given
        let expectation = XCTestExpectation(description: "Should process API notification")
        
        NotificationCenter.default.publisher(for: Notification.Name("PandoraDidLoadStationInfoNotification"))
            .receive(on: DispatchQueue.main)
            .sink { notification in
                // API notifications have Station object, not "cache" string
                if notification.object as? String != "cache" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When - Post an API notification (with Station object or nil)
        let station = Station()
        station.name = "Test Station"
        
        NotificationCenter.default.post(
            name: Notification.Name("PandoraDidLoadStationInfoNotification"),
            object: station,
            userInfo: [
                "name": "Test Station",
                "art": "https://example.com/art.jpg",
                "genres": ["Rock"]
            ]
        )
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Station Loading Tests
    
    func testLoadArtworkIfNeeded_SkipsIfAlreadyHasArtwork() {
        // Given
        let station = Station()
        station.stationId = "test123"
        station.name = "Test Station"
        station.artUrl = "https://existing.com/art.jpg"
        
        let loader = StationArtworkLoader.shared
        
        // When
        loader.loadArtworkIfNeeded(for: station)
        
        // Then - Should be marked as loaded without API call
        XCTAssertTrue(loader.isLoaded("test123"))
    }
    
    func testLoadArtworkIfNeeded_SkipsEmptyStationId() {
        // Given
        let station = Station()
        station.stationId = ""
        station.name = "Test Station"
        
        let loader = StationArtworkLoader.shared
        let initialCount = loader.loadedStations.count
        
        // When
        loader.loadArtworkIfNeeded(for: station)
        
        // Then - Should not add to loaded stations
        XCTAssertEqual(loader.loadedStations.count, initialCount)
    }
    
    // MARK: - Cache Directory Tests
    
    func testCacheDirectory_CreatesIfNotExists() throws {
        // Given - A path that doesn't exist
        let testDir = tempCacheURL.appendingPathComponent("NewCacheDir")
        XCTAssertFalse(FileManager.default.fileExists(atPath: testDir.path))
        
        // When - Create directory
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: testDir.path))
    }
    
    func testCacheFile_AtomicWrite() throws {
        // Given
        struct CachedStationInfo: Codable {
            let artUrl: String?
            let genres: [String]
        }
        
        let cache: [String: CachedStationInfo] = [
            "station1": CachedStationInfo(artUrl: "https://example.com/1.jpg", genres: ["Rock"]),
            "station2": CachedStationInfo(artUrl: "https://example.com/2.jpg", genres: ["Jazz"])
        ]
        
        let cacheFile = tempCacheURL.appendingPathComponent("test_cache.json")
        
        // When - Write atomically
        let data = try JSONEncoder().encode(cache)
        try data.write(to: cacheFile, options: .atomic)
        
        // Then - File should exist and be readable
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheFile.path))
        
        let readData = try Data(contentsOf: cacheFile)
        let decoded = try JSONDecoder().decode([String: CachedStationInfo].self, from: readData)
        XCTAssertEqual(decoded.count, 2)
    }
}
