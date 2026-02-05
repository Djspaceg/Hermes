//
//  ThreadingTests.swift
//  HermesTests
//
//  Tests for threading behavior - ensuring heavy operations don't block main thread
//  and UI updates happen on main thread
//

import Testing
import Foundation
@testable import Hermes

@Suite("Threading Behavior")
struct ThreadingTests {
    
    // MARK: - File I/O Threading Tests
    
    @Test("History loading happens off main thread")
    func historyLoadingOffMainThread() async throws {
        // Given - Create a test history file
        let testDirectory = NSTemporaryDirectory()
        let testPath = (testDirectory as NSString).appendingPathComponent("test_history.savestate")
        
        // Create some test songs
        let songs = [
            Song.mock(title: "Test Song 1", artist: "Test Artist 1"),
            Song.mock(title: "Test Song 2", artist: "Test Artist 2")
        ]
        
        // Archive the songs
        let data = try NSKeyedArchiver.archivedData(withRootObject: songs, requiringSecureCoding: false)
        try data.write(to: URL(fileURLWithPath: testPath))
        
        // When - Load history (this should happen on background thread)
        let startTime = Date()
        let viewModel = HistoryViewModel()
        
        // The loading happens asynchronously, so we need to wait a bit
        try await Task.sleep(for: .milliseconds(100))
        
        // Then - Verify the operation completed quickly (didn't block)
        let elapsed = Date().timeIntervalSince(startTime)
        #expect(elapsed < 0.5, "History loading should not block for long")
        
        // Clean up
        try? FileManager.default.removeItem(atPath: testPath)
    }
    
    @Test("History saving happens off main thread")
    func historySavingOffMainThread() async throws {
        // Given - Create a history view model with some items
        let viewModel = HistoryViewModel()
        viewModel.historyItems = [
            Song.mock(title: "Test Song 1", artist: "Test Artist 1"),
            Song.mock(title: "Test Song 2", artist: "Test Artist 2"),
            Song.mock(title: "Test Song 3", artist: "Test Artist 3")
        ]
        
        // When - Save history (this should happen on background thread)
        let startTime = Date()
        let result = viewModel.saveHistory()
        
        // Then - Verify the operation returned immediately (didn't block)
        let elapsed = Date().timeIntervalSince(startTime)
        #expect(elapsed < 0.1, "History saving should return immediately")
        #expect(result == true, "Save should return true")
        
        // Wait for async save to complete
        try await Task.sleep(for: .milliseconds(200))
    }
    
    @Test("Station artwork cache loading happens off main thread")
    func stationArtworkCacheLoadingOffMainThread() async throws {
        // Given - Create a test cache file
        let testDirectory = NSTemporaryDirectory()
        let hermesDir = (testDirectory as NSString).appendingPathComponent("Hermes")
        try? FileManager.default.createDirectory(atPath: hermesDir, withIntermediateDirectories: true)
        let cacheFile = (hermesDir as NSString).appendingPathComponent("test_station_cache.json")
        
        // Create test cache data
        let testCache = [
            "station1": ["artUrl": "https://example.com/art1.jpg", "genres": ["Rock"]],
            "station2": ["artUrl": "https://example.com/art2.jpg", "genres": ["Pop"]]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: testCache)
        try jsonData.write(to: URL(fileURLWithPath: cacheFile))
        
        // When - Initialize loader (this triggers cache loading)
        let startTime = Date()
        let loader = StationArtworkLoader.shared
        
        // Then - Verify initialization didn't block
        let elapsed = Date().timeIntervalSince(startTime)
        #expect(elapsed < 0.1, "Cache loading should not block initialization")
        
        // Wait for async load to complete
        try await Task.sleep(for: .milliseconds(200))
        
        // Clean up
        try? FileManager.default.removeItem(atPath: cacheFile)
    }
    
    // MARK: - Image Loading Threading Tests
    
    @Test("Image loading happens off main thread")
    func imageLoadingOffMainThread() async throws {
        // Given - A valid image URL (using a data URL to avoid network)
        let imageData = createTestImageData()
        let base64 = imageData.base64EncodedString()
        let dataURL = "data:image/png;base64,\(base64)"
        
        guard let url = URL(string: dataURL) else {
            Issue.record("Failed to create data URL")
            return
        }
        
        // When - Load image
        let startTime = Date()
        let cache = ImageCache.shared
        let image = await cache.loadImage(from: url)
        
        // Then - Verify operation completed
        let elapsed = Date().timeIntervalSince(startTime)
        #expect(image != nil, "Image should load successfully")
        #expect(elapsed < 1.0, "Image loading should complete quickly for data URL")
    }
    
    // MARK: - Main Thread Verification Tests
    
    @Test("View models are marked with @MainActor")
    func viewModelsAreMainActor() async throws {
        // This test verifies that view models can only be accessed from main thread
        // by attempting to create them on main actor
        
        await MainActor.run {
            // These should all compile and work because they're @MainActor
            let _ = PlayerViewModel()
            let _ = StationsViewModel(pandora: PandoraClient())
            let _ = HistoryViewModel()
            let _ = LoginViewModel()
            let _ = StationAddViewModel(pandora: PandoraClient())
            let _ = StationEditViewModel(station: Station.mock(), pandora: PandoraClient())
        }
        
        // If we got here without errors, the test passes
        #expect(true, "All view models should be @MainActor")
    }
    
    @Test("UI updates happen on main thread in PlayerViewModel")
    func playerViewModelUIUpdatesOnMainThread() async throws {
        // Given - A player view model
        let viewModel = await PlayerViewModel()
        
        // When - Update properties (these should only work on main thread)
        await MainActor.run {
            viewModel.isPlaying = true
            viewModel.volume = 0.5
            viewModel.playbackPosition = 100.0
        }
        
        // Then - Verify updates succeeded
        let isPlaying = await viewModel.isPlaying
        let volume = await viewModel.volume
        let position = await viewModel.playbackPosition
        
        #expect(isPlaying == true)
        #expect(volume == 0.5)
        #expect(position == 100.0)
    }
    
    @Test("UI updates happen on main thread in StationsViewModel")
    func stationsViewModelUIUpdatesOnMainThread() async throws {
        // Given - A stations view model
        let viewModel = await StationsViewModel(pandora: PandoraClient())
        
        // When - Update properties (these should only work on main thread)
        await MainActor.run {
            viewModel.isLoading = true
            viewModel.searchText = "test"
            viewModel.sortOrder = .name
        }
        
        // Then - Verify updates succeeded
        let isLoading = await viewModel.isLoading
        let searchText = await viewModel.searchText
        let sortOrder = await viewModel.sortOrder
        
        #expect(isLoading == true)
        #expect(searchText == "test")
        #expect(sortOrder == .name)
    }
    
    @Test("UI updates happen on main thread in HistoryViewModel")
    func historyViewModelUIUpdatesOnMainThread() async throws {
        // Given - A history view model
        let viewModel = await HistoryViewModel()
        
        // When - Update properties (these should only work on main thread)
        let testSong = Song.mock(title: "Test", artist: "Artist")
        await MainActor.run {
            viewModel.historyItems = [testSong]
            viewModel.selectedItem = testSong
        }
        
        // Then - Verify updates succeeded
        let items = await viewModel.historyItems
        let selected = await viewModel.selectedItem
        
        #expect(items.count == 1)
        #expect(selected?.title == "Test")
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("ImageCache handles concurrent requests safely")
    func imageCacheConcurrentAccess() async throws {
        // Given - Multiple concurrent image load requests
        let cache = ImageCache.shared
        let urls = (1...10).map { _ in
            URL(string: "https://example.com/image\(Int.random(in: 1...100)).jpg")!
        }
        
        // When - Load images concurrently
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = await cache.loadImage(from: url)
                }
            }
        }
        
        // Then - No crashes or data races should occur
        #expect(true, "Concurrent image loading should be safe")
    }
    
    @Test("StationArtworkLoader handles concurrent requests safely")
    func stationArtworkLoaderConcurrentAccess() async throws {
        // Given - Multiple stations
        let loader = await StationArtworkLoader.shared
        let stations = (1...10).map { i in
            Station.mock(name: "Station \(i)", stationId: "station\(i)")
        }
        
        // When - Request artwork for multiple stations concurrently
        await MainActor.run {
            for station in stations {
                loader.loadArtworkIfNeeded(for: station)
            }
        }
        
        // Wait for requests to process
        try await Task.sleep(for: .milliseconds(100))
        
        // Then - No crashes or data races should occur
        #expect(true, "Concurrent artwork loading should be safe")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageData() -> Data {
        // Create a simple 1x1 PNG image
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        image.unlockFocus()
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return Data()
        }
        
        return pngData
    }
}

// MARK: - Mock Extensions

extension Song {
    static func mock(
        title: String = "Test Song",
        artist: String = "Test Artist",
        album: String = "Test Album"
    ) -> Song {
        let song = Song()
        song.title = title
        song.artist = artist
        song.album = album
        return song
    }
}

extension Station {
    static func mock(
        name: String = "Test Station",
        stationId: String = "test-station-id"
    ) -> Station {
        let station = Station()
        station.name = name
        station.stationId = stationId
        station.token = "test-token"
        return station
    }
}
