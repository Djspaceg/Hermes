//
//  AppState.swift
//  Hermes
//
//  Central state manager - single source of truth for app state
//

import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared: AppState = {
        print("AppState.shared: Creating singleton instance")
        return AppState()
    }()
    
    // MARK: - Published Properties
    
    @Published var currentView: ViewState = .login
    @Published var isSidebarVisible: Bool = true
    @Published var isAuthenticated: Bool = false
    
    // MARK: - Dependencies
    
    let pandora: PandoraClient
    let loginViewModel: LoginViewModel
    let playerViewModel: PlayerViewModel
    let stationsViewModel: StationsViewModel
    let historyViewModel: HistoryViewModel
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        print("AppState: Initializing...")
        print("AppState: Process name: \(ProcessInfo.processInfo.processName)")
        print("AppState: Arguments: \(ProcessInfo.processInfo.arguments)")
        
        // Initialize Pandora
        self.pandora = PandoraClient()
        
        // Initialize view models
        self.loginViewModel = LoginViewModel(pandora: pandora)
        self.playerViewModel = PlayerViewModel()
        self.stationsViewModel = StationsViewModel(pandora: pandora)
        self.historyViewModel = HistoryViewModel()
        
        // Subscribe to notifications
        setupNotificationSubscriptions()
        
        // Check for saved credentials - but NOT in preview or test mode
        if !Self.isPreview && !Self.isRunningTests {
            checkSavedCredentials()
        } else {
            print("AppState: Running in preview/test mode, skipping credential check")
        }
        
        print("AppState: Initialized - currentView: \(currentView)")
    }
    
    // MARK: - Preview Detection
    
    private static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil ||
        NSClassFromString("XCTest") != nil
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
        if let username = UserDefaults.standard.string(forKey: "pandora.username"),
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
    
    func toggleSidebar() {
        isSidebarVisible.toggle()
    }
    
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

// MARK: - View State

extension AppState {
    enum ViewState: Equatable {
        case login
        case loading
        case player
        case error(String)
    }
}
