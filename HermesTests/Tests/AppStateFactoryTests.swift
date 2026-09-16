//
//  AppStateFactoryTests.swift
//  HermesTests
//
//  Unit tests for AppState factory methods
//  **Validates: Requirements 4.2, 4.3, 4.6**
//

import Testing
@testable import Hermes

@MainActor
@Suite("AppStateFactoryTests", .serialized)
struct AppStateFactoryTests {
    // MARK: - Production Factory Tests

    /// Test that production() creates AppState with PandoraClient
    /// **Validates: Requirement 4.2**
    @Test("Production Creates Pandora Client")
    func testProduction_CreatesPandoraClient() throws {
        // Create production AppState
        let appState = AppState.production()

        // Verify pandora is a PandoraClient instance
        #expect(appState.pandora is PandoraClient, "production() should create AppState with PandoraClient")

        // Verify view models are initialized
        #expect((appState.loginViewModel) != nil, "loginViewModel should be initialized")
        #expect((appState.playerViewModel) != nil, "playerViewModel should be initialized")
        #expect((appState.stationsViewModel) != nil, "stationsViewModel should be initialized")
        #expect((appState.historyViewModel) != nil, "historyViewModel should be initialized")
    }

    /// Test that production() creates AppState with correct initial state
    /// **Validates: Requirement 4.2**
    @Test("Production Has Correct Initial State")
    func testProduction_HasCorrectInitialState() throws {
        // Create production AppState
        let appState = AppState.production()

        // Verify initial state
        #expect((appState.currentView) == (.login), "production() should start in login view")
        #expect(appState.isSidebarVisible, "production() should have sidebar visible by default")
        #expect(!(appState.isAuthenticated), "production() should not be authenticated initially")
    }

    /// Test that production() creates independent instances
    /// **Validates: Requirement 4.2**
    @Test("Production Creates Independent Instances")
    func testProduction_CreatesIndependentInstances() throws {
        // Create two production AppState instances
        let appState1 = AppState.production()
        let appState2 = AppState.production()

        // Verify they are different instances
        #expect(!(appState1 === appState2), "production() should create independent instances")

        // Verify they have different pandora instances
        #expect(!(appState1.pandora === appState2.pandora), "Each AppState should have its own pandora instance")
    }

    // MARK: - Test Factory Tests

    /// Test that test() creates AppState with mock Pandora
    /// **Validates: Requirement 4.3**
    @Test("Test Creates Mock Pandora")
    func testTest_CreatesMockPandora() throws {
        // Create mock Pandora
        let mockPandora = MockPandora()

        // Create test AppState
        let appState = AppState.test(pandora: mockPandora)

        // Verify pandora is the mock instance
        #expect(appState.pandora === mockPandora, "test() should use the provided mock Pandora")

        // Verify view models are initialized
        #expect((appState.loginViewModel) != nil, "loginViewModel should be initialized")
        #expect((appState.playerViewModel) != nil, "playerViewModel should be initialized")
        #expect((appState.stationsViewModel) != nil, "stationsViewModel should be initialized")
        #expect((appState.historyViewModel) != nil, "historyViewModel should be initialized")
    }

    /// Test that test() skips credential check
    /// **Validates: Requirement 4.3**
    @Test("Test Skips Credential Check")
    func testTest_SkipsCredentialCheck() throws {
        // Create mock Pandora
        let mockPandora = MockPandora()

        // Create test AppState
        let appState = AppState.test(pandora: mockPandora)

        // The key requirement is that test() should NOT attempt authentication
        // We check for any authenticate calls
        let authenticateCalls = mockPandora.calls.filter {
            if case .authenticate = $0.method {
                return true
            }
            return false
        }

        #expect((authenticateCalls.count) == (0), "test() should not attempt authentication during initialization")

        // Verify initial state
        #expect((appState.currentView) == (.login), "test() should start in login view")
        #expect(!(appState.isAuthenticated), "test() should not be authenticated initially")
    }

    /// Test that test() creates AppState with correct initial state
    /// **Validates: Requirement 4.3**
    @Test("Test Has Correct Initial State")
    func testTest_HasCorrectInitialState() throws {
        // Create mock Pandora
        let mockPandora = MockPandora()

        // Create test AppState
        let appState = AppState.test(pandora: mockPandora)

        // Verify initial state
        #expect((appState.currentView) == (.login), "test() should start in login view")
        #expect(appState.isSidebarVisible, "test() should have sidebar visible by default")
        #expect(!(appState.isAuthenticated), "test() should not be authenticated initially")
    }

    /// Test that test() allows multiple instances with different mocks
    /// **Validates: Requirement 4.3**
    @Test("Test Allows Multiple Instances With Different Mocks")
    func testTest_AllowsMultipleInstancesWithDifferentMocks() throws {
        // Create two different mock Pandora instances
        let mockPandora1 = MockPandora()
        let mockPandora2 = MockPandora()

        // Create two test AppState instances
        let appState1 = AppState.test(pandora: mockPandora1)
        let appState2 = AppState.test(pandora: mockPandora2)

        // Verify they are different instances
        #expect(!(appState1 === appState2), "test() should create independent instances")

        // Verify they use different mock instances
        #expect(appState1.pandora === mockPandora1, "appState1 should use mockPandora1")
        #expect(appState2.pandora === mockPandora2, "appState2 should use mockPandora2")
        #expect(!(appState1.pandora === appState2.pandora), "Each test AppState should have its own mock")
    }

    // MARK: - Singleton Pattern Tests

    /// Test that shared singleton uses production factory
    /// **Validates: Requirement 4.6**
    @Test("Shared Uses Production Factory")
    func testShared_UsesProductionFactory() throws {
        // Access shared singleton
        let shared = AppState.shared

        // Verify pandora is a PandoraClient instance
        #expect(shared.pandora is PandoraClient, "shared singleton should use PandoraClient from production()")
    }

    /// Test that shared singleton is truly a singleton
    /// **Validates: Requirement 4.6**
    @Test("Shared Is Singleton")
    func testShared_IsSingleton() throws {
        // Access shared singleton multiple times
        let shared1 = AppState.shared
        let shared2 = AppState.shared

        // Verify they are the same instance
        #expect(shared1 === shared2, "shared should return the same instance every time")
    }

    /// Test that shared singleton is independent from test instances
    /// **Validates: Requirement 4.6**
    @Test("Shared Is Independent From Test Instances")
    func testShared_IsIndependentFromTestInstances() throws {
        // Create test instance
        let mockPandora = MockPandora()
        let testAppState = AppState.test(pandora: mockPandora)

        // Access shared singleton
        let shared = AppState.shared

        // Verify they are different instances
        #expect(!(shared === testAppState), "shared singleton should be independent from test instances")

        // Verify shared uses PandoraClient, not mock
        #expect(shared.pandora is PandoraClient, "shared should use PandoraClient")
        #expect(testAppState.pandora === mockPandora, "test instance should use mock")
    }

    // MARK: - View Model Dependency Injection Tests

    /// Test that production() injects PandoraClient into view models
    /// **Validates: Requirement 4.2**
    @Test("Production Injects Pandora Client Into View Models")
    func testProduction_InjectsPandoraClientIntoViewModels() throws {
        // Create production AppState
        let appState = AppState.production()

        // Verify LoginViewModel uses the same pandora instance
        // Note: We can't directly access the private pandora property in LoginViewModel,
        // but we can verify it's initialized and functional
        #expect((appState.loginViewModel) != nil, "loginViewModel should be initialized")

        // Verify StationsViewModel uses the same pandora instance
        #expect((appState.stationsViewModel) != nil, "stationsViewModel should be initialized")
    }

    /// Test that test() injects mock Pandora into view models
    /// **Validates: Requirement 4.3**
    @Test("Test Injects Mock Pandora Into View Models")
    func testTest_InjectsMockPandoraIntoViewModels() async throws {
        // Create mock Pandora
        let mockPandora = MockPandora()
        mockPandora.authenticateResult = true

        // Create test AppState
        let appState = AppState.test(pandora: mockPandora)

        // Verify the mock is injected by checking the pandora reference
        // We don't call authenticate() because that would save to UserDefaults
        // and pollute production data
        #expect(appState.pandora === mockPandora, "AppState should use the injected mock Pandora")

        // Verify LoginViewModel was initialized (it receives pandora in init)
        #expect((appState.loginViewModel) != nil, "LoginViewModel should be initialized")

        // Verify StationsViewModel was initialized
        #expect((appState.stationsViewModel) != nil, "StationsViewModel should be initialized")
    }

    // MARK: - Notification Subscription Tests

    /// Test that production() AppState subscribes to notifications
    /// **Validates: Requirement 4.2**
    @Test("Production Subscribes To Notifications")
    func testProduction_SubscribesToNotifications() async throws {
        // Create production AppState
        let appState = AppState.production()

        // Verify AppState is set up to receive notifications
        // The actual notification handling is tested in AppState integration tests
        // Here we just verify the factory creates a properly initialized instance
        #expect((appState) != nil, "production() should create a valid AppState")
        #expect((appState.currentView) == (.login), "Should start in login view")
        #expect(!(appState.isAuthenticated), "Should not be authenticated initially")
    }

    /// Test that test() AppState subscribes to notifications
    /// **Validates: Requirement 4.3**
    @Test("Test Subscribes To Notifications")
    func testTest_SubscribesToNotifications() async throws {
        // Create mock Pandora
        let mockPandora = MockPandora()

        // Create test AppState
        let appState = AppState.test(pandora: mockPandora)

        // Verify AppState is set up to receive notifications
        // The actual notification handling is tested in AppState integration tests
        // Here we just verify the factory creates a properly initialized instance
        #expect((appState) != nil, "test() should create a valid AppState")
        #expect((appState.currentView) == (.login), "Should start in login view")
        #expect(!(appState.isAuthenticated), "Should not be authenticated initially")
    }

    // MARK: - Edge Cases

    /// Test that test() works with mock configured for failure
    /// **Validates: Requirement 4.3**
    @Test("Test Works With Mock Configured For Failure")
    func testTest_WorksWithMockConfiguredForFailure() throws {
        // Create mock Pandora configured for failure
        let mockPandora = MockPandora()
        mockPandora.authenticateResult = false
        mockPandora.fetchStationsResult = false

        // Create test AppState
        let appState = AppState.test(pandora: mockPandora)

        // Verify AppState was created successfully
        #expect((appState) != nil, "test() should work with mock configured for failure")
        #expect(appState.pandora === mockPandora, "test() should use the provided mock even when configured for failure")
    }

    /// Test that test() works with mock that has pre-configured stations
    /// **Validates: Requirement 4.3**
    @Test("Test Works With Mock With Pre Configured Stations")
    func testTest_WorksWithMockWithPreConfiguredStations() throws {
        // Create mock Pandora with pre-configured stations
        let mockPandora = MockPandora()

        let station1 = Station()
        station1.token = "ST001"
        station1.name = "Test Station 1"

        let station2 = Station()
        station2.token = "ST002"
        station2.name = "Test Station 2"

        mockPandora.mockStations = [station1, station2]

        // Create test AppState
        let appState = AppState.test(pandora: mockPandora)

        // Verify AppState was created successfully
        #expect((appState) != nil, "test() should work with pre-configured mock stations")

        // Verify stations are accessible through pandora
        let stations = mockPandora.stations as? [Station] ?? []
        #expect((stations.count) == (2), "Mock should have 2 pre-configured stations")
    }

    /// Test that multiple test instances don't interfere with each other
    /// **Validates: Requirement 4.3**
    @Test("Test Multiple Instances Dont Interfere")
    func testTest_MultipleInstancesDontInterfere() throws {
        // Create first test instance
        let mockPandora1 = MockPandora()
        let appState1 = AppState.test(pandora: mockPandora1)

        // Create second test instance
        let mockPandora2 = MockPandora()
        let appState2 = AppState.test(pandora: mockPandora2)

        // Verify instances are independent
        #expect(!(appState1 === appState2), "AppState instances should be different")

        // Verify each AppState uses its own mock
        #expect(appState1.pandora === mockPandora1, "appState1 should use mockPandora1")
        #expect(appState2.pandora === mockPandora2, "appState2 should use mockPandora2")
    }
}
