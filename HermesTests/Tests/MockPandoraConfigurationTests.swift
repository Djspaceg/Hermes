//
//  MockPandoraConfigurationTests.swift
//  HermesTests
//
//  Unit tests for MockPandora configurable behavior
//  **Validates: Requirements 3.3, 3.4**
//

import XCTest
@testable import Hermes

@MainActor
final class MockPandoraConfigurationTests: XCTestCase {
    
    var sut: MockPandora!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = MockPandora()
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Return Value Configuration Tests
    
    func testAuthenticateResult_CanBeConfigured() throws {
        // Given: Mock configured to fail authentication
        sut.authenticateResult = false
        
        // When: Attempting to authenticate
        let result = sut.authenticate("user@example.com", password: "password", request: nil)
        
        // Then: Authentication fails as configured
        XCTAssertFalse(result)
        XCTAssertFalse(sut.isAuthenticatedValue)
    }
    
    func testFetchStationsResult_CanBeConfigured() throws {
        // Given: Mock configured to fail fetching stations
        sut.fetchStationsResult = false
        
        // When: Attempting to fetch stations
        let result = sut.fetchStations()
        
        // Then: Fetch fails as configured
        XCTAssertFalse(result)
    }
    
    func testCreateStationResult_CanBeConfigured() throws {
        // Given: Mock configured to fail creating station
        sut.createStationResult = false
        
        // When: Attempting to create station
        let result = sut.createStation("M12345")
        
        // Then: Creation fails as configured
        XCTAssertFalse(result)
    }
    
    func testRateSongResult_CanBeConfigured() throws {
        // Given: Mock configured to fail rating song
        sut.rateSongResult = false
        let song = Song()
        song.token = "SONG123"
        
        // When: Attempting to rate song
        let result = sut.rateSong(song, as: true)
        
        // Then: Rating fails as configured
        XCTAssertFalse(result)
    }
    
    // MARK: - Error Simulation Tests
    
    func testAuthenticateError_PostsErrorNotification() throws {
        // Given: Mock configured with authentication error
        let expectation = expectation(forNotification: Notification.Name("hermes.error"), object: nil)
        
        enum TestError: Error {
            case authFailed
        }
        sut.authenticateError = TestError.authFailed
        
        // When: Attempting to authenticate
        let result = sut.authenticate("user@example.com", password: "password", request: nil)
        
        // Then: Error notification is posted and authentication fails
        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(result)
        XCTAssertFalse(sut.isAuthenticatedValue)
    }
    
    func testFetchStationsError_PostsErrorNotification() throws {
        // Given: Mock configured with fetch stations error
        let expectation = expectation(forNotification: Notification.Name("hermes.error"), object: nil)
        
        enum TestError: Error {
            case networkError
        }
        sut.fetchStationsError = TestError.networkError
        
        // When: Attempting to fetch stations
        let result = sut.fetchStations()
        
        // Then: Error notification is posted and fetch fails
        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(result)
    }
    
    func testCreateStationError_PostsErrorNotification() throws {
        // Given: Mock configured with create station error
        let expectation = expectation(forNotification: Notification.Name("hermes.error"), object: nil)
        
        enum TestError: Error {
            case invalidMusicId
        }
        sut.createStationError = TestError.invalidMusicId
        
        // When: Attempting to create station
        let result = sut.createStation("INVALID")
        
        // Then: Error notification is posted and creation fails
        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(result)
    }
    
    func testRateSongError_PostsErrorNotification() throws {
        // Given: Mock configured with rate song error
        let expectation = expectation(forNotification: Notification.Name("hermes.error"), object: nil)
        
        enum TestError: Error {
            case ratingFailed
        }
        sut.rateSongError = TestError.ratingFailed
        
        let song = Song()
        song.token = "SONG123"
        
        // When: Attempting to rate song
        let result = sut.rateSong(song, as: true)
        
        // Then: Error notification is posted and rating fails
        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(result)
    }
    
    // MARK: - Mock Stations Configuration Tests
    
    func testMockStations_CanBeConfigured() throws {
        // Given: Mock configured with test stations
        let station1 = Station()
        station1.token = "ST001"
        station1.name = "Test Station 1"
        
        let station2 = Station()
        station2.token = "ST002"
        station2.name = "Test Station 2"
        
        sut.mockStations = [station1, station2]
        
        // When: Accessing stations property
        let stations = sut.stations as? [Station]
        
        // Then: Returns configured stations
        XCTAssertEqual(stations?.count, 2)
        XCTAssertEqual(stations?[0].token, "ST001")
        XCTAssertEqual(stations?[1].token, "ST002")
    }
    
    func testMockStations_DefaultsToEmptyArray() throws {
        // Given: Fresh mock instance
        let mock = MockPandora()
        
        // When: Accessing stations property
        let stations = mock.stations as? [Station]
        
        // Then: Returns empty array
        XCTAssertNotNil(stations)
        XCTAssertEqual(stations?.count, 0)
    }
    
    // MARK: - Reset Behavior Tests
    
    func testReset_ClearsAllConfiguration() throws {
        // Given: Mock with various configurations
        enum TestError: Error {
            case testError
        }
        
        sut.authenticateResult = false
        sut.authenticateError = TestError.testError
        sut.fetchStationsResult = false
        sut.fetchStationsError = TestError.testError
        sut.isAuthenticatedValue = true
        
        let station = Station()
        station.token = "ST001"
        sut.mockStations = [station]
        
        // When: Resetting the mock
        sut.reset()
        
        // Then: All configuration is reset to defaults
        XCTAssertTrue(sut.authenticateResult)
        XCTAssertNil(sut.authenticateError)
        XCTAssertTrue(sut.fetchStationsResult)
        XCTAssertNil(sut.fetchStationsError)
        XCTAssertFalse(sut.isAuthenticatedValue)
        XCTAssertEqual((sut.mockStations as? [Station])?.count, 0)
    }
    
    // MARK: - Combined Configuration Tests
    
    func testMultipleErrorsCanBeConfigured() throws {
        // Given: Mock configured with multiple errors
        enum TestError: Error {
            case authError
            case stationError
            case songError
        }
        
        sut.authenticateError = TestError.authError
        sut.fetchStationsError = TestError.stationError
        sut.rateSongError = TestError.songError
        
        // When: Calling methods with errors
        let authResult = sut.authenticate("user@example.com", password: "password", request: nil)
        let stationsResult = sut.fetchStations()
        
        let song = Song()
        song.token = "SONG123"
        let rateResult = sut.rateSong(song, as: true)
        
        // Then: All methods fail as configured
        XCTAssertFalse(authResult)
        XCTAssertFalse(stationsResult)
        XCTAssertFalse(rateResult)
    }
    
    func testSuccessAndErrorCanBeConfiguredIndependently() throws {
        // Given: Mock with some methods configured to succeed and others to fail
        enum TestError: Error {
            case authError
        }
        
        sut.authenticateError = TestError.authError  // Will fail
        sut.fetchStationsResult = true               // Will succeed
        
        // When: Calling both methods
        let authResult = sut.authenticate("user@example.com", password: "password", request: nil)
        let stationsResult = sut.fetchStations()
        
        // Then: Results match configuration
        XCTAssertFalse(authResult)  // Failed due to error
        XCTAssertTrue(stationsResult)  // Succeeded
    }
}
