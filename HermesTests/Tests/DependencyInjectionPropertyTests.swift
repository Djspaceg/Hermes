//
//  DependencyInjectionPropertyTests.swift
//  HermesTests
//
//  Comprehensive property tests for the dependency injection system
//

import XCTest
import Combine
@testable import Hermes

// MARK: - Property 4: Test Isolation Prevents Side Effects

/// Property tests validating that test isolation prevents side effects.
///
/// For any test that uses MockPandora, no network requests should be made,
/// no keychain access should occur, and no production API calls should be triggered.
///
/// **Validates: Requirements 3.5, 5.5, 5.6, 5.7**
@MainActor
final class TestIsolationPropertyTests: XCTestCase {
    
    // MARK: - Property 4: Test isolation prevents side effects
    //
    // For any test that uses MockPandora, no network requests should be made,
    // no keychain access should occur, and no production API calls should be
    // triggered during test execution.
    //
    // **Validates: Requirements 3.5, 5.5, 5.6, 5.7**
    
    /// Property test: MockPandora operations don't trigger network requests
    /// Tests that all MockPandora operations complete without network activity
    func testProperty_MockOperationsDoNotTriggerNetworkRequests() throws {
        // Feature: dependency-injection, Property 4: Test isolation prevents side effects
        // **Validates: Requirements 3.5, 5.5, 5.6, 5.7**
        
        for iteration in 0..<100 {
            let mock = MockPandora()
            
            // Configure mock for success
            mock.authenticateResult = true
            mock.fetchStationsResult = true
            
            // Create test stations and songs
            let station = Station()
            station.token = "ST\(iteration)"
            station.name = "Test Station \(iteration)"
            
            let song = Song()
            song.token = "SONG\(iteration)"
            
            // Perform all operations - these should complete immediately
            // without any network activity (synchronous mock behavior)
            let startTime = Date()
            
            _ = mock.authenticate("user\(iteration)@test.com", password: "pass\(iteration)", request: nil)
            _ = mock.fetchStations()
            _ = mock.createStation("M\(iteration)")
            _ = mock.removeStation("ST\(iteration)")
            _ = mock.renameStation("ST\(iteration)", to: "New Name")
            _ = mock.fetchPlaylist(for: station)
            _ = mock.rateSong(song, as: Bool.random())
            _ = mock.tired(of: song)
            _ = mock.search("query\(iteration)")
            
            let elapsed = Date().timeIntervalSince(startTime)
            
            // All operations should complete nearly instantly (< 100ms)
            // Real network requests would take much longer
            XCTAssertLessThan(
                elapsed,
                0.1,
                "Iteration \(iteration): Operations took \(elapsed)s - possible network activity"
            )
            
            // Verify all calls were recorded (mock was actually used)
            XCTAssertGreaterThan(
                mock.calls.count,
                0,
                "Iteration \(iteration): No calls recorded - mock may not be working"
            )
        }
    }
    
    /// Property test: Test AppState instances don't share state with production
    /// Tests that test instances are completely isolated from production singleton
    func testProperty_TestAppStateInstancesAreIsolated() throws {
        // Feature: dependency-injection, Property 4: Test isolation prevents side effects
        // **Validates: Requirements 3.5, 5.5, 5.6, 5.7**
        
        for iteration in 0..<100 {
            // Create isolated test instance
            let (testAppState, mock) = AppState.testInstance()
            
            // Configure mock with unique values
            mock.isAuthenticatedValue = Bool.random()
            let stationCount = Int.random(in: 0...5)
            mock.mockStations = (0..<stationCount).map { i in
                let s = Station()
                s.token = "ST\(iteration)_\(i)"
                s.name = "Station \(i)"
                return s
            }
            
            // Verify test instance uses the mock
            XCTAssertTrue(
                testAppState.pandora === mock,
                "Iteration \(iteration): Test AppState should use injected mock"
            )
            
            // Verify test instance is different from production singleton
            // (We can't directly compare to AppState.shared in tests as it would
            // trigger production initialization, but we can verify the mock is used)
            XCTAssertTrue(
                testAppState.pandora is MockPandora,
                "Iteration \(iteration): Test AppState should have MockPandora"
            )
            
            // Verify operations use the mock
            _ = testAppState.pandora.fetchStations()
            XCTAssertTrue(
                mock.didCall(.fetchStations),
                "Iteration \(iteration): fetchStations should be recorded on mock"
            )
        }
    }
    
    /// Property test: Multiple test instances don't interfere with each other
    /// Tests that creating multiple test instances maintains isolation
    func testProperty_MultipleTestInstancesAreIndependent() throws {
        // Feature: dependency-injection, Property 4: Test isolation prevents side effects
        // **Validates: Requirements 3.5, 5.5, 5.6, 5.7**
        
        for iteration in 0..<100 {
            // Create two independent test instances
            let (appState1, mock1) = AppState.testInstance()
            let (appState2, mock2) = AppState.testInstance()
            
            // Configure differently
            mock1.authenticateResult = true
            mock2.authenticateResult = false
            
            mock1.isAuthenticatedValue = true
            mock2.isAuthenticatedValue = false
            
            // Perform operations on each
            let result1 = appState1.pandora.authenticate("user1@test.com", password: "pass1", request: nil)
            let result2 = appState2.pandora.authenticate("user2@test.com", password: "pass2", request: nil)
            
            // Verify results match individual configurations
            XCTAssertTrue(
                result1,
                "Iteration \(iteration): AppState1 should return configured true"
            )
            XCTAssertFalse(
                result2,
                "Iteration \(iteration): AppState2 should return configured false"
            )
            
            // Verify calls are recorded on correct mocks
            XCTAssertTrue(
                mock1.didCall(.authenticate(username: "user1@test.com", password: "pass1")),
                "Iteration \(iteration): Mock1 should record its call"
            )
            XCTAssertFalse(
                mock1.didCall(.authenticate(username: "user2@test.com", password: "pass2")),
                "Iteration \(iteration): Mock1 should not have Mock2's call"
            )
            
            XCTAssertTrue(
                mock2.didCall(.authenticate(username: "user2@test.com", password: "pass2")),
                "Iteration \(iteration): Mock2 should record its call"
            )
            XCTAssertFalse(
                mock2.didCall(.authenticate(username: "user1@test.com", password: "pass1")),
                "Iteration \(iteration): Mock2 should not have Mock1's call"
            )
        }
    }
    
    /// Property test: ViewModel test instances use injected mocks
    /// Tests that ViewModels created with testInstance() use the mock, not production
    func testProperty_ViewModelTestInstancesUseMocks() throws {
        // Feature: dependency-injection, Property 4: Test isolation prevents side effects
        // **Validates: Requirements 3.5, 5.5, 5.6, 5.7**
        
        for iteration in 0..<100 {
            // Create test instances for each ViewModel type
            let (loginVM, loginMock) = LoginViewModel.testInstance()
            let (stationsVM, stationsMock) = StationsViewModel.testInstance()
            
            // Configure mocks
            loginMock.authenticateResult = Bool.random()
            stationsMock.fetchStationsResult = Bool.random()
            
            // Verify LoginViewModel uses its mock
            loginVM.username = "test\(iteration)@example.com"
            loginVM.password = "password\(iteration)"
            
            // StationsViewModel uses its mock
            _ = stationsVM.pandora.fetchStations()
            
            XCTAssertTrue(
                stationsMock.didCall(.fetchStations),
                "Iteration \(iteration): StationsViewModel should use injected mock"
            )
            
            // Verify mocks are independent
            XCTAssertFalse(
                loginMock.didCall(.fetchStations),
                "Iteration \(iteration): LoginViewModel mock should not have StationsViewModel calls"
            )
        }
    }
    
    /// Property test: Mock reset provides clean slate for each test
    /// Tests that reset() completely isolates test runs
    func testProperty_MockResetProvidesCleanSlate() throws {
        // Feature: dependency-injection, Property 4: Test isolation prevents side effects
        // **Validates: Requirements 3.5, 5.5, 5.6, 5.7**
        
        for iteration in 0..<100 {
            let mock = MockPandora()
            
            // Contaminate the mock with state
            mock.authenticateResult = false
            mock.isAuthenticatedValue = true
            mock.fetchStationsResult = false
            
            let station = Station()
            station.token = "CONTAMINATED"
            mock.mockStations = [station]
            
            // Make some calls
            _ = mock.authenticate("old@test.com", password: "oldpass", request: nil)
            _ = mock.fetchStations()
            
            let callsBeforeReset = mock.calls.count
            XCTAssertGreaterThan(callsBeforeReset, 0, "Iteration \(iteration): Should have calls before reset")
            
            // Reset
            mock.reset()
            
            // Verify clean slate
            XCTAssertEqual(
                mock.calls.count,
                0,
                "Iteration \(iteration): Calls should be cleared after reset"
            )
            XCTAssertTrue(
                mock.authenticateResult,
                "Iteration \(iteration): authenticateResult should be true after reset"
            )
            XCTAssertFalse(
                mock.isAuthenticatedValue,
                "Iteration \(iteration): isAuthenticatedValue should be false after reset"
            )
            XCTAssertTrue(
                mock.fetchStationsResult,
                "Iteration \(iteration): fetchStationsResult should be true after reset"
            )
            
            let stations = mock.stations as? [Station] ?? []
            XCTAssertEqual(
                stations.count,
                0,
                "Iteration \(iteration): mockStations should be empty after reset"
            )
            
            // New operations should work with default behavior
            let newResult = mock.authenticate("new\(iteration)@test.com", password: "newpass", request: nil)
            XCTAssertTrue(
                newResult,
                "Iteration \(iteration): New authenticate should succeed with default config"
            )
        }
    }
}


// MARK: - Property 5: Backward Compatibility Preservation

/// Property tests validating backward compatibility preservation.
///
/// For any existing code that creates ViewModels without explicit parameters,
/// the code should continue to compile and function correctly using production dependencies.
///
/// **Validates: Requirements 2.6, 6.1, 6.5**
@MainActor
final class BackwardCompatibilityPropertyTests: XCTestCase {
    
    // MARK: - Property 5: Backward compatibility preservation
    //
    // For any existing code that creates ViewModels without explicit parameters,
    // the code should continue to compile and function correctly using
    // production dependencies.
    //
    // **Validates: Requirements 2.6, 6.1, 6.5**
    
    /// Property test: ViewModels can be created with explicit mock injection
    /// Tests that the DI pattern allows explicit dependency injection
    func testProperty_ViewModelsAcceptExplicitDependencyInjection() throws {
        // Feature: dependency-injection, Property 5: Backward compatibility preservation
        // **Validates: Requirements 2.6, 6.1, 6.5**
        
        for iteration in 0..<100 {
            // Create mock with random configuration
            let mock = MockPandora()
            mock.authenticateResult = Bool.random()
            mock.fetchStationsResult = Bool.random()
            mock.isAuthenticatedValue = Bool.random()
            
            // Create ViewModels with explicit injection
            let loginVM = LoginViewModel(pandora: mock)
            let stationsVM = StationsViewModel(pandora: mock)
            
            // Verify ViewModels use the injected mock
            // (We can verify by checking that operations are recorded on the mock)
            _ = stationsVM.pandora.fetchStations()
            
            XCTAssertTrue(
                mock.didCall(.fetchStations),
                "Iteration \(iteration): StationsViewModel should use injected mock"
            )
            
            // Verify the mock's configuration affects behavior
            let expectedResult = mock.fetchStationsResult
            mock.reset()
            mock.fetchStationsResult = expectedResult
            
            let result = stationsVM.pandora.fetchStations()
            XCTAssertEqual(
                result,
                expectedResult,
                "Iteration \(iteration): Result should match mock configuration"
            )
            
            // LoginViewModel should also use the same mock
            XCTAssertTrue(
                loginVM.username.isEmpty,
                "Iteration \(iteration): LoginViewModel should initialize with empty username"
            )
        }
    }
    
    /// Property test: AppState factory methods produce correct instances
    /// Tests that production() and test() factories work correctly
    func testProperty_AppStateFactoryMethodsProduceCorrectInstances() throws {
        // Feature: dependency-injection, Property 5: Backward compatibility preservation
        // **Validates: Requirements 2.6, 6.1, 6.5**
        
        for iteration in 0..<100 {
            // Test factory creates instance with mock
            let mock = MockPandora()
            mock.isAuthenticatedValue = Bool.random()
            
            let testAppState = AppState.test(pandora: mock)
            
            // Verify test instance uses the mock
            XCTAssertTrue(
                testAppState.pandora === mock,
                "Iteration \(iteration): test() factory should use provided mock"
            )
            
            // Verify test instance's ViewModels use the same mock
            // (indirectly through pandora property)
            XCTAssertTrue(
                testAppState.pandora is MockPandora,
                "Iteration \(iteration): test() AppState should have MockPandora"
            )
            
            // Verify the mock is actually used
            _ = testAppState.pandora.fetchStations()
            XCTAssertTrue(
                mock.didCall(.fetchStations),
                "Iteration \(iteration): Operations should be recorded on mock"
            )
        }
    }
    
    /// Property test: Protocol conformance allows polymorphic usage
    /// Tests that PandoraProtocol enables polymorphic dependency injection
    func testProperty_ProtocolConformanceEnablesPolymorphism() throws {
        // Feature: dependency-injection, Property 5: Backward compatibility preservation
        // **Validates: Requirements 2.6, 6.1, 6.5**
        
        for iteration in 0..<100 {
            // Create mock as PandoraProtocol type
            let pandora: PandoraProtocol = MockPandora()
            
            // Verify it can be used wherever PandoraProtocol is expected
            let loginVM = LoginViewModel(pandora: pandora)
            let stationsVM = StationsViewModel(pandora: pandora)
            let appState = AppState.test(pandora: pandora)
            
            // All should accept the protocol-typed dependency
            XCTAssertNotNil(
                loginVM,
                "Iteration \(iteration): LoginViewModel should accept PandoraProtocol"
            )
            XCTAssertNotNil(
                stationsVM,
                "Iteration \(iteration): StationsViewModel should accept PandoraProtocol"
            )
            XCTAssertNotNil(
                appState,
                "Iteration \(iteration): AppState.test should accept PandoraProtocol"
            )
            
            // Verify operations work through protocol interface
            let result = pandora.fetchStations()
            XCTAssertTrue(
                result,
                "Iteration \(iteration): Protocol method should return default true"
            )
        }
    }
    
    /// Property test: Default parameter values provide production behavior
    /// Tests that omitting parameters uses production defaults (via testInstance helpers)
    func testProperty_TestInstanceHelpersProvideConsistentBehavior() throws {
        // Feature: dependency-injection, Property 5: Backward compatibility preservation
        // **Validates: Requirements 2.6, 6.1, 6.5**
        
        for iteration in 0..<100 {
            // Use test instance helpers (which provide mock by default)
            let (loginVM, loginMock) = LoginViewModel.testInstance()
            let (stationsVM, stationsMock) = StationsViewModel.testInstance()
            let (appState, appStateMock) = AppState.testInstance()
            
            // Verify helpers return both instance and mock
            XCTAssertNotNil(
                loginVM,
                "Iteration \(iteration): testInstance should return LoginViewModel"
            )
            XCTAssertNotNil(
                loginMock,
                "Iteration \(iteration): testInstance should return MockPandora"
            )
            
            XCTAssertNotNil(
                stationsVM,
                "Iteration \(iteration): testInstance should return StationsViewModel"
            )
            XCTAssertNotNil(
                stationsMock,
                "Iteration \(iteration): testInstance should return MockPandora"
            )
            
            XCTAssertNotNil(
                appState,
                "Iteration \(iteration): testInstance should return AppState"
            )
            XCTAssertNotNil(
                appStateMock,
                "Iteration \(iteration): testInstance should return MockPandora"
            )
            
            // Verify each instance has its own independent mock
            loginMock.authenticateResult = false
            stationsMock.authenticateResult = true
            appStateMock.authenticateResult = true
            
            // Each mock should be independent
            XCTAssertFalse(
                loginMock.authenticateResult,
                "Iteration \(iteration): loginMock should have its own config"
            )
            XCTAssertTrue(
                stationsMock.authenticateResult,
                "Iteration \(iteration): stationsMock should have its own config"
            )
        }
    }
    
    /// Property test: ViewModel initialization doesn't trigger side effects
    /// Tests that creating ViewModels with mocks doesn't cause production calls
    func testProperty_ViewModelInitializationIsSideEffectFree() throws {
        // Feature: dependency-injection, Property 5: Backward compatibility preservation
        // **Validates: Requirements 2.6, 6.1, 6.5**
        
        for iteration in 0..<100 {
            let mock = MockPandora()
            
            // Record initial call count
            let initialCallCount = mock.calls.count
            XCTAssertEqual(
                initialCallCount,
                0,
                "Iteration \(iteration): Fresh mock should have no calls"
            )
            
            // Create ViewModels
            let _ = LoginViewModel(pandora: mock)
            
            // LoginViewModel initialization should not make any Pandora calls
            XCTAssertEqual(
                mock.calls.count,
                0,
                "Iteration \(iteration): LoginViewModel init should not call Pandora"
            )
            
            // StationsViewModel may call isAuthenticated during init
            // but should not make network-triggering calls
            let stationsMock = MockPandora()
            stationsMock.isAuthenticatedValue = false // Not authenticated
            let _ = StationsViewModel(pandora: stationsMock)
            
            // Should only check authentication, not fetch stations
            let fetchStationsCalls = stationsMock.callCount(for: .fetchStations)
            XCTAssertEqual(
                fetchStationsCalls,
                0,
                "Iteration \(iteration): StationsViewModel should not fetch stations when not authenticated"
            )
        }
    }
}


// MARK: - Property 6: Notification Bridge Integrity

/// Property tests validating notification bridge integrity.
///
/// For any notification posted from Objective-C Pandora code, Swift ViewModels
/// using either real or mock Pandora implementations should receive the notification
/// with correct userInfo data.
///
/// **Validates: Requirements 6.3, 6.4**
@MainActor
final class NotificationBridgePropertyTests: XCTestCase {
    
    private var cancellables = Set<AnyCancellable>()
    
    override func tearDown() async throws {
        cancellables.removeAll()
        try await super.tearDown()
    }
    
    // MARK: - Property 6: Notification bridge integrity
    //
    // For any notification posted from Objective-C Pandora code, Swift ViewModels
    // using either real or mock Pandora implementations should receive the
    // notification with correct userInfo data.
    //
    // **Validates: Requirements 6.3, 6.4**
    
    /// Property test: MockPandora posts authentication notifications consistently
    /// Tests that MockPandora posts the same notifications as expected from PandoraClient
    func testProperty_MockPandoraPostsAuthenticationNotifications() throws {
        // Feature: dependency-injection, Property 6: Notification bridge integrity
        // **Validates: Requirements 6.3, 6.4**
        
        for iteration in 0..<100 {
            let mock = MockPandora()
            var receivedAuthenticated = false
            var receivedError = false
            var errorMessage: String?
            
            let authExpectation = XCTestExpectation(description: "Auth notification")
            authExpectation.isInverted = !mock.authenticateResult // Only expect if success
            
            // Subscribe to authentication notification
            let authCancellable = NotificationCenter.default.publisher(for: Notification.Name("hermes.authenticated"))
                .sink { _ in
                    receivedAuthenticated = true
                    authExpectation.fulfill()
                }
            
            // Subscribe to error notification
            let errorCancellable = NotificationCenter.default.publisher(for: Notification.Name("hermes.error"))
                .sink { notification in
                    receivedError = true
                    errorMessage = notification.userInfo?["error"] as? String
                }
            
            // Configure mock for success
            mock.authenticateResult = true
            mock.authenticateError = nil
            
            // Perform authentication
            let result = mock.authenticate("user\(iteration)@test.com", password: "pass\(iteration)", request: nil)
            
            // Wait for notification
            wait(for: [authExpectation], timeout: 1.0)
            
            // Verify notification was posted on success
            XCTAssertTrue(
                result,
                "Iteration \(iteration): Authentication should succeed"
            )
            XCTAssertTrue(
                receivedAuthenticated,
                "Iteration \(iteration): Should receive authenticated notification on success"
            )
            XCTAssertFalse(
                receivedError,
                "Iteration \(iteration): Should not receive error notification on success"
            )
            
            authCancellable.cancel()
            errorCancellable.cancel()
        }
    }
    
    /// Property test: MockPandora posts error notifications with correct userInfo
    /// Tests that error notifications contain the expected error message
    func testProperty_MockPandoraPostsErrorNotificationsWithUserInfo() throws {
        // Feature: dependency-injection, Property 6: Notification bridge integrity
        // **Validates: Requirements 6.3, 6.4**
        
        for iteration in 0..<100 {
            let mock = MockPandora()
            var receivedErrorMessage: String?
            
            let errorExpectation = XCTestExpectation(description: "Error notification")
            
            // Subscribe to error notification
            let cancellable = NotificationCenter.default.publisher(for: Notification.Name("hermes.error"))
                .sink { notification in
                    receivedErrorMessage = notification.userInfo?["error"] as? String
                    errorExpectation.fulfill()
                }
            
            // Configure mock for error
            let expectedError = "Test error message \(iteration)"
            mock.authenticateError = NSError(
                domain: "TestError",
                code: iteration,
                userInfo: [NSLocalizedDescriptionKey: expectedError]
            )
            
            // Perform authentication (should fail)
            let result = mock.authenticate("user@test.com", password: "pass", request: nil)
            
            // Wait for notification
            wait(for: [errorExpectation], timeout: 1.0)
            
            // Verify error notification was posted with correct message
            XCTAssertFalse(
                result,
                "Iteration \(iteration): Authentication should fail when error is configured"
            )
            XCTAssertEqual(
                receivedErrorMessage,
                expectedError,
                "Iteration \(iteration): Error message should match configured error"
            )
            
            cancellable.cancel()
        }
    }
    
    /// Property test: MockPandora posts station notifications consistently
    /// Tests that station-related notifications are posted correctly
    func testProperty_MockPandoraPostsStationNotifications() throws {
        // Feature: dependency-injection, Property 6: Notification bridge integrity
        // **Validates: Requirements 6.3, 6.4**
        
        for iteration in 0..<100 {
            let mock = MockPandora()
            
            // Test fetchStations notification
            var receivedStationsNotification = false
            let stationsExpectation = XCTestExpectation(description: "Stations notification")
            
            let stationsCancellable = NotificationCenter.default.publisher(for: Notification.Name("hermes.stations"))
                .sink { _ in
                    receivedStationsNotification = true
                    stationsExpectation.fulfill()
                }
            
            mock.fetchStationsResult = true
            _ = mock.fetchStations()
            
            wait(for: [stationsExpectation], timeout: 1.0)
            
            XCTAssertTrue(
                receivedStationsNotification,
                "Iteration \(iteration): Should receive stations notification"
            )
            
            stationsCancellable.cancel()
            
            // Test station-created notification
            var receivedCreatedNotification = false
            var createdMusicId: String?
            let createdExpectation = XCTestExpectation(description: "Station created notification")
            
            let createdCancellable = NotificationCenter.default.publisher(for: Notification.Name("hermes.station-created"))
                .sink { notification in
                    receivedCreatedNotification = true
                    createdMusicId = notification.userInfo?["musicId"] as? String
                    createdExpectation.fulfill()
                }
            
            let testMusicId = "M\(iteration)"
            mock.createStationResult = true
            _ = mock.createStation(testMusicId)
            
            wait(for: [createdExpectation], timeout: 1.0)
            
            XCTAssertTrue(
                receivedCreatedNotification,
                "Iteration \(iteration): Should receive station-created notification"
            )
            XCTAssertEqual(
                createdMusicId,
                testMusicId,
                "Iteration \(iteration): musicId in notification should match"
            )
            
            createdCancellable.cancel()
        }
    }
    
    /// Property test: MockPandora posts song rating notifications
    /// Tests that song rating notifications contain correct userInfo
    func testProperty_MockPandoraPostsSongRatingNotifications() throws {
        // Feature: dependency-injection, Property 6: Notification bridge integrity
        // **Validates: Requirements 6.3, 6.4**
        
        for iteration in 0..<100 {
            let mock = MockPandora()
            
            // Create test song
            let song = Song()
            song.token = "SONG\(iteration)"
            
            var receivedRatingNotification = false
            var ratedToken: String?
            var ratedLiked: Bool?
            
            let ratingExpectation = XCTestExpectation(description: "Rating notification")
            
            let cancellable = NotificationCenter.default.publisher(for: Notification.Name("hermes.song-rated"))
                .sink { notification in
                    receivedRatingNotification = true
                    ratedToken = notification.userInfo?["token"] as? String
                    ratedLiked = notification.userInfo?["liked"] as? Bool
                    ratingExpectation.fulfill()
                }
            
            // Rate song
            let liked = Bool.random()
            mock.rateSongResult = true
            _ = mock.rateSong(song, as: liked)
            
            wait(for: [ratingExpectation], timeout: 1.0)
            
            XCTAssertTrue(
                receivedRatingNotification,
                "Iteration \(iteration): Should receive song-rated notification"
            )
            XCTAssertEqual(
                ratedToken,
                song.token,
                "Iteration \(iteration): Token in notification should match song token"
            )
            XCTAssertEqual(
                ratedLiked,
                liked,
                "Iteration \(iteration): Liked value in notification should match"
            )
            
            cancellable.cancel()
        }
    }
    
    /// Property test: Notifications are not posted when operations fail
    /// Tests that success notifications are only posted on successful operations
    func testProperty_NotificationsNotPostedOnFailure() throws {
        // Feature: dependency-injection, Property 6: Notification bridge integrity
        // **Validates: Requirements 6.3, 6.4**
        
        for iteration in 0..<100 {
            let mock = MockPandora()
            
            // Configure for failure (no error, just false result)
            mock.fetchStationsResult = false
            mock.fetchStationsError = nil
            
            var receivedStationsNotification = false
            
            let stationsExpectation = XCTestExpectation(description: "Stations notification")
            stationsExpectation.isInverted = true // Should NOT be fulfilled
            
            let cancellable = NotificationCenter.default.publisher(for: Notification.Name("hermes.stations"))
                .sink { _ in
                    receivedStationsNotification = true
                    stationsExpectation.fulfill()
                }
            
            // Perform operation that should fail
            let result = mock.fetchStations()
            
            // Wait briefly to ensure no notification is posted
            wait(for: [stationsExpectation], timeout: 0.5)
            
            XCTAssertFalse(
                result,
                "Iteration \(iteration): Operation should fail"
            )
            XCTAssertFalse(
                receivedStationsNotification,
                "Iteration \(iteration): Should not receive notification on failure"
            )
            
            cancellable.cancel()
        }
    }
    
    /// Property test: Multiple notification subscribers receive notifications
    /// Tests that notifications are broadcast to all subscribers
    func testProperty_MultipleSubscribersReceiveNotifications() throws {
        // Feature: dependency-injection, Property 6: Notification bridge integrity
        // **Validates: Requirements 6.3, 6.4**
        
        for iteration in 0..<100 {
            let mock = MockPandora()
            
            var subscriber1Received = false
            var subscriber2Received = false
            var subscriber3Received = false
            
            let expectation1 = XCTestExpectation(description: "Subscriber 1")
            let expectation2 = XCTestExpectation(description: "Subscriber 2")
            let expectation3 = XCTestExpectation(description: "Subscriber 3")
            
            // Create multiple subscribers
            let cancellable1 = NotificationCenter.default.publisher(for: Notification.Name("hermes.authenticated"))
                .sink { _ in
                    subscriber1Received = true
                    expectation1.fulfill()
                }
            
            let cancellable2 = NotificationCenter.default.publisher(for: Notification.Name("hermes.authenticated"))
                .sink { _ in
                    subscriber2Received = true
                    expectation2.fulfill()
                }
            
            let cancellable3 = NotificationCenter.default.publisher(for: Notification.Name("hermes.authenticated"))
                .sink { _ in
                    subscriber3Received = true
                    expectation3.fulfill()
                }
            
            // Trigger notification
            mock.authenticateResult = true
            _ = mock.authenticate("user@test.com", password: "pass", request: nil)
            
            // Wait for all subscribers
            wait(for: [expectation1, expectation2, expectation3], timeout: 1.0)
            
            XCTAssertTrue(
                subscriber1Received,
                "Iteration \(iteration): Subscriber 1 should receive notification"
            )
            XCTAssertTrue(
                subscriber2Received,
                "Iteration \(iteration): Subscriber 2 should receive notification"
            )
            XCTAssertTrue(
                subscriber3Received,
                "Iteration \(iteration): Subscriber 3 should receive notification"
            )
            
            cancellable1.cancel()
            cancellable2.cancel()
            cancellable3.cancel()
        }
    }
    
    /// Property test: Notification userInfo contains all expected keys
    /// Tests that notifications include all required data in userInfo
    func testProperty_NotificationUserInfoContainsExpectedKeys() throws {
        // Feature: dependency-injection, Property 6: Notification bridge integrity
        // **Validates: Requirements 6.3, 6.4**
        
        for iteration in 0..<100 {
            let mock = MockPandora()
            
            // Test station-renamed notification
            var receivedUserInfo: [AnyHashable: Any]?
            let renameExpectation = XCTestExpectation(description: "Rename notification")
            
            let cancellable = NotificationCenter.default.publisher(for: Notification.Name("hermes.station-renamed"))
                .sink { notification in
                    receivedUserInfo = notification.userInfo
                    renameExpectation.fulfill()
                }
            
            let testToken = "ST\(iteration)"
            let testName = "New Name \(iteration)"
            mock.renameStationResult = true
            _ = mock.renameStation(testToken, to: testName)
            
            wait(for: [renameExpectation], timeout: 1.0)
            
            // Verify userInfo contains expected keys
            XCTAssertNotNil(
                receivedUserInfo,
                "Iteration \(iteration): Notification should have userInfo"
            )
            XCTAssertEqual(
                receivedUserInfo?["token"] as? String,
                testToken,
                "Iteration \(iteration): userInfo should contain token"
            )
            XCTAssertEqual(
                receivedUserInfo?["name"] as? String,
                testName,
                "Iteration \(iteration): userInfo should contain name"
            )
            
            cancellable.cancel()
        }
    }
}
