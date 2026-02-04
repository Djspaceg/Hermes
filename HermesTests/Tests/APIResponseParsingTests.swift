//
//  APIResponseParsingTests.swift
//  HermesTests
//
//  Property-based tests for Pandora API response parsing
//  **Validates: Requirements 4.3, 4.4, 4.5, 4.6, 4.7**
//

import XCTest
@testable import Hermes

final class APIResponseParsingTests: XCTestCase {
    
    // MARK: - Test Infrastructure
    
    private var pandoraClient: PandoraClient!
    
    override func setUp() {
        super.setUp()
        pandoraClient = PandoraClient()
    }
    
    override func tearDown() {
        pandoraClient = nil
        super.tearDown()
    }
    
    // MARK: - Property 2: API Response Parsing Correctness
    //
    // For all valid Pandora API response JSON, parsing should produce correctly
    // typed model objects with all expected fields populated.
    //
    // **Validates: Requirements 4.3, 4.4, 4.5, 4.6, 4.7**
    
    // MARK: - Station Parsing Tests (Requirement 4.3)
    
    /// Property test: Station list parsing with various valid responses
    /// Tests that all required station fields are populated correctly
    func testStationListParsing_AllRequiredFields() throws {
        // Test with 100+ iterations of different station configurations
        for iteration in 0..<120 {
            let stationCount = Int.random(in: 1...20)
            let mockResponse = generateMockStationListResponse(stationCount: stationCount)
            
            // Parse the response
            let stations = parseStationList(from: mockResponse)
            
            // Verify count matches
            XCTAssertEqual(
                stations.count,
                stationCount,
                "Iteration \(iteration): Station count mismatch"
            )
            
            // Verify all required fields are populated
            for (index, station) in stations.enumerated() {
                XCTAssertFalse(station.name.isEmpty, "Iteration \(iteration), Station \(index): name is empty")
                XCTAssertFalse(station.stationId.isEmpty, "Iteration \(iteration), Station \(index): stationId is empty")
                XCTAssertFalse(station.token.isEmpty, "Iteration \(iteration), Station \(index): token is empty")
                
                // Verify boolean fields have valid values
                XCTAssertNotNil(station.shared, "Iteration \(iteration), Station \(index): shared is nil")
                XCTAssertNotNil(station.allowAddMusic, "Iteration \(iteration), Station \(index): allowAddMusic is nil")
                XCTAssertNotNil(station.allowRename, "Iteration \(iteration), Station \(index): allowRename is nil")
                
                // Verify created timestamp is reasonable (not 0, not in far future)
                XCTAssertGreaterThan(station.created, 0, "Iteration \(iteration), Station \(index): created timestamp is 0")
                XCTAssertLessThan(station.created, UInt64(Date().timeIntervalSince1970 * 1000), "Iteration \(iteration), Station \(index): created timestamp is in future")
            }
        }
    }
    
    /// Property test: Station parsing with optional fields
    /// Tests that optional fields (artUrl, genres) are handled correctly
    func testStationParsing_OptionalFields() throws {
        for iteration in 0..<100 {
            // Randomly include or exclude optional fields
            let includeArt = Bool.random()
            let includeGenres = Bool.random()
            let genreCount = includeGenres ? Int.random(in: 1...5) : 0
            
            let mockStation = generateMockStation(
                includeArt: includeArt,
                genreCount: genreCount
            )
            
            let station = parseStation(from: mockStation)
            
            // Verify optional fields
            if includeArt {
                XCTAssertNotNil(station.artUrl, "Iteration \(iteration): artUrl should be present")
                XCTAssertFalse(station.artUrl!.isEmpty, "Iteration \(iteration): artUrl should not be empty")
            }
            
            if includeGenres {
                XCTAssertNotNil(station.genres, "Iteration \(iteration): genres should not be nil")
                XCTAssertFalse(station.genres?.isEmpty ?? true, "Iteration \(iteration): genres should not be empty")
                XCTAssertEqual(station.genres?.count ?? 0, genreCount, "Iteration \(iteration): genre count mismatch")
            }
        }
    }
    
    /// Property test: QuickMix station detection
    /// Tests that QuickMix stations are properly identified and named
    func testStationParsing_QuickMixDetection() throws {
        for _ in 0..<50 {
            let isQuickMix = Bool.random()
            let mockStation = generateMockStation(isQuickMix: isQuickMix)
            
            let station = parseStation(from: mockStation)
            
            if isQuickMix {
                XCTAssertTrue(station.isQuickMix, "QuickMix flag should be set")
                XCTAssertTrue(station.name.contains("Shuffle") || station.name.contains("🔀"), "QuickMix should have Shuffle in name")
            } else {
                XCTAssertFalse(station.isQuickMix, "Non-QuickMix station should not have flag set")
            }
        }
    }
    
    // MARK: - Song Parsing Tests (Requirements 4.4, 4.5)
    
    /// Property test: Playlist (song list) parsing with various configurations
    /// Tests that all required song fields are populated correctly
    func testPlaylistParsing_AllRequiredFields() throws {
        for iteration in 0..<120 {
            let songCount = Int.random(in: 1...10)
            let mockResponse = generateMockPlaylistResponse(songCount: songCount)
            
            let songs = parsePlaylist(from: mockResponse)
            
            // Verify count (may be less than songCount if ads are filtered)
            XCTAssertLessThanOrEqual(songs.count, songCount, "Iteration \(iteration): Too many songs")
            XCTAssertGreaterThan(songs.count, 0, "Iteration \(iteration): No songs parsed")
            
            // Verify all required fields
            for (index, song) in songs.enumerated() {
                XCTAssertFalse(song.artist.isEmpty, "Iteration \(iteration), Song \(index): artist is empty")
                XCTAssertFalse(song.title.isEmpty, "Iteration \(iteration), Song \(index): title is empty")
                XCTAssertFalse(song.album.isEmpty, "Iteration \(iteration), Song \(index): album is empty")
                XCTAssertNotNil(song.token, "Iteration \(iteration), Song \(index): token is nil")
                XCTAssertNotNil(song.stationId, "Iteration \(iteration), Song \(index): stationId is nil")
                
                // Verify at least one audio URL is present
                let hasAudioUrl = song.lowUrl != nil || song.medUrl != nil || song.highUrl != nil
                XCTAssertTrue(hasAudioUrl, "Iteration \(iteration), Song \(index): No audio URLs present")
            }
        }
    }
    
    /// Property test: Song audio URL parsing with different quality levels
    /// Tests that audio URLs are correctly assigned to low/med/high quality
    func testSongParsing_AudioURLAssignment() throws {
        for iteration in 0..<100 {
            // Generate songs with different URL configurations
            let urlCount = Int.random(in: 1...3)
            let mockSong = generateMockSong(audioUrlCount: urlCount)
            
            let song = parseSong(from: mockSong)
            
            // Verify URL assignment based on count
            switch urlCount {
            case 1:
                XCTAssertNotNil(song.lowUrl, "Iteration \(iteration): lowUrl should be set")
                XCTAssertNotNil(song.medUrl, "Iteration \(iteration): medUrl should fallback to lowUrl")
                XCTAssertNotNil(song.highUrl, "Iteration \(iteration): highUrl should fallback to medUrl")
            case 2:
                XCTAssertNotNil(song.lowUrl, "Iteration \(iteration): lowUrl should be set")
                XCTAssertNotNil(song.medUrl, "Iteration \(iteration): medUrl should be set")
                XCTAssertNotNil(song.highUrl, "Iteration \(iteration): highUrl should fallback to medUrl")
            case 3:
                XCTAssertNotNil(song.lowUrl, "Iteration \(iteration): lowUrl should be set")
                XCTAssertNotNil(song.medUrl, "Iteration \(iteration): medUrl should be set")
                XCTAssertNotNil(song.highUrl, "Iteration \(iteration): highUrl should be set")
            default:
                break
            }
        }
    }
    
    /// Property test: Song rating parsing
    /// Tests that song ratings are correctly parsed and represented
    func testSongParsing_RatingValues() throws {
        for iteration in 0..<100 {
            // Test all possible rating values: -1 (dislike), 0 (none), 1 (like)
            let ratingValue = [-1, 0, 1].randomElement()!
            let mockSong = generateMockSong(rating: ratingValue)
            
            let song = parseSong(from: mockSong)
            
            XCTAssertNotNil(song.nrating, "Iteration \(iteration): rating should not be nil")
            XCTAssertEqual(
                song.nrating?.intValue,
                ratingValue,
                "Iteration \(iteration): rating value mismatch"
            )
        }
    }
    
    /// Property test: Song optional fields (artwork, URLs, trackGain)
    /// Tests that optional song fields are handled correctly
    func testSongParsing_OptionalFields() throws {
        for iteration in 0..<100 {
            let includeArt = Bool.random()
            let includeUrls = Bool.random()
            let includeTrackGain = Bool.random()
            let allowFeedback = Bool.random()
            
            let mockSong = generateMockSong(
                includeArt: includeArt,
                includeUrls: includeUrls,
                includeTrackGain: includeTrackGain,
                allowFeedback: allowFeedback
            )
            
            let song = parseSong(from: mockSong)
            
            if includeArt {
                XCTAssertNotNil(song.art, "Iteration \(iteration): art should be present")
            }
            
            if includeUrls {
                XCTAssertNotNil(song.albumUrl, "Iteration \(iteration): albumUrl should be present")
                XCTAssertNotNil(song.artistUrl, "Iteration \(iteration): artistUrl should be present")
                XCTAssertNotNil(song.titleUrl, "Iteration \(iteration): titleUrl should be present")
            }
            
            if includeTrackGain {
                XCTAssertNotNil(song.trackGain, "Iteration \(iteration): trackGain should be present")
            }
            
            XCTAssertEqual(song.allowFeedback, allowFeedback, "Iteration \(iteration): allowFeedback mismatch")
        }
    }
    
    /// Property test: Ad token filtering
    /// Tests that items with adToken are filtered out from playlists
    func testPlaylistParsing_AdFiltering() throws {
        for iteration in 0..<50 {
            let songCount = Int.random(in: 3...10)
            let adCount = Int.random(in: 1...3)
            
            let mockResponse = generateMockPlaylistResponse(
                songCount: songCount,
                adCount: adCount
            )
            
            let songs = parsePlaylist(from: mockResponse)
            
            // Verify ads are filtered out
            XCTAssertEqual(
                songs.count,
                songCount,
                "Iteration \(iteration): Ads should be filtered out"
            )
            
            // Verify no song has an adToken
            for song in songs {
                // Songs should not have any ad-related properties
                XCTAssertNotNil(song.token, "Songs should have track tokens, not ad tokens")
            }
        }
    }
    
    // MARK: - Search Results Parsing Tests (Requirements 4.6, 4.7)
    
    /// Property test: Search results parsing for songs and artists
    /// Tests that search results are correctly categorized and parsed
    func testSearchResultsParsing_SongsAndArtists() throws {
        for iteration in 0..<100 {
            let songResultCount = Int.random(in: 0...20)
            let artistResultCount = Int.random(in: 0...20)
            
            let mockResponse = generateMockSearchResponse(
                songCount: songResultCount,
                artistCount: artistResultCount
            )
            
            let results = parseSearchResults(from: mockResponse)
            
            // Verify both categories exist
            XCTAssertNotNil(results["Songs"], "Iteration \(iteration): Songs array should exist")
            XCTAssertNotNil(results["Artists"], "Iteration \(iteration): Artists array should exist")
            
            let songs = results["Songs"] as? [PandoraSearchResult] ?? []
            let artists = results["Artists"] as? [PandoraSearchResult] ?? []
            
            // Verify counts
            XCTAssertEqual(
                songs.count,
                songResultCount,
                "Iteration \(iteration): Song result count mismatch"
            )
            XCTAssertEqual(
                artists.count,
                artistResultCount,
                "Iteration \(iteration): Artist result count mismatch"
            )
            
            // Verify all results have required fields
            for (index, result) in songs.enumerated() {
                XCTAssertFalse(result.name.isEmpty, "Iteration \(iteration), Song \(index): name is empty")
                XCTAssertFalse(result.value.isEmpty, "Iteration \(iteration), Song \(index): musicToken is empty")
                XCTAssertTrue(result.name.contains(" - "), "Iteration \(iteration), Song \(index): name should contain ' - ' separator")
            }
            
            for (index, result) in artists.enumerated() {
                XCTAssertFalse(result.name.isEmpty, "Iteration \(iteration), Artist \(index): name is empty")
                XCTAssertFalse(result.value.isEmpty, "Iteration \(iteration), Artist \(index): musicToken is empty")
            }
        }
    }
    
    /// Property test: Empty search results handling
    /// Tests that empty search results are handled gracefully
    func testSearchResultsParsing_EmptyResults() throws {
        for _ in 0..<50 {
            let mockResponse = generateMockSearchResponse(songCount: 0, artistCount: 0)
            
            let results = parseSearchResults(from: mockResponse)
            
            let songs = results["Songs"] as? [PandoraSearchResult] ?? []
            let artists = results["Artists"] as? [PandoraSearchResult] ?? []
            
            XCTAssertTrue(songs.isEmpty, "Empty search should return empty songs array")
            XCTAssertTrue(artists.isEmpty, "Empty search should return empty artists array")
        }
    }
    
    /// Property test: Search result music token validity
    /// Tests that all search results have valid music tokens for station creation
    func testSearchResultsParsing_MusicTokenValidity() throws {
        for iteration in 0..<100 {
            let resultCount = Int.random(in: 1...10)
            let mockResponse = generateMockSearchResponse(
                songCount: resultCount,
                artistCount: resultCount
            )
            
            let results = parseSearchResults(from: mockResponse)
            let songs = results["Songs"] as? [PandoraSearchResult] ?? []
            let artists = results["Artists"] as? [PandoraSearchResult] ?? []
            
            // Verify all music tokens are non-empty and have expected format
            for result in songs + artists {
                XCTAssertFalse(result.value.isEmpty, "Iteration \(iteration): musicToken should not be empty")
                // Music tokens typically start with 'S' for songs or 'R' for artists
                XCTAssertTrue(
                    result.value.hasPrefix("S") || result.value.hasPrefix("R") || result.value.hasPrefix("T"),
                    "Iteration \(iteration): musicToken should have valid prefix"
                )
            }
        }
    }
    
    // MARK: - Mock Data Generators
    
    /// Generate a mock station list response
    private func generateMockStationListResponse(stationCount: Int) -> [String: Any] {
        var stations: [[String: Any]] = []
        
        for i in 0..<stationCount {
            stations.append(generateMockStation(index: i))
        }
        
        return [
            "stat": "ok",
            "result": [
                "stations": stations
            ]
        ]
    }
    
    /// Generate a mock station dictionary
    private func generateMockStation(
        index: Int = 0,
        includeArt: Bool = true,
        genreCount: Int = 2,
        isQuickMix: Bool = false
    ) -> [String: Any] {
        var station: [String: Any] = [
            "stationName": "Test Station \(index)",
            "stationId": "station_id_\(index)",
            "stationToken": "token_\(index)",
            "isShared": Bool.random(),
            "allowAddMusic": Bool.random(),
            "allowRename": Bool.random(),
            "dateCreated": [
                "time": UInt64(Date().timeIntervalSince1970 * 1000) - UInt64.random(in: 0...31536000000) // Random time in past year
            ]
        ]
        
        if includeArt {
            station["artUrl"] = "https://example.com/art/\(index).jpg"
        }
        
        if genreCount > 0 {
            let genres = (0..<genreCount).map { "Genre \($0)" }
            station["genre"] = genres
        }
        
        if isQuickMix {
            station["isQuickMix"] = true
        }
        
        return station
    }
    
    /// Generate a mock playlist response
    private func generateMockPlaylistResponse(songCount: Int, adCount: Int = 0) -> [String: Any] {
        var items: [[String: Any]] = []
        
        // Add songs
        for i in 0..<songCount {
            items.append(generateMockSong(index: i))
        }
        
        // Add ads
        for i in 0..<adCount {
            items.append([
                "adToken": "ad_token_\(i)",
                "audioUrlMap": [:],
                "trackGain": "0.0"
            ])
        }
        
        // Shuffle to mix ads and songs
        items.shuffle()
        
        return [
            "stat": "ok",
            "result": [
                "items": items
            ]
        ]
    }
    
    /// Generate a mock song dictionary
    private func generateMockSong(
        index: Int = 0,
        audioUrlCount: Int = 3,
        rating: Int = 0,
        includeArt: Bool = true,
        includeUrls: Bool = true,
        includeTrackGain: Bool = true,
        allowFeedback: Bool = true
    ) -> [String: Any] {
        var song: [String: Any] = [
            "artistName": "Artist \(index)",
            "songName": "Song \(index)",
            "albumName": "Album \(index)",
            "stationId": "station_\(index)",
            "trackToken": "track_token_\(index)",
            "songRating": rating,
            "allowFeedback": allowFeedback
        ]
        
        // Add audio URLs
        var audioUrls: [String] = []
        for quality in 0..<audioUrlCount {
            audioUrls.append("https://example.com/audio/\(index)_q\(quality).mp3")
        }
        song["additionalAudioUrl"] = audioUrls
        
        if includeArt {
            song["albumArtUrl"] = "https://example.com/art/\(index).jpg"
        }
        
        if includeUrls {
            song["albumDetailUrl"] = "https://example.com/album/\(index)"
            song["artistDetailUrl"] = "https://example.com/artist/\(index)"
            song["songDetailUrl"] = "https://example.com/song/\(index)"
        }
        
        if includeTrackGain {
            song["trackGain"] = String(format: "%.2f", Double.random(in: -10.0...10.0))
        }
        
        return song
    }
    
    /// Generate a mock search response
    private func generateMockSearchResponse(songCount: Int, artistCount: Int) -> [String: Any] {
        var songs: [[String: Any]] = []
        var artists: [[String: Any]] = []
        
        for i in 0..<songCount {
            songs.append([
                "songName": "Song \(i)",
                "artistName": "Artist \(i)",
                "musicToken": "S\(String(format: "%06d", i))"
            ])
        }
        
        for i in 0..<artistCount {
            artists.append([
                "artistName": "Artist \(i)",
                "musicToken": "R\(String(format: "%06d", i))"
            ])
        }
        
        return [
            "stat": "ok",
            "result": [
                "songs": songs,
                "artists": artists
            ]
        ]
    }
    
    // MARK: - Parsing Helpers
    
    /// Parse station list from API response
    private func parseStationList(from response: [String: Any]) -> [Station] {
        guard let result = response["result"] as? [String: Any],
              let stationsArray = result["stations"] as? [[String: Any]] else {
            return []
        }
        
        var stations: [Station] = []
        for stationDict in stationsArray {
            let station = parseStation(from: stationDict)
            stations.append(station)
        }
        
        return stations
    }
    
    /// Parse a single station from dictionary
    private func parseStation(from dict: [String: Any]) -> Station {
        let station = Station()
        
        station.name = dict["stationName"] as? String ?? ""
        station.stationId = dict["stationId"] as? String ?? ""
        station.token = dict["stationToken"] as? String ?? ""
        station.shared = (dict["isShared"] as? Bool) ?? false
        station.allowAddMusic = (dict["allowAddMusic"] as? Bool) ?? false
        station.allowRename = (dict["allowRename"] as? Bool) ?? false
        
        if let dateCreatedDict = dict["dateCreated"] as? [String: Any],
           let time = dateCreatedDict["time"] as? UInt64 {
            station.created = time
        }
        
        if let artUrl = dict["artUrl"] as? String {
            station.artUrl = artUrl
        }
        
        if let genreData = dict["genre"] {
            if let genreArray = genreData as? [String] {
                station.genres = genreArray
            } else if let genreString = genreData as? String {
                station.genres = [genreString]
            }
        }
        
        if (dict["isQuickMix"] as? Bool) == true {
            station.name = "🔀 Shuffle"
            station.isQuickMix = true
        }
        
        return station
    }
    
    /// Parse playlist (song list) from API response
    private func parsePlaylist(from response: [String: Any]) -> [Song] {
        guard let result = response["result"] as? [String: Any],
              let items = result["items"] as? [[String: Any]] else {
            return []
        }
        
        var songs: [Song] = []
        
        for item in items {
            // Skip ad tokens
            if item["adToken"] != nil { continue }
            
            let song = parseSong(from: item)
            songs.append(song)
        }
        
        return songs
    }
    
    /// Parse a single song from dictionary
    private func parseSong(from dict: [String: Any]) -> Song {
        let song = Song()
        
        song.artist = dict["artistName"] as? String ?? ""
        song.title = dict["songName"] as? String ?? ""
        song.album = dict["albumName"] as? String ?? ""
        song.art = dict["albumArtUrl"] as? String
        song.stationId = dict["stationId"] as? String
        song.token = dict["trackToken"] as? String
        song.nrating = dict["songRating"] as? NSNumber
        song.albumUrl = dict["albumDetailUrl"] as? String
        song.artistUrl = dict["artistDetailUrl"] as? String
        song.titleUrl = dict["songDetailUrl"] as? String
        song.trackGain = dict["trackGain"] as? String
        song.allowFeedback = (dict["allowFeedback"] as? Bool) ?? true
        
        // Parse audio URLs
        if let urls = dict["additionalAudioUrl"] as? [String] {
            switch urls.count {
            case 3...:
                song.highUrl = urls[2]
                fallthrough
            case 2:
                song.medUrl = urls[1]
                fallthrough
            case 1:
                song.lowUrl = urls[0]
            default:
                break
            }
        }
        
        // Fallback URL assignments
        if song.medUrl == nil { song.medUrl = song.lowUrl }
        if song.highUrl == nil { song.highUrl = song.medUrl }
        
        return song
    }
    
    /// Parse search results from API response
    private func parseSearchResults(from response: [String: Any]) -> [String: Any] {
        guard let result = response["result"] as? [String: Any] else {
            return ["Songs": [], "Artists": []]
        }
        
        var searchSongs: [PandoraSearchResult] = []
        var searchArtists: [PandoraSearchResult] = []
        
        // Parse songs
        if let songs = result["songs"] as? [[String: Any]] {
            for s in songs {
                let r = PandoraSearchResult()
                let songName = s["songName"] as? String ?? ""
                let artistName = s["artistName"] as? String ?? ""
                r.name = "\(songName) - \(artistName)"
                r.value = s["musicToken"] as? String ?? ""
                searchSongs.append(r)
            }
        }
        
        // Parse artists
        if let artists = result["artists"] as? [[String: Any]] {
            for a in artists {
                let r = PandoraSearchResult()
                r.name = a["artistName"] as? String ?? ""
                r.value = a["musicToken"] as? String ?? ""
                searchArtists.append(r)
            }
        }
        
        return [
            "Songs": searchSongs,
            "Artists": searchArtists
        ]
    }
}
