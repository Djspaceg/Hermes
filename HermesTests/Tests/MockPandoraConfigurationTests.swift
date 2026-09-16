//
//  MockPandoraConfigurationTests.swift
//  HermesTests
//
//  Unit tests for MockPandora configurable behavior
//  **Validates: Requirements 3.3, 3.4**
//

import Testing
import Foundation
@testable import Hermes

@MainActor
@Suite("MockPandoraConfigurationTests", .serialized)
struct MockPandoraConfigurationTests {
    let sut: MockPandora

    init() {
        sut = MockPandora()
    }

    private func performExpectingErrorNotification(
        _ operation: () -> Bool
    ) async -> Bool {
        var result = false
        await confirmation("Posts hermes.error notification") { confirmation in
            let observer = NotificationCenter.default.addObserver(
                forName: Notification.Name("hermes.error"),
                object: nil,
                queue: nil
            ) { _ in
                confirmation()
            }
            defer {
                NotificationCenter.default.removeObserver(observer)
            }

            result = operation()
        }
        return result
    }
    
    // MARK: - Return Value Configuration Tests
    
    @Test("Authenticate Result Can Be Configured")
    func testAuthenticateResult_CanBeConfigured() throws {
        // Given: Mock configured to fail authentication
        sut.authenticateResult = false
        
        // When: Attempting to authenticate
        let result = sut.authenticate("user@example.com", password: "password", request: nil)
        
        // Then: Authentication fails as configured
        #expect(!(result))
        #expect(!(sut.isAuthenticatedValue))
    }
    
    @Test("Fetch Stations Result Can Be Configured")
    func testFetchStationsResult_CanBeConfigured() throws {
        // Given: Mock configured to fail fetching stations
        sut.fetchStationsResult = false
        
        // When: Attempting to fetch stations
        let result = sut.fetchStations()
        
        // Then: Fetch fails as configured
        #expect(!(result))
    }
    
    @Test("Create Station Result Can Be Configured")
    func testCreateStationResult_CanBeConfigured() throws {
        // Given: Mock configured to fail creating station
        sut.createStationResult = false
        
        // When: Attempting to create station
        let result = sut.createStation("M12345")
        
        // Then: Creation fails as configured
        #expect(!(result))
    }
    
    @Test("Rate Song Result Can Be Configured")
    func testRateSongResult_CanBeConfigured() throws {
        // Given: Mock configured to fail rating song
        sut.rateSongResult = false
        let song = Song()
        song.token = "SONG123"
        
        // When: Attempting to rate song
        let result = sut.rateSong(song, as: true)
        
        // Then: Rating fails as configured
        #expect(!(result))
    }
    
    // MARK: - Error Simulation Tests
    
    @Test("Authenticate Error Posts Error Notification")
    func testAuthenticateError_PostsErrorNotification() async throws {
        // Given: Mock configured with authentication error
        enum TestError: Error {
            case authFailed
        }
        sut.authenticateError = TestError.authFailed
        
        // When: Attempting to authenticate
        let result = await performExpectingErrorNotification {
            sut.authenticate("user@example.com", password: "password", request: nil)
        }
        
        // Then: Error notification is posted and authentication fails
        #expect(!(result))
        #expect(!(sut.isAuthenticatedValue))
    }
    
    @Test("Fetch Stations Error Posts Error Notification")
    func testFetchStationsError_PostsErrorNotification() async throws {
        // Given: Mock configured with fetch stations error
        enum TestError: Error {
            case networkError
        }
        sut.fetchStationsError = TestError.networkError
        
        // When: Attempting to fetch stations
        let result = await performExpectingErrorNotification {
            sut.fetchStations()
        }
        
        // Then: Error notification is posted and fetch fails
        #expect(!(result))
    }
    
    @Test("Create Station Error Posts Error Notification")
    func testCreateStationError_PostsErrorNotification() async throws {
        // Given: Mock configured with create station error
        enum TestError: Error {
            case invalidMusicId
        }
        sut.createStationError = TestError.invalidMusicId
        
        // When: Attempting to create station
        let result = await performExpectingErrorNotification {
            sut.createStation("INVALID")
        }
        
        // Then: Error notification is posted and creation fails
        #expect(!(result))
    }
    
    @Test("Rate Song Error Posts Error Notification")
    func testRateSongError_PostsErrorNotification() async throws {
        // Given: Mock configured with rate song error
        enum TestError: Error {
            case ratingFailed
        }
        sut.rateSongError = TestError.ratingFailed
        
        let song = Song()
        song.token = "SONG123"
        
        // When: Attempting to rate song
        let result = await performExpectingErrorNotification {
            sut.rateSong(song, as: true)
        }
        
        // Then: Error notification is posted and rating fails
        #expect(!(result))
    }
    
    // MARK: - Mock Stations Configuration Tests
    
    @Test("Mock Stations Can Be Configured")
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
        #expect((stations?.count) == (2))
        #expect((stations?[0].token) == ("ST001"))
        #expect((stations?[1].token) == ("ST002"))
    }
    
    @Test("Mock Stations Defaults To Empty Array")
    func testMockStations_DefaultsToEmptyArray() throws {
        // Given: Fresh mock instance
        let mock = MockPandora()
        
        // When: Accessing stations property
        let stations = mock.stations as? [Station]
        
        // Then: Returns empty array
        #expect((stations) != nil)
        #expect((stations?.count) == (0))
    }
    
    // MARK: - Reset Behavior Tests
    
    @Test("Reset Clears All Configuration")
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
        #expect(sut.authenticateResult)
        #expect((sut.authenticateError) == nil)
        #expect(sut.fetchStationsResult)
        #expect((sut.fetchStationsError) == nil)
        #expect(!(sut.isAuthenticatedValue))
        #expect(((sut.mockStations as? [Station])?.count) == (0))
    }
    
    // MARK: - Combined Configuration Tests
    
    @Test("Multiple Errors Can Be Configured")
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
        #expect(!(authResult))
        #expect(!(stationsResult))
        #expect(!(rateResult))
    }
    
    @Test("Success And Error Can Be Configured Independently")
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
        #expect(!(authResult))  // Failed due to error
        #expect(stationsResult)  // Succeeded
    }
}
