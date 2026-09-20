//
//  AppState.swift
//  Hermes
//
//  Central state manager - single source of truth for app state
//

import Foundation
import Combine
import Observation

// MARK: - ViewState

/// Represents the current view state of the application
enum ViewState: Equatable {
    /// Credential restoration is in progress.
    case checking

    /// Login screen - user needs to authenticate
    case login
    
    /// Loading screen - waiting for data
    case loading
    
    /// Main player view - authenticated and ready
    case player
    
    /// Error state with message
    case error(String)
}

enum CredentialRestorationState: Equatable {
    case checking
    case restored
    case absent
    case temporarilyUnavailable
    case failed(String)
}

/// Central state manager providing a single source of truth for application state.
///
/// `AppState` is a singleton that manages the global state of the Hermes application,
/// including authentication status, current view, and references to all view models.
/// It uses the `@Observable` macro for automatic SwiftUI state tracking.
///
/// ## Topics
///
/// ### Accessing the Shared Instance
/// - ``shared``
///
/// ### View State
/// - ``currentView``
/// - ``ViewState``
/// - ``isSidebarVisible``
///
/// ### Authentication
/// - ``isAuthenticated``
///
/// ### View Models
/// - ``pandora``
/// - ``loginViewModel``
/// - ``playerViewModel``
/// - ``stationsViewModel``
/// - ``historyViewModel``
///
/// ### Actions
/// - ``toggleSidebar()``
/// - ``retry()``
///
/// ## Usage
///
/// ```swift
/// // Access the shared instance
/// let appState = AppState.shared
///
/// // Check authentication status
/// if appState.isAuthenticated {
///     // Show player view
/// }
///
/// // Toggle sidebar visibility
/// appState.toggleSidebar()
/// ```
@MainActor
@Observable
final class AppState {
    /// Shared singleton instance of AppState
    ///
    /// This is the single source of truth for application-wide state.
    /// All views and view models should access state through this instance.
    static let shared: AppState = {
        print("AppState.shared: Creating singleton instance")
        return AppState.production()
    }()
    
    // MARK: - Observable Properties
    
    /// The current view state of the application
    var currentView: ViewState = .checking

    var credentialRestorationState: CredentialRestorationState = .checking
    
    /// Whether the sidebar is currently visible
    var isSidebarVisible: Bool = true
    
    /// Whether the user is authenticated with Pandora
    var isAuthenticated: Bool = false
    
    // MARK: - Dependencies
    
    /// The Pandora API client
    let pandora: PandoraProtocol
    
    /// View model for the login screen
    let loginViewModel: LoginViewModel
    
    /// View model for the player interface
    let playerViewModel: PlayerViewModel
    
    /// View model for station management
    let stationsViewModel: StationsViewModel
    
    /// View model for listening history
    let historyViewModel: HistoryViewModel

    @ObservationIgnored
    private let credentialStore: any CredentialStore

    @ObservationIgnored
    private let userDefaults: UserDefaults

    @ObservationIgnored
    private let notificationCenter: NotificationCenter

    @ObservationIgnored
    private let credentialRestorationDeadline: Duration
    
    // MARK: - Private Properties
    
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    @ObservationIgnored
    private var credentialRestorationGeneration: UInt64 = 0

    @ObservationIgnored
    private var activeCredentialRestorationGeneration: UInt64?
    
    // MARK: - Factory Methods
    
    /// Creates an AppState instance for production use with real Pandora implementation
    ///
    /// This factory method creates an AppState with a PandoraClient instance,
    /// suitable for production use. The singleton `shared` instance uses this factory.
    ///
    /// - Returns: A new AppState configured for production
    static func production(
        notificationCenter: NotificationCenter = .default
    ) -> AppState {
        let credentialStore = KeychainManager.shared
        let userDefaults = productionUserDefaults
        let pandora = PandoraClient(
            credentialStore: credentialStore,
            userDefaults: userDefaults
        )
        return AppState(
            pandora: pandora,
            credentialStore: credentialStore,
            userDefaults: userDefaults,
            notificationCenter: notificationCenter,
            historySaveStateURL: testHistorySaveStateURL()
        )
    }
    
    /// Creates an AppState instance for testing with mock Pandora implementation
    ///
    /// This factory method creates an AppState with a custom PandoraProtocol
    /// implementation (typically MockPandora), suitable for testing. It skips
    /// credential checking to avoid side effects during tests.
    ///
    /// - Parameter pandora: The PandoraProtocol implementation to use (e.g., MockPandora)
    /// - Returns: A new AppState configured for testing
    static func test(
        pandora: PandoraProtocol,
        notificationCenter: NotificationCenter = .default
    ) -> AppState {
        let userDefaults = UserDefaults(suiteName: "com.hermes.tests.app-state.\(UUID().uuidString)")!
        return AppState(
            pandora: pandora,
            credentialStore: MockKeychainManager(),
            userDefaults: userDefaults,
            notificationCenter: notificationCenter,
            historySaveStateURL: testHistorySaveStateURL(),
            skipCredentialCheck: true
        )
    }

    static func testRestoringCredentials(
        pandora: PandoraProtocol,
        credentialStore: any CredentialStore,
        userDefaults: UserDefaults,
        deadline: Duration
    ) -> AppState {
        AppState(
            pandora: pandora,
            credentialStore: credentialStore,
            userDefaults: userDefaults,
            historySaveStateURL: testHistorySaveStateURL(),
            credentialRestorationDeadline: deadline
        )
    }
    
    // MARK: - Initialization
    
    private init(
        pandora: PandoraProtocol,
        credentialStore: any CredentialStore,
        userDefaults: UserDefaults,
        notificationCenter: NotificationCenter = .default,
        historySaveStateURL: URL? = nil,
        credentialRestorationDeadline: Duration = .seconds(2),
        skipCredentialCheck: Bool = false
    ) {
        print("AppState: Initializing...")
        print("AppState: Process name: \(ProcessInfo.processInfo.processName)")
        print("AppState: Arguments: \(ProcessInfo.processInfo.arguments)")
        
        // Store injected Pandora dependency
        self.pandora = pandora
        self.credentialStore = credentialStore
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
        self.credentialRestorationDeadline = credentialRestorationDeadline
        
        // Initialize view models with injected dependency
        self.loginViewModel = LoginViewModel(
            pandora: pandora,
            credentialStore: credentialStore,
            userDefaults: userDefaults,
            persistCredentials: !skipCredentialCheck
        )
        self.playerViewModel = PlayerViewModel()
        self.stationsViewModel = StationsViewModel(pandora: pandora)
        self.historyViewModel = HistoryViewModel(saveStateURL: historySaveStateURL)

        self.loginViewModel.onManualAuthenticationStarted = { [weak self] in
            self?.invalidateCredentialRestorationForManualSignIn()
        }
        
        // Subscribe to notifications
        setupNotificationSubscriptions()
        
        // Check for saved credentials - but NOT in preview, test mode, or when explicitly skipped
        if !skipCredentialCheck && !Self.isPreview {
            beginCredentialRestoration()
        } else {
            print("AppState: Skipping credential check (test/preview mode or explicitly skipped)")
            currentView = .login
            credentialRestorationState = .absent
        }
        
        print("AppState: Initialized - currentView: \(currentView)")
    }
    
    // MARK: - Preview Detection
    
    private static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    private static var isRunningTests: Bool {
        TestProcessDetection.isRunningTests
    }

    private static var productionUserDefaults: UserDefaults {
        if isRunningTests {
            return UserDefaults(suiteName: "com.hermes.tests.production.\(UUID().uuidString)")!
        }
        return .standard
    }

    private static func testHistorySaveStateURL() -> URL? {
        guard isRunningTests else {
            return nil
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("AppStateHistoryTests")
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.savestate")
    }
    
    // MARK: - Notification Subscriptions
    
    private func setupNotificationSubscriptions() {
        // Authentication success
        notificationCenter.pandoraAuthenticatedPublisher
            .sink { [weak self] in
                self?.handleAuthentication()
            }
            .store(in: &cancellables)
        
        // Stations loaded
        notificationCenter.pandoraStationsLoadedPublisher
            .sink { [weak self] in
                self?.handleStationsLoaded()
            }
            .store(in: &cancellables)
        
        // Errors
        notificationCenter.pandoraErrorPublisher
            .sink { [weak self] errorMessage in
                self?.handleError(errorMessage)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Event Handlers
    
    private func handleAuthentication() {
        print("AppState: Authentication successful")
        invalidateCredentialRestoration()
        isAuthenticated = true
        currentView = .loading
        Task {
            await loginViewModel.persistPendingManualCredentials()
        }
        print("AppState: Set currentView to .loading, fetching stations...")
        
        // Fetch stations after authentication
        Task {
            await stationsViewModel.refreshStations()
        }
    }
    
    private func handleStationsLoaded() {
        print("AppState: Stations loaded")
        if currentView == .loading {
            currentView = .player
            print("AppState: Transitioned to .player view")
        }
    }
    
    private func handleError(_ message: String) {
        print("AppState: Error - \(message)")
        loginViewModel.discardPendingManualCredentials()
        currentView = .error(message)
    }
    
    // MARK: - Saved Credentials
    
    private func beginCredentialRestoration() {
        invalidateCredentialRestoration()
        credentialRestorationState = .checking
        currentView = .checking
        loginViewModel.credentialAvailabilityMessage = nil
        loginViewModel.credentialPersistenceErrorMessage = nil

        guard let username = userDefaults.string(forKey: UserDefaultsKeys.username),
              !username.isEmpty else {
            finishCredentialRestoration(.absent, username: nil, generation: nil)
            return
        }

        loginViewModel.username = username
        loginViewModel.password = ""
        credentialRestorationGeneration &+= 1
        let generation = credentialRestorationGeneration
        activeCredentialRestorationGeneration = generation
        let credentialStore = credentialStore

        Task { [weak self] in
            do {
                let result = try await credentialStore.retrievePassword(username: username)
                self?.finishCredentialRestoration(
                    result,
                    username: username,
                    generation: generation
                )
            } catch {
                self?.failCredentialRestoration(
                    error,
                    generation: generation
                )
            }
        }

        let deadline = credentialRestorationDeadline
        Task { [weak self] in
            try? await Task.sleep(for: deadline)
            self?.finishCredentialRestoration(
                .temporarilyUnavailable,
                username: username,
                generation: generation
            )
        }
    }

    private func finishCredentialRestoration(
        _ result: CredentialLookupResult,
        username: String?,
        generation: UInt64?
    ) {
        if let generation {
            guard activeCredentialRestorationGeneration == generation,
                  !isAuthenticated else {
                return
            }
            activeCredentialRestorationGeneration = nil
        }

        switch result {
        case .found(let password):
            guard let username, !username.isEmpty, !password.isEmpty else {
                failCredentialRestoration(
                    CredentialStoreError.decodingError,
                    generation: nil
                )
                return
            }
            credentialRestorationState = .restored
            currentView = .loading
            loginViewModel.username = username
            loginViewModel.password = password
            loginViewModel.credentialAvailabilityMessage = nil
            Task {
                try? await loginViewModel.authenticateRestoredCredentials()
            }
        case .absent:
            credentialRestorationState = .absent
            currentView = .login
            loginViewModel.username = ""
            loginViewModel.password = ""
            loginViewModel.credentialAvailabilityMessage = nil
        case .temporarilyUnavailable:
            credentialRestorationState = .temporarilyUnavailable
            currentView = .login
            loginViewModel.password = ""
            loginViewModel.credentialAvailabilityMessage = "Saved credentials are temporarily unavailable."
        }
    }

    private func failCredentialRestoration(_ error: Error, generation: UInt64?) {
        if let generation {
            guard activeCredentialRestorationGeneration == generation,
                  !isAuthenticated else {
                return
            }
            activeCredentialRestorationGeneration = nil
        }
        let message = error.localizedDescription
        credentialRestorationState = .failed(message)
        currentView = .error(message)
    }

    private func invalidateCredentialRestorationForManualSignIn() {
        invalidateCredentialRestoration()
        loginViewModel.credentialAvailabilityMessage = nil
        if credentialRestorationState == .checking ||
            credentialRestorationState == .temporarilyUnavailable {
            credentialRestorationState = .absent
        }
    }

    private func invalidateCredentialRestoration() {
        activeCredentialRestorationGeneration = nil
        credentialRestorationGeneration &+= 1
    }

    func retrySavedCredentials() {
        guard !isAuthenticated else { return }
        beginCredentialRestoration()
    }
    
    // MARK: - Public Methods
    
    /// Toggles the sidebar visibility
    ///
    /// Call this method to show or hide the stations/history sidebar.
    func toggleSidebar() {
        isSidebarVisible.toggle()
    }
    
    /// Retries the last failed operation
    ///
    /// Handles retry logic based on the current view state:
    /// - If in error state and not authenticated: returns to login
    /// - If in error state and authenticated: refreshes stations
    func retry() {
        switch currentView {
        case .error:
            if !isAuthenticated {
                currentView = .login
            } else {
                currentView = .loading
                Task {
                    await stationsViewModel.refreshStations()
                }
            }
        case .login where credentialRestorationState == .temporarilyUnavailable:
            retrySavedCredentials()
        default:
            break
        }
    }
}
