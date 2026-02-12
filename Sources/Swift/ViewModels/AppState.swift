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
    /// Login screen - user needs to authenticate
    case login
    
    /// Loading screen - waiting for data
    case loading
    
    /// Main player view - authenticated and ready
    case player
    
    /// Error state with message
    case error(String)
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
    var currentView: ViewState = .login
    
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
    
    // MARK: - Private Properties
    
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Factory Methods
    
    /// Creates an AppState instance for production use with real Pandora implementation
    ///
    /// This factory method creates an AppState with a PandoraClient instance,
    /// suitable for production use. The singleton `shared` instance uses this factory.
    ///
    /// - Returns: A new AppState configured for production
    static func production() -> AppState {
        let pandora = PandoraClient()
        return AppState(pandora: pandora)
    }
    
    /// Creates an AppState instance for testing with mock Pandora implementation
    ///
    /// This factory method creates an AppState with a custom PandoraProtocol
    /// implementation (typically MockPandora), suitable for testing. It skips
    /// credential checking to avoid side effects during tests.
    ///
    /// - Parameter pandora: The PandoraProtocol implementation to use (e.g., MockPandora)
    /// - Returns: A new AppState configured for testing
    static func test(pandora: PandoraProtocol) -> AppState {
        return AppState(pandora: pandora, skipCredentialCheck: true)
    }
    
    // MARK: - Initialization
    
    private init(pandora: PandoraProtocol, skipCredentialCheck: Bool = false) {
        print("AppState: Initializing...")
        print("AppState: Process name: \(ProcessInfo.processInfo.processName)")
        print("AppState: Arguments: \(ProcessInfo.processInfo.arguments)")
        
        // Store injected Pandora dependency
        self.pandora = pandora
        
        // Initialize view models with injected dependency
        self.loginViewModel = LoginViewModel(pandora: pandora)
        self.playerViewModel = PlayerViewModel()
        self.stationsViewModel = StationsViewModel(pandora: pandora)
        self.historyViewModel = HistoryViewModel()
        
        // Subscribe to notifications
        setupNotificationSubscriptions()
        
        // Check for saved credentials - but NOT in preview, test mode, or when explicitly skipped
        if !skipCredentialCheck && !Self.isPreview && !Self.isRunningTests {
            checkSavedCredentials()
        } else {
            print("AppState: Skipping credential check (test/preview mode or explicitly skipped)")
        }
        
        print("AppState: Initialized - currentView: \(currentView)")
    }
    
    // MARK: - Preview Detection
    
    private static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    private static var isRunningTests: Bool {
        // Check environment variables (set by test harness)
        let hasTestEnvVars = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                            ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil
        
        // Check if XCTest framework is loaded (works for hosted tests)
        let hasXCTestClass = NSClassFromString("XCTest") != nil ||
                            NSClassFromString("XCTestCase") != nil
        
        // Check command line arguments for test indicators
        let args = ProcessInfo.processInfo.arguments
        let hasTestArgs = args.contains { arg in
            arg.contains("xctest") || 
            arg.contains("XCTest") ||
            arg.hasSuffix(".xctest")
        }
        
        return hasTestEnvVars || hasXCTestClass || hasTestArgs
    }
    
    // MARK: - Notification Subscriptions
    
    private func setupNotificationSubscriptions() {
        // Authentication success
        NotificationCenter.default.pandoraAuthenticatedPublisher
            .sink { [weak self] in
                self?.handleAuthentication()
            }
            .store(in: &cancellables)
        
        // Stations loaded
        NotificationCenter.default.pandoraStationsLoadedPublisher
            .sink { [weak self] in
                self?.handleStationsLoaded()
            }
            .store(in: &cancellables)
        
        // Errors
        NotificationCenter.default.pandoraErrorPublisher
            .sink { [weak self] errorMessage in
                self?.handleError(errorMessage)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Event Handlers
    
    private func handleAuthentication() {
        print("AppState: Authentication successful")
        isAuthenticated = true
        currentView = .loading
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
        currentView = .error(message)
    }
    
    // MARK: - Saved Credentials
    
    private func checkSavedCredentials() {
        if let username = UserDefaults.standard.string(forKey: UserDefaultsKeys.username),
           let password = try? KeychainManager.shared.retrievePassword(username: username),
           !username.isEmpty && !password.isEmpty {
            print("AppState: Found saved credentials, auto-authenticating")
            currentView = .loading
            loginViewModel.username = username
            loginViewModel.password = password
            
            Task {
                try? await loginViewModel.authenticate()
            }
        } else {
            print("AppState: No saved credentials, showing login")
            currentView = .login
        }
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
        default:
            break
        }
    }
}
