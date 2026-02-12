//
//  MockPandoraTests.swift
//  HermesTests
//
//  Property-based tests for MockPandora call recording
//  **Validates: Requirements 3.2**
//

import XCTest
import Combine
@testable import Hermes

@MainActor
final class MockPandoraTests: XCTestCase {
    
    var sut: MockPandora!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = MockPandora()
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()


    // MARK: - Property 3: Mock Configuration Affects Behavior
    //
    // For any MockPandora instance, when a return value or error is configured
    // for a method, calling that method should return the configured value or
    // throw the configured error, not the default behavior.
    //
    // **Validates: Requirements 3.3, 3.4**

    /// Property test: Authentication configuration affects return value
    /// Tests that configuring authenticateResult changes the method's return value
    func testProperty_AuthenticationConfigurationAffectsReturnValue() throws {
        // Run 100+ iterations with random configurations
        for iteration in 0..<100 {
            let mock = MockPandora()

            // Randomly configure success or failure
            let shouldSucceed = Bool.random()
            mock.authenticateResult = shouldSucceed

            // Call authenticate
            let result = mock.authenticate("user@example.com", password: "password", request: nil)

            // Verify result matches configuration
            XCTAssertEqual(
                result,
                shouldSucceed,
                "Iteration \(iteration): Expected authenticate to return \(shouldSucceed), got \(result)"
            )

            // Verify isAuthenticated state matches success
            if shouldSucceed {
                XCTAssertTrue(
                    mock.isAuthenticatedValue,
                    "Iteration \(iteration): Expected isAuthenticatedValue to be true after successful auth"
                )
            }
        }
    }

    /// Property test: Station management configuration affects return values
    /// Tests that configuring station operation results changes method return values
    func testProperty_StationManagementConfigurationAffectsReturnValues() throws {
        // Run 100+ iterations with random configurations
        for iteration in 0..<100 {
            let mock = MockPandora()

            // Randomly configure each operation
            let fetchStationsSuccess = Bool.random()
            let createStationSuccess = Bool.random()
            let removeStationSuccess = Bool.random()
            let renameStationSuccess = Bool.random()
            let fetchGenreStationsSuccess = Bool.random()

            mock.fetchStationsResult = fetchStationsSuccess
            mock.createStationResult = createStationSuccess
            mock.removeStationResult = removeStationSuccess
            mock.renameStationResult = renameStationSuccess
            mock.fetchGenreStationsResult = fetchGenreStationsSuccess

            // Call methods and verify results match configuration
            XCTAssertEqual(
                mock.fetchStations(),
                fetchStationsSuccess,
                "Iteration \(iteration): fetchStations result mismatch"
            )

            XCTAssertEqual(
                mock.createStation("M1234"),
                createStationSuccess,
                "Iteration \(iteration): createStation result mismatch"
            )

            XCTAssertEqual(
                mock.removeStation("ST1234"),
                removeStationSuccess,
                "Iteration \(iteration): removeStation result mismatch"
            )

            XCTAssertEqual(
                mock.renameStation("ST1234", to: "New Name"),
                renameStationSuccess,
                "Iteration \(iteration): renameStation result mismatch"
            )

            XCTAssertEqual(
                mock.fetchGenreStations(),
                fetchGenreStationsSuccess,
                "Iteration \(iteration): fetchGenreStations result mismatch"
            )
        }
    }

    /// Property test: Song operation configuration affects return values
    /// Tests that configuring song operation results changes method return values
    func testProperty_SongOperationConfigurationAffectsReturnValues() throws {
        // Run 100+ iterations with random configurations
        for iteration in 0..<100 {
            let mock = MockPandora()

            // Create mock song
            let song = Song()
            song.token = "SONG\(iteration)"

            // Randomly configure each operation
            let rateSongSuccess = Bool.random()
            let tiredOfSongSuccess = Bool.random()
            let deleteRatingSuccess = Bool.random()

            mock.rateSongResult = rateSongSuccess
            mock.tiredOfSongResult = tiredOfSongSuccess
            mock.deleteRatingResult = deleteRatingSuccess

            // Call methods and verify results match configuration
            XCTAssertEqual(
                mock.rateSong(song, as: Bool.random()),
                rateSongSuccess,
                "Iteration \(iteration): rateSong result mismatch"
            )

            XCTAssertEqual(
                mock.tired(of: song),
                tiredOfSongSuccess,
                "Iteration \(iteration): tiredOfSong result mismatch"
            )

            XCTAssertEqual(
                mock.deleteRating(song),
                deleteRatingSuccess,
                "Iteration \(iteration): deleteRating result mismatch"
            )
        }
    }

    /// Property test: Search and seed configuration affects return values
    /// Tests that configuring search and seed operation results changes method return values
    func testProperty_SearchAndSeedConfigurationAffectsReturnValues() throws {
        // Run 100+ iterations with random configurations
        for iteration in 0..<100 {
            let mock = MockPandora()

            // Create mock station
            let station = Station()
            station.token = "ST\(iteration)"

            // Randomly configure each operation
            let searchSuccess = Bool.random()
            let addSeedSuccess = Bool.random()
            let removeSeedSuccess = Bool.random()
            let deleteFeedbackSuccess = Bool.random()

            mock.searchResult = searchSuccess
            mock.addSeedResult = addSeedSuccess
            mock.removeSeedResult = removeSeedSuccess
            mock.deleteFeedbackResult = deleteFeedbackSuccess

            // Call methods and verify results match configuration
            XCTAssertEqual(
                mock.search("query"),
                searchSuccess,
                "Iteration \(iteration): search result mismatch"
            )

            XCTAssertEqual(
                mock.addSeed("SEED123", to: station),
                addSeedSuccess,
                "Iteration \(iteration): addSeed result mismatch"
            )

            XCTAssertEqual(
                mock.removeSeed("SEED123"),
                removeSeedSuccess,
                "Iteration \(iteration): removeSeed result mismatch"
            )

            XCTAssertEqual(
                mock.deleteFeedback("FB123"),
                deleteFeedbackSuccess,
                "Iteration \(iteration): deleteFeedback result mismatch"
            )
        }
    }

    /// Property test: Playback configuration affects return values
    /// Tests that configuring playback operation results changes method return values
    func testProperty_PlaybackConfigurationAffectsReturnValues() throws {
        // Run 100+ iterations with random configurations
        for iteration in 0..<100 {
            let mock = MockPandora()

            // Create mock station
            let station = Station()
            station.token = "ST\(iteration)"

            // Randomly configure operation
            let fetchPlaylistSuccess = Bool.random()
            mock.fetchPlaylistResult = fetchPlaylistSuccess

            // Call method and verify result matches configuration
            XCTAssertEqual(
                mock.fetchPlaylist(for: station),
                fetchPlaylistSuccess,
                "Iteration \(iteration): fetchPlaylist result mismatch"
            )
        }
    }

    /// Property test: Error configuration causes failure and posts error notification
    /// Tests that configuring an error causes the method to fail and post error notification
    func testProperty_ErrorConfigurationCausesFailure() throws {
        // Test authentication error
        for iteration in 0..<100 {
            let mock = MockPandora()
            let expectation = XCTestExpectation(description: "Error notification posted")

            // Configure error
            let errorMessage = "Auth error \(iteration)"
            mock.authenticateError = NSError(domain: "TestError", code: iteration, userInfo: [NSLocalizedDescriptionKey: errorMessage])

            // Listen for error notification
            let cancellable = NotificationCenter.default.publisher(for: Notification.Name("hermes.error"))
                .sink { notification in
                    if let error = notification.userInfo?["error"] as? String {
                        XCTAssertEqual(error, errorMessage, "Iteration \(iteration): Error message mismatch")
                        expectation.fulfill()
                    }
                }

            // Call method
            let result = mock.authenticate("user@example.com", password: "password", request: nil)

            // Verify failure
            XCTAssertFalse(result, "Iteration \(iteration): Expected authenticate to fail when error is configured")
            XCTAssertFalse(mock.isAuthenticatedValue, "Iteration \(iteration): Should not be authenticated after error")

            // Wait for notification
            wait(for: [expectation], timeout: 1.0)
            cancellable.cancel()
        }
    }

    /// Property test: Station management errors cause failure and post error notifications
    /// Tests that configuring errors for station operations causes failures
    func testProperty_StationManagementErrorsCauseFailure() throws {
        // Run 100+ iterations with random error configurations
        for iteration in 0..<100 {
            let mock = MockPandora()

            // Randomly choose which operation to test
            let operation = Int.random(in: 0...4)
            let errorMessage = "Station error \(iteration)"
            let error = NSError(domain: "TestError", code: iteration, userInfo: [NSLocalizedDescriptionKey: errorMessage])

            let expectation = XCTestExpectation(description: "Error notification posted")
            let cancellable = NotificationCenter.default.publisher(for: Notification.Name("hermes.error"))
                .sink { notification in
                    if let receivedError = notification.userInfo?["error"] as? String {
                        XCTAssertEqual(receivedError, errorMessage, "Iteration \(iteration): Error message mismatch")
                        expectation.fulfill()
                    }
                }

            var result = false

            switch operation {
            case 0:
                mock.fetchStationsError = error
                result = mock.fetchStations()
            case 1:
                mock.createStationError = error
                result = mock.createStation("M1234")
            case 2:
                mock.removeStationError = error
                result = mock.removeStation("ST1234")
            case 3:
                mock.renameStationError = error
                result = mock.renameStation("ST1234", to: "New Name")
            case 4:
                mock.fetchGenreStationsError = error
                result = mock.fetchGenreStations()
            default:
                break
            }

            // Verify failure
            XCTAssertFalse(result, "Iteration \(iteration): Expected operation \(operation) to fail when error is configured")

            // Wait for notification
            wait(for: [expectation], timeout: 1.0)
            cancellable.cancel()
        }
    }

    /// Property test: Mock stations configuration affects stations property
    /// Tests that configuring mockStations changes the stations property value
    func testProperty_MockStationsConfigurationAffectsStationsProperty() throws {
        // Run 100+ iterations with random station counts
        for iteration in 0..<100 {
            let mock = MockPandora()

            // Create random number of mock stations
            let stationCount = Int.random(in: 0...10)
            var mockStations: [Station] = []

            for i in 0..<stationCount {
                let station = Station()
                station.token = "ST\(iteration)_\(i)"
                station.name = "Station \(i)"
                mockStations.append(station)
            }

            // Configure mock stations
            mock.mockStations = mockStations

            // Verify stations property returns configured stations
            let retrievedStations = mock.stations as? [Station] ?? []
            XCTAssertEqual(
                retrievedStations.count,
                stationCount,
                "Iteration \(iteration): Expected \(stationCount) stations, got \(retrievedStations.count)"
            )

            // Verify station tokens match
            for (index, station) in retrievedStations.enumerated() {
                XCTAssertEqual(
                    station.token,
                    mockStations[index].token,
                    "Iteration \(iteration): Station \(index) token mismatch"
                )
            }
        }
    }

    /// Property test: Reset restores default configuration
    /// Tests that calling reset() restores all configuration to default values
    func testProperty_ResetRestoresDefaultConfiguration() throws {
        // Run 100+ iterations
        for iteration in 0..<100 {
            let mock = MockPandora()

            // Configure mock with non-default values
            mock.authenticateResult = false
            mock.authenticateError = NSError(domain: "TestError", code: 1)
            mock.isAuthenticatedValue = true
            mock.fetchStationsResult = false
            mock.fetchStationsError = NSError(domain: "TestError", code: 2)
            mock.createStationResult = false
            mock.rateSongResult = false
            mock.searchResult = false

            // Create mock stations
            let station = Station()
            station.token = "ST\(iteration)"
            mock.mockStations = [station]

            // Make some calls
            _ = mock.authenticate("user@example.com", password: "password", request: nil)
            _ = mock.fetchStations()

            // Reset
            mock.reset()

            // Verify all configuration is back to defaults
            XCTAssertTrue(mock.authenticateResult, "Iteration \(iteration): authenticateResult should be true after reset")
            XCTAssertNil(mock.authenticateError, "Iteration \(iteration): authenticateError should be nil after reset")
            XCTAssertFalse(mock.isAuthenticatedValue, "Iteration \(iteration): isAuthenticatedValue should be false after reset")
            XCTAssertTrue(mock.fetchStationsResult, "Iteration \(iteration): fetchStationsResult should be true after reset")
            XCTAssertNil(mock.fetchStationsError, "Iteration \(iteration): fetchStationsError should be nil after reset")
            XCTAssertTrue(mock.createStationResult, "Iteration \(iteration): createStationResult should be true after reset")
            XCTAssertTrue(mock.rateSongResult, "Iteration \(iteration): rateSongResult should be true after reset")
            XCTAssertTrue(mock.searchResult, "Iteration \(iteration): searchResult should be true after reset")

            // Verify mock stations is empty
            let stations = mock.stations as? [Station] ?? []
            XCTAssertEqual(stations.count, 0, "Iteration \(iteration): mockStations should be empty after reset")

            // Verify calls were cleared
            XCTAssertEqual(mock.calls.count, 0, "Iteration \(iteration): calls should be empty after reset")
        }
    }

    /// Property test: Configuration changes don't affect previous calls
    /// Tests that changing configuration after a call doesn't retroactively change the result
    func testProperty_ConfigurationChangesDoNotAffectPreviousCalls() throws {
        // Run 100+ iterations
        for iteration in 0..<100 {
            let mock = MockPandora()

            // Configure for success
            mock.authenticateResult = true

            // Make first call
            let firstResult = mock.authenticate("user1@example.com", password: "pass1", request: nil)
            XCTAssertTrue(firstResult, "Iteration \(iteration): First call should succeed")

            // Change configuration to failure
            mock.authenticateResult = false

            // Make second call
            let secondResult = mock.authenticate("user2@example.com", password: "pass2", request: nil)
            XCTAssertFalse(secondResult, "Iteration \(iteration): Second call should fail")

            // Verify both calls were recorded
            XCTAssertEqual(mock.calls.count, 2, "Iteration \(iteration): Should have 2 recorded calls")

            // Verify first call is still recorded (configuration change didn't affect it)
            XCTAssertTrue(
                mock.didCall(.authenticate(username: "user1@example.com", password: "pass1")),
                "Iteration \(iteration): First call should still be recorded"
            )
            XCTAssertTrue(
                mock.didCall(.authenticate(username: "user2@example.com", password: "pass2")),
                "Iteration \(iteration): Second call should be recorded"
            )
        }
    }

    /// Property test: Multiple configuration changes affect subsequent calls correctly
    /// Tests that configuration can be changed multiple times and each call uses current config
    func testProperty_MultipleConfigurationChangesAffectSubsequentCalls() throws {
        // Run 100+ iterations
        for iteration in 0..<100 {
            let mock = MockPandora()

            // Generate random sequence of configuration changes and calls
            let operationCount = Int.random(in: 3...10)
            var expectedResults: [Bool] = []

            for i in 0..<operationCount {
                // Randomly change configuration
                let shouldSucceed = Bool.random()
                mock.fetchStationsResult = shouldSucceed
                expectedResults.append(shouldSucceed)

                // Make call
                let result = mock.fetchStations()

                // Verify result matches current configuration
                XCTAssertEqual(
                    result,
                    shouldSucceed,
                    "Iteration \(iteration), call \(i): Result should match current configuration"
                )
            }

            // Verify all calls were recorded
            XCTAssertEqual(
                mock.callCount(for: .fetchStations),
                operationCount,
                "Iteration \(iteration): Should have \(operationCount) fetchStations calls"
            )
        }
    }

    }
    
    // MARK: - Property 2: Mock Call Recording is Complete
    //
    // For any sequence of method calls made on a MockPandora instance,
    // the mock's call history should contain exactly those calls in the
    // same order, with no missing or extra calls.
    //
    // **Validates: Requirements 3.2**
    
    /// Property test: All authentication method calls are recorded
    /// Tests that authentication-related methods are captured in call history
    func testProperty_AuthenticationCallsAreRecorded() throws {
        // Run 100+ iterations with random authentication sequences
        for iteration in 0..<100 {
            let mock = MockPandora()
            var expectedCalls: [MockPandora.Call.Method] = []
            
            // Generate random sequence of authentication calls
            let callCount = Int.random(in: 1...10)
            for _ in 0..<callCount {
                let operation = Int.random(in: 0...3)
                
                switch operation {
                case 0:
                    let username = "user\(Int.random(in: 1...100))@example.com"
                    let password = "pass\(Int.random(in: 1...1000))"
                    _ = mock.authenticate(username, password: password, request: nil)
                    expectedCalls.append(.authenticate(username: username, password: password))
                    
                case 1:
                    _ = mock.isAuthenticated()
                    expectedCalls.append(.isAuthenticated)
                    
                case 2:
                    mock.logout()
                    expectedCalls.append(.logout)
                    
                case 3:
                    mock.logoutNoNotify()
                    expectedCalls.append(.logoutNoNotify)
                    
                default:
                    break
                }
            }
            
            // Verify all calls were recorded in order
            XCTAssertEqual(
                mock.calls.count,
                expectedCalls.count,
                "Iteration \(iteration): Expected \(expectedCalls.count) calls, got \(mock.calls.count)"
            )
            
            for (index, expectedMethod) in expectedCalls.enumerated() {
                XCTAssertEqual(
                    mock.calls[index].method,
                    expectedMethod,
                    "Iteration \(iteration): Call \(index) mismatch"
                )
            }
        }
    }
    
    /// Property test: All station management method calls are recorded
    /// Tests that station-related methods are captured in call history
    func testProperty_StationManagementCallsAreRecorded() throws {
        // Run 100+ iterations with random station management sequences
        for iteration in 0..<100 {
            let mock = MockPandora()
            var expectedCalls: [MockPandora.Call.Method] = []
            
            // Generate random sequence of station management calls
            let callCount = Int.random(in: 1...10)
            for _ in 0..<callCount {
                let operation = Int.random(in: 0...5)
                
                switch operation {
                case 0:
                    _ = mock.fetchStations()
                    expectedCalls.append(.fetchStations)
                    
                case 1:
                    let musicId = "M\(Int.random(in: 1000...9999))"
                    _ = mock.createStation(musicId)
                    expectedCalls.append(.createStation(musicId: musicId))
                    
                case 2:
                    let token = "ST\(Int.random(in: 1000...9999))"
                    _ = mock.removeStation(token)
                    expectedCalls.append(.removeStation(token: token))
                    
                case 3:
                    let token = "ST\(Int.random(in: 1000...9999))"
                    let name = "Station \(Int.random(in: 1...100))"
                    _ = mock.renameStation(token, to: name)
                    expectedCalls.append(.renameStation(token: token, name: name))
                    
                case 4:
                    _ = mock.fetchGenreStations()
                    expectedCalls.append(.fetchGenreStations)
                    
                case 5:
                    let sort = Int.random(in: 0...3)
                    mock.sortStations(sort)
                    expectedCalls.append(.sortStations(sort: sort))
                    
                default:
                    break
                }
            }
            
            // Verify all calls were recorded in order
            XCTAssertEqual(
                mock.calls.count,
                expectedCalls.count,
                "Iteration \(iteration): Expected \(expectedCalls.count) calls, got \(mock.calls.count)"
            )
            
            for (index, expectedMethod) in expectedCalls.enumerated() {
                XCTAssertEqual(
                    mock.calls[index].method,
                    expectedMethod,
                    "Iteration \(iteration): Call \(index) mismatch"
                )
            }
        }
    }
    
    /// Property test: All song operation method calls are recorded
    /// Tests that song-related methods are captured in call history
    func testProperty_SongOperationCallsAreRecorded() throws {
        // Run 100+ iterations with random song operation sequences
        for iteration in 0..<100 {
            let mock = MockPandora()
            var expectedCalls: [MockPandora.Call.Method] = []
            
            // Create mock songs for testing
            let mockSongs = (0..<5).map { index -> Song in
                let song = Song()
                song.token = "SONG\(index)_\(Int.random(in: 1000...9999))"
                return song
            }
            
            // Generate random sequence of song operation calls
            let callCount = Int.random(in: 1...10)
            for _ in 0..<callCount {
                let operation = Int.random(in: 0...2)
                let song = mockSongs.randomElement()!
                let token = song.token ?? ""
                
                switch operation {
                case 0:
                    let liked = Bool.random()
                    _ = mock.rateSong(song, as: liked)
                    expectedCalls.append(.rateSong(songToken: token, liked: liked))
                    
                case 1:
                    _ = mock.tired(of: song)
                    expectedCalls.append(.tiredOfSong(songToken: token))
                    
                case 2:
                    _ = mock.deleteRating(song)
                    expectedCalls.append(.deleteRating(songToken: token))
                    
                default:
                    break
                }
            }
            
            // Verify all calls were recorded in order
            XCTAssertEqual(
                mock.calls.count,
                expectedCalls.count,
                "Iteration \(iteration): Expected \(expectedCalls.count) calls, got \(mock.calls.count)"
            )
            
            for (index, expectedMethod) in expectedCalls.enumerated() {
                XCTAssertEqual(
                    mock.calls[index].method,
                    expectedMethod,
                    "Iteration \(iteration): Call \(index) mismatch"
                )
            }
        }
    }
    
    /// Property test: All search and seed management calls are recorded
    /// Tests that search and seed-related methods are captured in call history
    func testProperty_SearchAndSeedCallsAreRecorded() throws {
        // Run 100+ iterations with random search and seed sequences
        for iteration in 0..<100 {
            let mock = MockPandora()
            var expectedCalls: [MockPandora.Call.Method] = []
            
            // Create mock station for testing
            let mockStation = Station()
            mockStation.token = "ST\(Int.random(in: 1000...9999))"
            
            // Generate random sequence of search and seed calls
            let callCount = Int.random(in: 1...10)
            for _ in 0..<callCount {
                let operation = Int.random(in: 0...3)
                
                switch operation {
                case 0:
                    let query = "artist\(Int.random(in: 1...100))"
                    _ = mock.search(query)
                    expectedCalls.append(.search(query: query))
                    
                case 1:
                    let token = "SEED\(Int.random(in: 1000...9999))"
                    _ = mock.addSeed(token, to: mockStation)
                    expectedCalls.append(.addSeed(token: token, stationToken: mockStation.token))
                    
                case 2:
                    let seedId = "SEED\(Int.random(in: 1000...9999))"
                    _ = mock.removeSeed(seedId)
                    expectedCalls.append(.removeSeed(seedId: seedId))
                    
                case 3:
                    let feedbackId = "FB\(Int.random(in: 1000...9999))"
                    _ = mock.deleteFeedback(feedbackId)
                    expectedCalls.append(.deleteFeedback(feedbackId: feedbackId))
                    
                default:
                    break
                }
            }
            
            // Verify all calls were recorded in order
            XCTAssertEqual(
                mock.calls.count,
                expectedCalls.count,
                "Iteration \(iteration): Expected \(expectedCalls.count) calls, got \(mock.calls.count)"
            )
            
            for (index, expectedMethod) in expectedCalls.enumerated() {
                XCTAssertEqual(
                    mock.calls[index].method,
                    expectedMethod,
                    "Iteration \(iteration): Call \(index) mismatch"
                )
            }
        }
    }
    
    /// Property test: Mixed method calls are recorded in correct order
    /// Tests that interleaved calls from different categories maintain order
    func testProperty_MixedCallsRecordedInOrder() throws {
        // Run 100+ iterations with random mixed sequences
        for iteration in 0..<100 {
            let mock = MockPandora()
            var expectedCalls: [MockPandora.Call.Method] = []
            
            // Create test data
            let mockStation = Station()
            mockStation.token = "ST\(Int.random(in: 1000...9999))"
            
            let mockSong = Song()
            mockSong.token = "SONG\(Int.random(in: 1000...9999))"
            
            // Generate random sequence mixing all method types
            let callCount = Int.random(in: 5...20)
            for _ in 0..<callCount {
                let operation = Int.random(in: 0...10)
                
                switch operation {
                case 0:
                    let username = "user\(Int.random(in: 1...100))@example.com"
                    let password = "pass\(Int.random(in: 1...1000))"
                    _ = mock.authenticate(username, password: password, request: nil)
                    expectedCalls.append(.authenticate(username: username, password: password))
                    
                case 1:
                    _ = mock.fetchStations()
                    expectedCalls.append(.fetchStations)
                    
                case 2:
                    let musicId = "M\(Int.random(in: 1000...9999))"
                    _ = mock.createStation(musicId)
                    expectedCalls.append(.createStation(musicId: musicId))
                    
                case 3:
                    _ = mock.fetchPlaylist(for: mockStation)
                    expectedCalls.append(.fetchPlaylist(stationToken: mockStation.token))
                    
                case 4:
                    let liked = Bool.random()
                    _ = mock.rateSong(mockSong, as: liked)
                    expectedCalls.append(.rateSong(songToken: mockSong.token ?? "", liked: liked))
                    
                case 5:
                    let query = "artist\(Int.random(in: 1...100))"
                    _ = mock.search(query)
                    expectedCalls.append(.search(query: query))
                    
                case 6:
                    _ = mock.isAuthenticated()
                    expectedCalls.append(.isAuthenticated)
                    
                case 7:
                    let token = "ST\(Int.random(in: 1000...9999))"
                    _ = mock.removeStation(token)
                    expectedCalls.append(.removeStation(token: token))
                    
                case 8:
                    _ = mock.tired(of: mockSong)
                    expectedCalls.append(.tiredOfSong(songToken: mockSong.token ?? ""))
                    
                case 9:
                    _ = mock.fetchGenreStations()
                    expectedCalls.append(.fetchGenreStations)
                    
                case 10:
                    let sort = Int.random(in: 0...3)
                    mock.sortStations(sort)
                    expectedCalls.append(.sortStations(sort: sort))
                    
                default:
                    break
                }
            }
            
            // Verify all calls were recorded in exact order
            XCTAssertEqual(
                mock.calls.count,
                expectedCalls.count,
                "Iteration \(iteration): Expected \(expectedCalls.count) calls, got \(mock.calls.count)"
            )
            
            for (index, expectedMethod) in expectedCalls.enumerated() {
                XCTAssertEqual(
                    mock.calls[index].method,
                    expectedMethod,
                    "Iteration \(iteration): Call \(index) mismatch - expected \(expectedMethod), got \(mock.calls[index].method)"
                )
            }
        }
    }
    
    /// Property test: Call timestamps are monotonically increasing
    /// Tests that recorded calls have timestamps in chronological order
    func testProperty_CallTimestampsAreMonotonicallyIncreasing() throws {
        // Run 100+ iterations
        for iteration in 0..<100 {
            let mock = MockPandora()
            
            // Make a sequence of calls
            let callCount = Int.random(in: 5...20)
            for i in 0..<callCount {
                _ = mock.authenticate("user\(i)@example.com", password: "pass\(i)", request: nil)
                
                // Small delay to ensure timestamps differ
                Thread.sleep(forTimeInterval: 0.001)
            }
            
            // Verify timestamps are monotonically increasing
            for i in 1..<mock.calls.count {
                let previousTimestamp = mock.calls[i - 1].timestamp
                let currentTimestamp = mock.calls[i].timestamp
                
                XCTAssertLessThanOrEqual(
                    previousTimestamp,
                    currentTimestamp,
                    "Iteration \(iteration): Timestamp at index \(i) is not >= previous timestamp"
                )
            }
        }
    }
    
    /// Property test: Reset clears all recorded calls
    /// Tests that calling reset() removes all call history
    func testProperty_ResetClearsAllCalls() throws {
        // Run 100+ iterations
        for iteration in 0..<100 {
            let mock = MockPandora()
            
            // Make random number of calls
            let callCount = Int.random(in: 1...20)
            for i in 0..<callCount {
                _ = mock.authenticate("user\(i)@example.com", password: "pass\(i)", request: nil)
            }
            
            // Verify calls were recorded
            XCTAssertEqual(
                mock.calls.count,
                callCount,
                "Iteration \(iteration): Expected \(callCount) calls before reset"
            )
            
            // Reset
            mock.reset()
            
            // Verify all calls were cleared
            XCTAssertEqual(
                mock.calls.count,
                0,
                "Iteration \(iteration): Expected 0 calls after reset, got \(mock.calls.count)"
            )
        }
    }
    
    /// Property test: Helper methods correctly identify recorded calls
    /// Tests that didCall() and callCount() accurately reflect call history
    func testProperty_HelperMethodsReflectCallHistory() throws {
        // Run 100+ iterations
        for iteration in 0..<100 {
            let mock = MockPandora()
            
            // Make specific calls with known counts
            let username = "test@example.com"
            let password = "testpass"
            let authenticateCount = Int.random(in: 1...5)
            let fetchStationsCount = Int.random(in: 1...5)
            
            for _ in 0..<authenticateCount {
                _ = mock.authenticate(username, password: password, request: nil)
            }
            
            for _ in 0..<fetchStationsCount {
                _ = mock.fetchStations()
            }
            
            // Verify didCall() works correctly
            XCTAssertTrue(
                mock.didCall(.authenticate(username: username, password: password)),
                "Iteration \(iteration): didCall should return true for authenticate"
            )
            XCTAssertTrue(
                mock.didCall(.fetchStations),
                "Iteration \(iteration): didCall should return true for fetchStations"
            )
            XCTAssertFalse(
                mock.didCall(.logout),
                "Iteration \(iteration): didCall should return false for logout"
            )
            
            // Verify callCount() works correctly
            XCTAssertEqual(
                mock.callCount(for: .authenticate(username: username, password: password)),
                authenticateCount,
                "Iteration \(iteration): Expected \(authenticateCount) authenticate calls"
            )
            XCTAssertEqual(
                mock.callCount(for: .fetchStations),
                fetchStationsCount,
                "Iteration \(iteration): Expected \(fetchStationsCount) fetchStations calls"
            )
            XCTAssertEqual(
                mock.callCount(for: .logout),
                0,
                "Iteration \(iteration): Expected 0 logout calls"
            )
        }
    }
    
    // MARK: - Edge Cases
    
    /// Test that nil parameters are handled correctly in call recording
    func testCallRecording_WithNilParameters() throws {
        let mock = MockPandora()
        
        // Call methods with nil parameters
        _ = mock.authenticate(nil, password: nil, request: nil)
        _ = mock.createStation(nil)
        _ = mock.removeStation(nil)
        _ = mock.renameStation(nil, to: nil)
        _ = mock.search(nil)
        
        // Verify calls were recorded with empty strings
        XCTAssertEqual(mock.calls.count, 5)
        XCTAssertTrue(mock.didCall(.authenticate(username: "", password: "")))
        XCTAssertTrue(mock.didCall(.createStation(musicId: "")))
        XCTAssertTrue(mock.didCall(.removeStation(token: "")))
        XCTAssertTrue(mock.didCall(.renameStation(token: "", name: "")))
        XCTAssertTrue(mock.didCall(.search(query: "")))
    }
    
    /// Test that empty string parameters are recorded correctly
    func testCallRecording_WithEmptyStrings() throws {
        let mock = MockPandora()
        
        // Call methods with empty strings
        _ = mock.authenticate("", password: "", request: nil)
        _ = mock.createStation("")
        _ = mock.search("")
        
        // Verify calls were recorded
        XCTAssertEqual(mock.calls.count, 3)
        XCTAssertTrue(mock.didCall(.authenticate(username: "", password: "")))
        XCTAssertTrue(mock.didCall(.createStation(musicId: "")))
        XCTAssertTrue(mock.didCall(.search(query: "")))
    }
    
    /// Test that special characters in parameters are recorded correctly
    func testCallRecording_WithSpecialCharacters() throws {
        let mock = MockPandora()
        
        let specialUsername = "user+test@example.com"
        let specialPassword = "p@$$w0rd!#%"
        let specialQuery = "artist: \"The Beatles\" & more"
        
        _ = mock.authenticate(specialUsername, password: specialPassword, request: nil)
        _ = mock.search(specialQuery)
        
        // Verify calls were recorded with special characters intact
        XCTAssertTrue(mock.didCall(.authenticate(username: specialUsername, password: specialPassword)))
        XCTAssertTrue(mock.didCall(.search(query: specialQuery)))
    }
}
