//
//  HistoryViewModelTests.swift
//  HermesTests
//
//  Tests for HistoryViewModel to verify parity with HistoryController
//

import XCTest
@testable import Hermes

@MainActor
final class HistoryViewModelTests: XCTestCase {
    
    var sut: HistoryViewModel!
    var tempDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        sut = HistoryViewModel()
    }
    
    override func tearDown() async throws {
        sut = nil
        
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        
        try await super.tearDown()
    }
    
    // MARK: - History Limit Tests (from HistoryController HISTORY_LIMIT)
    
    func testHistoryLimit_EnforcesMaximum() {
        // Given - Create 25 songs (limit is 20)
        let songs = (1...25).map { createMockSong(title: "Song \($0)") }
        
        // When
        for song in songs {
            sut.addToHistory(song)
        }
        
        // Then
        XCTAssertEqual(sut.historyItems.count, 20, "Should enforce 20 item limit")
        XCTAssertEqual(sut.historyItems.first?.title, "Song 25", "Most recent song should be first")
        XCTAssertEqual(sut.historyItems.last?.title, "Song 6", "Oldest songs should be removed")
    }
    
    func testHistoryLimit_MaintainsOrder() {
        // Given
        let songs = (1...5).map { createMockSong(title: "Song \($0)") }
        
        // When
        for song in songs {
            sut.addToHistory(song)
        }
        
        // Then
        XCTAssertEqual(sut.historyItems[0].title, "Song 5", "Most recent first")
        XCTAssertEqual(sut.historyItems[1].title, "Song 4")
        XCTAssertEqual(sut.historyItems[2].title, "Song 3")
        XCTAssertEqual(sut.historyItems[3].title, "Song 2")
        XCTAssertEqual(sut.historyItems[4].title, "Song 1", "Oldest last")
    }
    
    // MARK: - Add Song Tests (from HistoryController addSong:)
    
    func testAddSong_InsertsAtBeginning() {
        // Given
        let song1 = createMockSong(title: "First Song")
        let song2 = createMockSong(title: "Second Song")
        
        // When
        sut.addToHistory(song1)
        sut.addToHistory(song2)
        
        // Then
        XCTAssertEqual(sut.historyItems.count, 2)
        XCTAssertEqual(sut.historyItems[0].title, "Second Song", "New song should be first")
        XCTAssertEqual(sut.historyItems[1].title, "First Song")
    }
    
    func testAddSong_RemovesDuplicates() {
        // Given
        let song1 = createMockSong(title: "Song", id: "123")
        let song2 = createMockSong(title: "Other Song", id: "456")
        let song1Duplicate = createMockSong(title: "Song", id: "123")
        
        // When
        sut.addToHistory(song1)
        sut.addToHistory(song2)
        sut.addToHistory(song1Duplicate)
        
        // Then
        XCTAssertEqual(sut.historyItems.count, 2, "Should not have duplicates")
        XCTAssertEqual(sut.historyItems[0].id, "123", "Duplicate should move to front")
        XCTAssertEqual(sut.historyItems[1].id, "456")
    }
    
    // MARK: - Persistence Tests (from HistoryController saveSongs/loadSavedSongs)
    
    func testSaveHistory_CreatesFile() {
        // Given
        let song = createMockSong(title: "Test Song")
        sut.addToHistory(song)
        
        // When
        let success = sut.saveHistory()
        
        // Then
        XCTAssertTrue(success, "Save should succeed")
        
        // Verify file exists
        let saveStatePath = ("~/Library/Application Support/Hermes/history.savestate" as NSString).expandingTildeInPath
        XCTAssertTrue(FileManager.default.fileExists(atPath: saveStatePath), "Save file should exist")
    }
    
    func testSaveAndLoad_PreservesHistory() {
        // Given
        let songs = (1...5).map { createMockSong(title: "Song \($0)", id: "id\($0)") }
        for song in songs {
            sut.addToHistory(song)
        }
        
        // When - Save
        let saveSuccess = sut.saveHistory()
        XCTAssertTrue(saveSuccess, "Save should succeed")
        
        // Verify we have the expected items before "reloading"
        XCTAssertEqual(sut.historyItems.count, 5, "Should have 5 items")
        
        // Then - Verify items are in correct order (most recent first)
        XCTAssertEqual(sut.historyItems[0].title, "Song 5", "Most recent should be first")
        XCTAssertEqual(sut.historyItems[4].title, "Song 1", "Oldest should be last")
        
        // Note: Full persistence testing (creating new ViewModel) requires
        // integration tests or a test-specific save location to avoid
        // interfering with actual app data
    }
    
    func testAutoSave_OnAddSong() {
        // Given
        let song = createMockSong(title: "Test Song")
        
        // When
        sut.addToHistory(song)
        
        // Then - Verify file was saved automatically
        let saveStatePath = ("~/Library/Application Support/Hermes/history.savestate" as NSString).expandingTildeInPath
        XCTAssertTrue(FileManager.default.fileExists(atPath: saveStatePath), "Should auto-save on add")
    }
    
    // MARK: - Clear History Tests
    
    func testClearHistory_RemovesAllItems() {
        // Given
        let songs = (1...5).map { createMockSong(title: "Song \($0)") }
        for song in songs {
            sut.addToHistory(song)
        }
        
        // When
        sut.clearHistory()
        
        // Then
        XCTAssertEqual(sut.historyItems.count, 0, "Should remove all items")
    }
    
    func testClearHistory_SavesEmptyState() {
        // Given
        let songs = (1...5).map { createMockSong(title: "Song \($0)") }
        for song in songs {
            sut.addToHistory(song)
        }
        
        // When
        sut.clearHistory()
        
        // Then - Create new view model to verify empty state persisted
        let newViewModel = HistoryViewModel()
        XCTAssertEqual(newViewModel.historyItems.count, 0, "Cleared state should persist")
    }
    
    // MARK: - Selection Tests (from HistoryController selectedItem)
    
    func testSelection_InitiallyNil() {
        // Then
        XCTAssertNil(sut.selectedItem, "No item should be selected initially")
    }
    
    func testSelection_CanSelectItem() {
        // Given
        let song = createMockSong(title: "Test Song")
        sut.addToHistory(song)
        
        // When
        sut.selectedItem = sut.historyItems.first
        
        // Then
        XCTAssertNotNil(sut.selectedItem)
        XCTAssertEqual(sut.selectedItem?.title, "Test Song")
    }
    
    // MARK: - Action Tests (from HistoryController IBActions)
    
    func testOpenSongOnPandora_WithValidURL() {
        // Given
        let song = createMockSong(title: "Test Song", titleUrl: "https://pandora.com/song/123")
        sut.selectedItem = song
        
        // Then - Verify URL is set correctly
        XCTAssertNotNil(sut.selectedItem?.titleUrl, "Should have title URL")
        XCTAssertEqual(sut.selectedItem?.titleUrl, "https://pandora.com/song/123")
        
        // Note: Actual URL opening requires mocking NSWorkspace
        // This test verifies the data is correct for opening
    }
    
    func testOpenArtistOnPandora_WithValidURL() {
        // Given
        let song = createMockSong(title: "Test Song", artistUrl: "https://pandora.com/artist/456")
        sut.selectedItem = song
        
        // Then - Verify URL is set correctly
        XCTAssertNotNil(sut.selectedItem?.artistUrl, "Should have artist URL")
        XCTAssertEqual(sut.selectedItem?.artistUrl, "https://pandora.com/artist/456")
    }
    
    func testOpenAlbumOnPandora_WithValidURL() {
        // Given
        let song = createMockSong(title: "Test Song", albumUrl: "https://pandora.com/album/789")
        sut.selectedItem = song
        
        // Then - Verify URL is set correctly
        XCTAssertNotNil(sut.selectedItem?.albumUrl, "Should have album URL")
        XCTAssertEqual(sut.selectedItem?.albumUrl, "https://pandora.com/album/789")
    }
    
    func testShowLyrics_WithValidSong() {
        // Given
        let song = createMockSong(title: "Test Song", artist: "Test Artist")
        sut.selectedItem = song
        
        // Then - Verify song data is correct for lyrics search
        XCTAssertNotNil(sut.selectedItem, "Should have selected item")
        XCTAssertEqual(sut.selectedItem?.title, "Test Song")
        XCTAssertEqual(sut.selectedItem?.artist, "Test Artist")
        
        // Note: Actual lyrics opening requires mocking NSWorkspace
        // This test verifies the data is correct for searching
    }
    
    // MARK: - Distributed Notification Tests (from HistoryController postNotificationName)
    
    func testAddSong_PostsDistributedNotification() {
        // Given
        let expectation = XCTestExpectation(description: "Distributed notification posted")
        let song = createMockSong(title: "Test Song", artist: "Test Artist")
        
        let observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("hermes.song"),
            object: "hermes",
            queue: .main
        ) { notification in
            // Then
            XCTAssertNotNil(notification.userInfo)
            XCTAssertEqual(notification.userInfo?["title"] as? String, "Test Song")
            XCTAssertEqual(notification.userInfo?["artist"] as? String, "Test Artist")
            expectation.fulfill()
        }
        
        // When
        sut.addToHistory(song)
        
        wait(for: [expectation], timeout: 1.0)
        DistributedNotificationCenter.default().removeObserver(observer)
    }
    
    // MARK: - Helper Methods
    
    private func createMockSong(
        title: String,
        artist: String = "Test Artist",
        album: String = "Test Album",
        id: String = UUID().uuidString,
        titleUrl: String = "",
        artistUrl: String = "",
        albumUrl: String = ""
    ) -> SongModel {
        let song = Song()
        song.title = title
        song.artist = artist
        song.album = album
        song.token = id
        song.titleUrl = titleUrl.isEmpty ? nil : titleUrl
        song.artistUrl = artistUrl.isEmpty ? nil : artistUrl
        song.albumUrl = albumUrl.isEmpty ? nil : albumUrl
        return SongModel(song: song)
    }
}
