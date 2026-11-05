//
//  AppStateFactoryTests.swift
//  HermesTests
//
//  Unit tests for AppState factory methods
//  **Validates: Requirements 4.2, 4.3, 4.6**
//

import AppKit
import Foundation
import Security
import SwiftUI
import Testing
@testable import Hermes

@MainActor
@Suite("AppStateFactoryTests", .serialized)
struct AppStateFactoryTests {
    // MARK: - Production Factory Tests

    private func sourceRepositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Test that production() creates AppState with PandoraClient
    /// **Validates: Requirement 4.2**
    @Test("Production Creates Pandora Client")
    func testProduction_CreatesPandoraClient() throws {
        // Create production AppState
        let appState = AppState.production()

        // Verify pandora is a PandoraClient instance
        #expect(appState.pandora is PandoraClient, "production() should create AppState with PandoraClient")
        #expect(!appState.loginViewModel.isLoading, "loginViewModel should start idle")
        #expect(appState.loginViewModel.errorMessage == nil, "loginViewModel should start without an error")
        #expect(appState.playerViewModel.currentSong == nil, "playerViewModel should start without a song")
        #expect(!appState.playerViewModel.isPlaying, "playerViewModel should start stopped")
        #expect(appState.stationsViewModel.stations.isEmpty, "stationsViewModel should start without stations")
        #expect(appState.historyViewModel.historyItems.isEmpty, "historyViewModel should start without history")
    }

    @Test("Locally signed Debug host uses an identity-based designated requirement")
    func locallySignedDebugHostUsesIdentityBasedDesignatedRequirement() throws {
        let repositoryRoot = sourceRepositoryRoot()
        let localSigningConfig = repositoryRoot
            .appendingPathComponent("Config")
            .appendingPathComponent("DebugSigning.local.xcconfig")
        guard FileManager.default.fileExists(atPath: localSigningConfig.path) else {
            return
        }

        let hostBundle = Bundle(for: AppState.self)
        let hostExecutable = try #require(hostBundle.executableURL)
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-d", "-r-", hostExecutable.path]
        process.standardOutput = output
        process.standardError = output

        try process.run()
        process.waitUntilExit()

        let requirement = String(
            data: output.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        #expect(process.terminationStatus == 0)
        #expect(requirement.contains("designated =>"))
        #expect(requirement.contains("anchor apple generic"))
        #expect(!requirement.localizedCaseInsensitiveContains("cdhash"))
    }

    @Test("Debug signing identifiers stay out of the committed project file")
    func debugSigningIdentifiersStayOutOfCommittedProjectFile() throws {
        let projectFile = sourceRepositoryRoot()
            .appendingPathComponent("Hermes.xcodeproj")
            .appendingPathComponent("project.pbxproj")
        let projectContents = try String(contentsOf: projectFile, encoding: .utf8)

        let settingsLines = projectContents.split(whereSeparator: \.isNewline)
        let nonEmptyTeamAssignments = settingsLines.filter { line in
            guard line.contains("DEVELOPMENT_TEAM"),
                  let equalsIndex = line.lastIndex(of: "=") else {
                return false
            }
            let value = line[line.index(after: equalsIndex)...]
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t;\""))
            return !value.isEmpty
        }
        let hardCodedIdentityAssignments = settingsLines.filter { line in
            guard line.contains("CODE_SIGN_IDENTITY"),
                  let equalsIndex = line.lastIndex(of: "=") else {
                return false
            }
            let value = line[line.index(after: equalsIndex)...]
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t;\""))
            return value != "-"
        }

        #expect(nonEmptyTeamAssignments.isEmpty)
        #expect(hardCodedIdentityAssignments.isEmpty)
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
        #expect(!appState.loginViewModel.isLoading, "loginViewModel should start idle")
        #expect(appState.loginViewModel.errorMessage == nil, "loginViewModel should start without an error")
        #expect(appState.playerViewModel.currentSong == nil, "playerViewModel should start without a song")
        #expect(!appState.playerViewModel.isPlaying, "playerViewModel should start stopped")
        #expect(appState.stationsViewModel.stations.isEmpty, "stationsViewModel should start without stations")
        #expect(appState.historyViewModel.historyItems.isEmpty, "historyViewModel should start without history")
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

        #expect(appState.stationsViewModel.pandora === appState.pandora, "stationsViewModel should receive AppState's Pandora client")
        #expect(appState.loginViewModel.username.isEmpty, "loginViewModel should start with no username")
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
        #expect(appState.stationsViewModel.pandora === mockPandora, "stationsViewModel should receive the injected mock")
        #expect(appState.loginViewModel.username.isEmpty, "loginViewModel should start with no username")

    }

    @Test("Titlebar section controls open, switch, and close the sidebar")
    func titlebarSectionControlsOpenSwitchAndCloseSidebar() {
        let appState = AppState.test(pandora: MockPandora())

        appState.selectSidebar(.stations)

        #expect(!appState.isSidebarVisible)
        #expect(appState.selectedSidebar == .stations)

        appState.selectSidebar(.history)

        #expect(appState.isSidebarVisible)
        #expect(appState.selectedSidebar == .history)

        appState.selectSidebar(.history)

        #expect(!appState.isSidebarVisible)
        #expect(appState.selectedSidebar == .history)

        appState.selectSidebar(.stations)

        #expect(appState.isSidebarVisible)
        #expect(appState.selectedSidebar == .stations)
    }

    @Test("Titlebar exposes only section controls")
    func titlebarExposesOnlySectionControls() {
        #expect(SidebarSelection.allCases == [.stations, .history])
    }

    @Test("Titlebar controls use the principal fixed group")
    func titlebarControlsUsePrincipalFixedGroup() throws {
        let root = sourceRepositoryRoot()
        let contentView = try String(
            contentsOf: root.appendingPathComponent("Sources/Swift/Views/ContentView.swift"),
            encoding: .utf8
        )

        #expect(contentView.contains("ToolbarItem(placement: .principal)"))
        #expect(contentView.contains("SidebarTitlebarButtons(appState: appState)"))
        #expect(contentView.contains(".fixedSize()"))
    }

    @Test("Content view removes sidebar toggle controls")
    func contentViewRemovesSidebarToggleControls() throws {
        let root = sourceRepositoryRoot()
        let contentView = try String(
            contentsOf: root.appendingPathComponent("Sources/Swift/Views/ContentView.swift"),
            encoding: .utf8
        )
        let sidebarView = try String(
            contentsOf: root.appendingPathComponent("Sources/Swift/Views/SidebarView.swift"),
            encoding: .utf8
        )

        #expect(contentView.contains(".toolbar(removing: .sidebarToggle)"))
        #expect(!contentView.contains("Show Sidebar"))
        #expect(!contentView.contains("sidebar.leading"))
        #expect(!sidebarView.contains("ToolbarItem("))
    }

    @Test("Embedded test bundle alone does not identify a test process")
    func embeddedTestBundleAloneDoesNotIdentifyTestProcess() {
        #expect(!TestProcessDetection.detectsTestProcess(
            environment: [:],
            arguments: [],
            hasTestRuntime: false
        ))
    }

    // MARK: - Notification Subscription Tests

    /// Test that production() AppState subscribes to notifications
    /// **Validates: Requirement 4.2**
    @Test("Production Subscribes To Notifications")
    func testProduction_SubscribesToNotifications() async throws {
        let notificationCenter = NotificationCenter()
        let appState = AppState.production(notificationCenter: notificationCenter)
        let errorMessage = "production notification error"

        #expect((appState.currentView) == (.login), "Should start in login view")
        notificationCenter.post(
            name: .pandoraDidError,
            object: nil,
            userInfo: ["error": errorMessage]
        )
        try await waitUntil {
            appState.currentView == .error(errorMessage)
        }

        #expect(
            appState.currentView == .error(errorMessage),
            "production() should handle errors from its injected notification center"
        )
    }

    /// Test that test() AppState subscribes to notifications
    /// **Validates: Requirement 4.3**
    @Test("Test Subscribes To Notifications")
    func testTest_SubscribesToNotifications() async throws {
        let mockPandora = MockPandora()
        let notificationCenter = NotificationCenter()
        let appState = AppState.test(
            pandora: mockPandora,
            notificationCenter: notificationCenter
        )
        let errorMessage = "test notification error"

        #expect((appState.currentView) == (.login), "Should start in login view")
        notificationCenter.post(
            name: .pandoraDidError,
            object: nil,
            userInfo: ["error": errorMessage]
        )
        try await waitUntil {
            appState.currentView == .error(errorMessage)
        }

        #expect(
            appState.currentView == .error(errorMessage),
            "test() should handle errors from its injected notification center"
        )
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

        #expect(appState.pandora === mockPandora, "test() should use the provided mock even when configured for failure")
        #expect(appState.currentView == .login, "test() should remain at login before authentication")
        #expect(appState.credentialRestorationState == .absent, "test() should skip credential restoration")
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
        mockPandora.isAuthenticatedValue = true

        // Create test AppState
        let appState = AppState.test(pandora: mockPandora)

        // Verify stations are accessible through pandora
        let stations = mockPandora.stations as? [Station] ?? []
        #expect((stations.count) == (2), "Mock should have 2 pre-configured stations")
        #expect(appState.stationsViewModel.pandora === mockPandora, "stationsViewModel should receive the pre-configured mock")
        #expect(appState.stationsViewModel.stations.count == 2, "stationsViewModel should load the pre-configured stations")
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

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else {
                Issue.record("Timed out waiting for asynchronous state")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}

@MainActor
@Suite("CredentialRestorationTests", .serialized)
struct CredentialRestorationTests {
    @Test("Launch construction does not wait for credentials")
    func launchDoesNotWaitForCredentialRead() async throws {
        let isolation = try TestIsolation.require()
        defer { isolation.cleanUp() }
        isolation.defaults.set("saved@example.com", forKey: UserDefaultsKeys.username)
        let store = ScriptedCredentialStore(
            readSteps: [.delayed(.milliseconds(250), .absent)]
        )
        let clock = ContinuousClock()
        var heartbeatRan = false
        Task { @MainActor in
            await Task.yield()
            heartbeatRan = true
        }

        let start = clock.now
        let appState = AppState.testRestoringCredentials(
            pandora: MockPandora(),
            credentialStore: store,
            userDefaults: isolation.defaults,
            deadline: .seconds(2)
        )
        let elapsed = start.duration(to: clock.now)

        #expect(elapsed < .milliseconds(100))
        #expect(appState.currentView == .checking)
        #expect(appState.credentialRestorationState == .checking)
        #expect(TestProcessDetection.isRunningTests)
        #expect(KeychainManager.shared is MockKeychainManager)
        try await Task.sleep(for: .milliseconds(20))
        #expect(heartbeatRan)
    }

    @Test("Credential restoration deadline degrades to login")
    func deadlineDegradesToTemporarilyUnavailable() async throws {
        let isolation = try TestIsolation.require()
        defer { isolation.cleanUp() }
        isolation.defaults.set("saved@example.com", forKey: UserDefaultsKeys.username)
        let store = ScriptedCredentialStore(readSteps: [.suspended])
        let pandora = MockPandora()
        pandora.authenticateResult = true
        let appState = AppState.testRestoringCredentials(
            pandora: pandora,
            credentialStore: store,
            userDefaults: isolation.defaults,
            deadline: .milliseconds(40)
        )

        try await waitUntil {
            appState.credentialRestorationState == .temporarilyUnavailable
        }

        var heartbeatRan = false
        Task { @MainActor in
            await Task.yield()
            heartbeatRan = true
        }
        try await Task.sleep(for: .milliseconds(20))
        #expect(heartbeatRan)
        #expect(appState.currentView == .login)
        #expect(appState.loginViewModel.username == "saved@example.com")
        #expect(appState.loginViewModel.password.isEmpty)
        #expect(appState.loginViewModel.credentialAvailabilityMessage == "Saved credentials are temporarily unavailable.")
        #expect(await store.saveCallCount == 0)
        #expect(await store.deleteCallCount == 0)
        try writeDegradedLoginScreenshotIfRequested(appState: appState, isolation: isolation)
        appState.loginViewModel.password = "manual-password"
        try await appState.loginViewModel.authenticate()
        await store.resumeSuspendedRead(with: .found("late-password"))
        try await Task.sleep(for: .milliseconds(40))
        #expect(appState.loginViewModel.password == "manual-password")
        #expect(!pandora.didCall(.authenticate(username: "saved@example.com", password: "late-password")))
    }

    @Test("Absent credentials keep the first-run login form")
    func absentCredentialsShowFirstRunLogin() async throws {
        let isolation = try TestIsolation.require()
        defer { isolation.cleanUp() }
        let store = ScriptedCredentialStore(readSteps: [])
        let appState = AppState.testRestoringCredentials(
            pandora: MockPandora(),
            credentialStore: store,
            userDefaults: isolation.defaults,
            deadline: .milliseconds(40)
        )

        try await waitUntil {
            appState.credentialRestorationState == .absent
        }

        #expect(appState.currentView == .login)
        #expect(appState.loginViewModel.username.isEmpty)
        #expect(appState.loginViewModel.password.isEmpty)
        #expect(appState.loginViewModel.credentialAvailabilityMessage == nil)
        #expect(await store.readCallCount == 0)
    }

    @Test("Unavailable credentials preserve restoration data")
    func unavailableCredentialsPreserveRestorationData() async throws {
        let isolation = try TestIsolation.require()
        defer { isolation.cleanUp() }
        isolation.defaults.set("saved@example.com", forKey: UserDefaultsKeys.username)
        let store = ScriptedCredentialStore(readSteps: [.result(.temporarilyUnavailable)])
        let appState = AppState.testRestoringCredentials(
            pandora: MockPandora(),
            credentialStore: store,
            userDefaults: isolation.defaults,
            deadline: .seconds(1)
        )
        try await waitUntil {
            appState.credentialRestorationState == .temporarilyUnavailable
        }

        #expect(isolation.defaults.string(forKey: UserDefaultsKeys.username) == "saved@example.com")
        #expect(appState.loginViewModel.username == "saved@example.com")
        #expect(appState.loginViewModel.password.isEmpty)
        #expect(appState.loginViewModel.showsCredentialRetry)
        #expect(await store.saveCallCount == 0)
        #expect(await store.deleteCallCount == 0)
        #expect(try KeychainManager.lookupResult(status: errSecItemNotFound, result: nil) == .absent)
        #expect(try KeychainManager.lookupResult(status: errSecInteractionNotAllowed, result: nil) == .temporarilyUnavailable)
        #expect(try KeychainManager.lookupResult(status: errSecInteractionRequired, result: nil) == .temporarilyUnavailable)
        #expect(try KeychainManager.lookupResult(status: errSecDataNotAvailable, result: nil) == .temporarilyUnavailable)
        #expect(try KeychainManager.lookupResult(status: errSecNotAvailable, result: nil) == .temporarilyUnavailable)
    }

    @Test("Retry recovers saved credentials")
    func retryRestoresCredentialsWithoutWriting() async throws {
        let isolation = try TestIsolation.require()
        defer { isolation.cleanUp() }
        isolation.defaults.set("saved@example.com", forKey: UserDefaultsKeys.username)
        let store = ScriptedCredentialStore(
            readSteps: [
                .result(.temporarilyUnavailable),
                .result(.found("saved-password"))
            ]
        )
        let pandora = MockPandora()
        pandora.authenticateResult = true
        let appState = AppState.testRestoringCredentials(
            pandora: pandora,
            credentialStore: store,
            userDefaults: isolation.defaults,
            deadline: .seconds(1)
        )
        try await waitUntil {
            appState.credentialRestorationState == .temporarilyUnavailable
        }

        appState.retrySavedCredentials()

        try await waitUntil {
            pandora.didCall(.authenticate(username: "saved@example.com", password: "saved-password"))
        }

        #expect(appState.credentialRestorationState == .restored)
        #expect(await store.saveCallCount == 0)
        #expect(await store.deleteCallCount == 0)
    }

    @Test("Restored credentials are not re-persisted")
    func restoredCredentialsAreNotRepersisted() async throws {
        let isolation = try TestIsolation.require()
        defer { isolation.cleanUp() }
        isolation.defaults.set("saved@example.com", forKey: UserDefaultsKeys.username)
        let store = ScriptedCredentialStore(readSteps: [.result(.found("saved-password"))])
        let pandora = MockPandora()
        pandora.authenticateResult = true
        let appState = AppState.testRestoringCredentials(
            pandora: pandora,
            credentialStore: store,
            userDefaults: isolation.defaults,
            deadline: .seconds(1)
        )

        try await waitUntil {
            pandora.didCall(.authenticate(username: "saved@example.com", password: "saved-password"))
        }

        #expect(appState.credentialRestorationState == .restored)
        #expect(await store.saveCallCount == 0)
        #expect(await store.deleteCallCount == 0)
        #expect(isolation.defaults.string(forKey: UserDefaultsKeys.username) == "saved@example.com")
    }

    @Test("Manual sign-in persistence is nonblocking")
    func manualSignInPersistenceIsNonblocking() async throws {
        let isolation = try TestIsolation.require()
        defer { isolation.cleanUp() }
        let store = ScriptedCredentialStore(
            readSteps: [],
            saveSteps: [.suspended]
        )
        let pandora = MockPandora()
        pandora.authenticateResult = true
        let viewModel = LoginViewModel(
            pandora: pandora,
            credentialStore: store,
            userDefaults: isolation.defaults,
            persistCredentials: true
        )
        viewModel.username = "manual@example.com"
        viewModel.password = "manual-password"
        var heartbeatRan = false

        try await viewModel.authenticate()
        #expect(await store.saveCallCount == 0)
        let persistence = Task { @MainActor in
            await viewModel.persistPendingManualCredentials()
        }
        try await waitUntil {
            await store.saveCallCount == 1
        }
        Task { @MainActor in
            await Task.yield()
            heartbeatRan = true
        }
        try await Task.sleep(for: .milliseconds(20))
        #expect(heartbeatRan)

        await store.resumeSuspendedSave(throwing: .temporarilyUnavailable)
        await persistence.value
        #expect(viewModel.credentialPersistenceErrorMessage != nil)
        #expect(isolation.defaults.string(forKey: UserDefaultsKeys.username) == nil)

        isolation.defaults.set("existing@example.com", forKey: UserDefaultsKeys.username)
        let rejectedStore = ScriptedCredentialStore(readSteps: [])
        let rejectedPandora = MockPandora()
        rejectedPandora.authenticateResult = false
        let rejectedViewModel = LoginViewModel(
            pandora: rejectedPandora,
            credentialStore: rejectedStore,
            userDefaults: isolation.defaults,
            persistCredentials: true
        )
        rejectedViewModel.username = "replacement@example.com"
        rejectedViewModel.password = "wrong-password"
        do {
            try await rejectedViewModel.authenticate()
            Issue.record("Rejected authentication unexpectedly succeeded")
        } catch LoginViewModel.LoginError.authenticationFailed {
        }
        await rejectedViewModel.persistPendingManualCredentials()
        #expect(await rejectedStore.saveCallCount == 0)
        #expect(isolation.defaults.string(forKey: UserDefaultsKeys.username) == "existing@example.com")
    }

    @Test("Pandora and Last.fm credential call sites stay asynchronous")
    func serviceCredentialCallSitesStayAsynchronous() async throws {
        let isolation = try TestIsolation.require()
        defer { isolation.cleanUp() }
        isolation.defaults.set("saved@example.com", forKey: UserDefaultsKeys.username)
        let staleStore = ScriptedCredentialStore(readSteps: [.suspended])
        let stalePandora = PandoraClient(
            httpClient: HTTPClient(),
            credentialStore: staleStore,
            userDefaults: isolation.defaults
        )
        let staleRequest = PandoraRequest()
        staleRequest.method = "test.stale"
        var staleRecoveryPostedError = false
        let observer = NotificationCenter.default.addObserver(
            forName: Notification.Name("PandoraDidErrorNotification"),
            object: stalePandora,
            queue: .main
        ) { _ in
            staleRecoveryPostedError = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        #expect(stalePandora.sendAuthenticatedRequest(staleRequest))
        try await waitUntil {
            await staleStore.readCallCount == 1
        }
        let manualGeneration = stalePandora.beginManualCredentialAuthentication()
        stalePandora.finishCredentialAuthentication(manualGeneration)
        await staleStore.resumeSuspendedRead(with: .found("stale-password"))
        let queuedGeneration = stalePandora.beginManualCredentialAuthentication()
        stalePandora.finishCredentialAuthentication(queuedGeneration)
        stalePandora.postNotification(
            "PandoraDidErrorNotification",
            object: stalePandora,
            userInfo: ["err": "stale"],
            authenticationGeneration: queuedGeneration
        )
        let newerGeneration = stalePandora.beginManualCredentialAuthentication()
        stalePandora.finishCredentialAuthentication(newerGeneration)
        try await Task.sleep(for: .milliseconds(40))
        #expect(!staleRecoveryPostedError)
        #expect(stalePandora.userAuthToken == nil)

        let pandoraStore = ScriptedCredentialStore(
            readSteps: [
                .delayed(.milliseconds(250), .temporarilyUnavailable),
                .delayed(.milliseconds(250), .temporarilyUnavailable)
            ]
        )
        let pandora = PandoraClient(
            httpClient: HTTPClient(),
            credentialStore: pandoraStore,
            userDefaults: isolation.defaults
        )
        let request = PandoraRequest()
        request.method = "test.method"
        let clock = ContinuousClock()

        let requestStart = clock.now
        #expect(pandora.sendAuthenticatedRequest(request))
        #expect(requestStart.duration(to: clock.now) < .milliseconds(100))
        let retry = Task {
            await pandora.retryRequestAfterAuthenticationFailure(request)
        }

        let lastFMStore = ScriptedCredentialStore(
            readSteps: [.delayed(.milliseconds(250), .temporarilyUnavailable)]
        )
        let lastFMStart = clock.now
        let lastFM = LastFMService(credentialStore: lastFMStore)
        #expect(lastFMStart.duration(to: clock.now) < .milliseconds(100))
        let lastFMSaveStore = ScriptedCredentialStore(
            readSteps: [.result(.absent)],
            saveSteps: [.delayed(.milliseconds(250), .success)]
        )
        let lastFMSaver = LastFMService(credentialStore: lastFMSaveStore)
        let save = Task { @MainActor in
            await lastFMSaver.persistSessionToken("session-token")
        }

        var heartbeatRan = false
        Task { @MainActor in
            await Task.yield()
            heartbeatRan = true
        }
        try await Task.sleep(for: .milliseconds(20))
        #expect(heartbeatRan)
        #expect(await retry.value == false)
        await save.value
        #expect(await pandoraStore.readCallCount == 2)
        #expect(await lastFMStore.readCallCount == 1)
        #expect(await lastFMSaveStore.saveCallCount == 1)
        #expect(lastFM.credentialAvailability == .temporarilyUnavailable)
        #expect(!lastFM.canAutomaticallyAuthorizeMissingSession)

        let lastFMFailureStore = ScriptedCredentialStore(
            readSteps: [.result(.absent)],
            saveSteps: [.delayed(.milliseconds(20), .failure(.temporarilyUnavailable))]
        )
        let lastFMWithSaveFailure = LastFMService(credentialStore: lastFMFailureStore)
        await lastFMWithSaveFailure.persistSessionToken("replacement-token")
        #expect(lastFMWithSaveFailure.credentialPersistenceError != nil)

        let staleLastFMStore = ScriptedCredentialStore(
            readSteps: [.suspended],
            saveSteps: [.success]
        )
        let staleLastFM = LastFMService(credentialStore: staleLastFMStore)
        try await waitUntil {
            await staleLastFMStore.readCallCount == 1
        }
        await staleLastFM.persistSessionToken("new-session-token")
        await staleLastFMStore.resumeSuspendedRead(
            throwing: .temporarilyUnavailable
        )
        try await Task.sleep(for: .milliseconds(20))
        #expect(staleLastFM.credentialAvailability == .available)
        #expect(staleLastFM.credentialPersistenceError == nil)
        #expect(await staleLastFMStore.saveCallCount == 1)
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else {
                Issue.record("Timed out waiting for asynchronous state")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @Sendable () async -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !(await condition()) {
            guard clock.now < deadline else {
                Issue.record("Timed out waiting for asynchronous state")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func writeDegradedLoginScreenshotIfRequested(
        appState: AppState,
        isolation: TestIsolation
    ) throws {
        guard let requestedPath = ProcessInfo.processInfo.environment["HERMES_UX_EVIDENCE_PATH"],
              !requestedPath.isEmpty else {
            return
        }
        let outputURL = URL(fileURLWithPath: requestedPath).standardizedFileURL
        guard isolation.contains(outputURL) else {
            throw TestIsolationError.pathOutsideRoot(outputURL.path)
        }

        let hostingView = NSHostingView(
            rootView: LoginView(
                viewModel: appState.loginViewModel,
                onRetrySavedCredentials: {}
            )
            .frame(width: 520, height: 560)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 520, height: 560)
        hostingView.layoutSubtreeIfNeeded()
        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            Issue.record("Unable to allocate screenshot bitmap")
            return
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            Issue.record("Unable to encode screenshot")
            return
        }
        try png.write(to: outputURL)
    }
}

private actor ScriptedCredentialStore: CredentialStore {
    enum ReadStep: Sendable {
        case result(CredentialLookupResult)
        case delayed(Duration, CredentialLookupResult)
        case suspended
    }

    enum SaveStep: Sendable {
        case success
        case delayed(Duration, SaveCompletion)
        case suspended
    }

    enum SaveCompletion: Sendable {
        case success
        case failure(CredentialStoreError)
    }

    private var readSteps: [ReadStep]
    private var saveSteps: [SaveStep]
    private var suspendedRead: CheckedContinuation<CredentialLookupResult, Error>?
    private var suspendedSave: CheckedContinuation<Void, Error>?
    private(set) var readCallCount = 0
    private(set) var saveCallCount = 0
    private(set) var deleteCallCount = 0

    init(readSteps: [ReadStep], saveSteps: [SaveStep] = []) {
        self.readSteps = readSteps
        self.saveSteps = saveSteps
    }

    func saveCredentials(username: String, password: String) async throws {
        saveCallCount += 1
        guard !saveSteps.isEmpty else {
            return
        }
        switch saveSteps.removeFirst() {
        case .success:
            return
        case .delayed(let duration, let completion):
            try await Task.sleep(for: duration)
            try completeSave(completion)
        case .suspended:
            try await withCheckedThrowingContinuation { continuation in
                suspendedSave = continuation
            }
        }
    }

    func retrievePassword(username: String) async throws -> CredentialLookupResult {
        readCallCount += 1
        guard !readSteps.isEmpty else {
            return .absent
        }
        switch readSteps.removeFirst() {
        case .result(let result):
            return result
        case .delayed(let duration, let result):
            try await Task.sleep(for: duration)
            return result
        case .suspended:
            return try await withCheckedThrowingContinuation { continuation in
                suspendedRead = continuation
            }
        }
    }

    func deleteCredentials(username: String) async throws {
        deleteCallCount += 1
    }

    func deleteAllCredentials() async throws {
        deleteCallCount += 1
    }

    func credentialStatus(username: String) async throws -> CredentialExistence {
        .absent
    }

    func resumeSuspendedRead(with result: CredentialLookupResult) {
        suspendedRead?.resume(returning: result)
        suspendedRead = nil
    }

    func resumeSuspendedRead(throwing error: CredentialStoreError) {
        suspendedRead?.resume(throwing: error)
        suspendedRead = nil
    }

    func resumeSuspendedSave(throwing error: CredentialStoreError? = nil) {
        if let error {
            suspendedSave?.resume(throwing: error)
        } else {
            suspendedSave?.resume()
        }
        suspendedSave = nil
    }

    private func completeSave(_ completion: SaveCompletion) throws {
        switch completion {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}

private struct TestIsolation {
    let rootURL: URL
    let homeURL: URL
    let stateURL: URL
    let suiteName: String
    let defaults: UserDefaults

    static func require() throws -> TestIsolation {
        let environment = ProcessInfo.processInfo.environment
        guard let rootPath = environment["HERMES_TEST_ROOT"],
              let canonicalTmpPath = environment["HERMES_TEST_CANONICAL_TMP"],
              let expectedHomePath = environment["HERMES_TEST_HOME"],
              let expectedStatePath = environment["HERMES_TEST_STATE_PATH"] else {
            throw TestIsolationError.missingEnvironment
        }

        let rootURL = URL(fileURLWithPath: rootPath).resolvingSymlinksInPath().standardizedFileURL
        let canonicalTmpURL = URL(fileURLWithPath: canonicalTmpPath).resolvingSymlinksInPath().standardizedFileURL
        let homeURL = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().standardizedFileURL
        let expectedHomeURL = URL(fileURLWithPath: expectedHomePath).resolvingSymlinksInPath().standardizedFileURL
        let statePath = ("~/Library/Application Support/Hermes" as NSString).expandingTildeInPath
        let stateURL = URL(fileURLWithPath: statePath).resolvingSymlinksInPath().standardizedFileURL
        let expectedStateURL = URL(fileURLWithPath: expectedStatePath).resolvingSymlinksInPath().standardizedFileURL

        guard rootURL.path.hasPrefix(canonicalTmpURL.path + "/hermes-tests."),
              Self.isDescendant(rootURL, of: canonicalTmpURL),
              homeURL == expectedHomeURL,
              stateURL == expectedStateURL,
              Self.isDescendant(homeURL, of: rootURL),
              Self.isDescendant(stateURL, of: rootURL) else {
            throw TestIsolationError.unsafePaths(
                root: rootURL.path,
                home: homeURL.path,
                state: stateURL.path
            )
        }
        guard let appEntrySnapshot = TestProcessIsolationGuard.appEntryValidationSnapshot else {
            throw TestIsolationError.hostGuardDidNotRun
        }
        guard appEntrySnapshot == TestProcessIsolationGuard.ValidationSnapshot(
            rootPath: rootURL.path,
            homePath: homeURL.path,
            statePath: stateURL.path
        ) else {
            throw TestIsolationError.hostGuardMismatch(
                root: appEntrySnapshot.rootPath,
                home: appEntrySnapshot.homePath,
                state: appEntrySnapshot.statePath
            )
        }
        let proofURL = rootURL.appendingPathComponent("host-entry-isolation.txt")
        let expectedProof = """
        phase=HermesApp.init before AppState.shared
        root=\(rootURL.path)
        home=\(homeURL.path)
        state=\(stateURL.path)
        """
        guard let proof = try? String(contentsOf: proofURL, encoding: .utf8),
              proof == expectedProof else {
            throw TestIsolationError.hostProofMissing(proofURL.path)
        }

        let suiteName = "com.hermes.tests.credentials.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestIsolationError.defaultsUnavailable
        }
        return TestIsolation(
            rootURL: rootURL,
            homeURL: homeURL,
            stateURL: stateURL,
            suiteName: suiteName,
            defaults: defaults
        )
    }

    func contains(_ url: URL) -> Bool {
        if (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil {
            return false
        }
        let parentURL = url.deletingLastPathComponent()
            .resolvingSymlinksInPath()
            .standardizedFileURL
        return parentURL == rootURL || Self.isDescendant(parentURL, of: rootURL)
    }

    func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        candidate.path.hasPrefix(root.path + "/")
    }
}

private enum TestIsolationError: Error, CustomStringConvertible {
    case missingEnvironment
    case unsafePaths(root: String, home: String, state: String)
    case hostGuardDidNotRun
    case hostGuardMismatch(root: String, home: String, state: String)
    case hostProofMissing(String)
    case defaultsUnavailable
    case pathOutsideRoot(String)

    var description: String {
        switch self {
        case .missingEnvironment:
            return "Missing guarded Hermes test environment"
        case .unsafePaths(let root, let home, let state):
            return "Unsafe Hermes test paths: root=\(root), home=\(home), state=\(state)"
        case .hostGuardDidNotRun:
            return "Hosted Hermes app did not validate isolation at app entry"
        case .hostGuardMismatch(let root, let home, let state):
            return "Hosted Hermes app validated different paths: root=\(root), home=\(home), state=\(state)"
        case .hostProofMissing(let path):
            return "Hosted Hermes app did not write matching entry proof: \(path)"
        case .defaultsUnavailable:
            return "Unable to create isolated UserDefaults suite"
        case .pathOutsideRoot(let path):
            return "Refusing to write UX evidence outside the guarded test root: \(path)"
        }
    }
}
