//
//  ContentView.swift
//  Hermes
//
//  Root view that switches between login, loading, player, and error states
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var userCollapsedSidebar = false // Track if user manually collapsed
    @Environment(\.openSettings) private var openSettings
    
    private let sidebarToggleWidth: CGFloat = 500
    
    var body: some View {
        Group {
            switch appState.currentView {
            case .login:
                LoginView(viewModel: appState.loginViewModel)
                
            case .loading:
                loadingView
                
            case .player:
                mainInterfaceView
                
            case .error(let message):
                ErrorView(errorMessage: message, onRetry: {
                    appState.retry()
                })
            }
        }
        .onAppear {
            print("ContentView: Appeared - currentView: \(appState.currentView)")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSettingsRequested"))) { _ in
            openSettings()
        }
    }
    
    private var mainInterfaceView: some View {
        GeometryReader { geometry in
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(
                    stationsViewModel: appState.stationsViewModel,
                    historyViewModel: appState.historyViewModel
                )
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
                .toolbar {
                    // When sidebar is visible, show play/pause in sidebar header
                    if columnVisibility != .detailOnly {
                        ToolbarItem(placement: .automatic) {
                            PlayPauseButton(viewModel: appState.playerViewModel)
                        }
                    }
                }
            } detail: {
                PlayerView(viewModel: appState.playerViewModel)
                    .navigationTitle("Hermes")
                    .navigationSubtitle(appState.playerViewModel.currentSong?.artist ?? "")
                    .toolbar {
                        // Leading accessory buttons
                        ToolbarItemGroup(placement: .navigation) {
                            // When sidebar is hidden, show both play/pause and next
                            if columnVisibility == .detailOnly {
                                PlayPauseButton(viewModel: appState.playerViewModel)
                            }
                            
                            // Next button always in leading position
                            Button(action: { appState.playerViewModel.next() }) {
                                Label("Next", systemImage: "forward.fill")
                            }
                            .help("Next")
                        }
                        
                        // Rating controls after title (primaryAction placement)
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button(action: { appState.playerViewModel.like() }) {
                                Label(
                                    appState.playerViewModel.isLiked ? "Unlike" : "Like",
                                    systemImage: appState.playerViewModel.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup"
                                )
                            }
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(appState.playerViewModel.isLiked ? .green : .primary)
                            .help(appState.playerViewModel.isLiked ? "Unlike" : "Like")
                            
                            Button(action: { appState.playerViewModel.dislike() }) {
                                Label("Dislike", systemImage: "hand.thumbsdown")
                            }
                            .help("Dislike")
                            
                            Button(action: { appState.playerViewModel.tired() }) {
                                Label("Tired", systemImage: "moon.zzz")
                            }
                            .help("Tired of this song")
                        }
                    }
            }
            .navigationSplitViewStyle(.automatic)
            .onChange(of: geometry.size.width) { oldWidth, newWidth in
                // Auto-hide sidebar when window is narrow (only if user hasn't manually collapsed it)
                let shouldShowSidebar = newWidth >= sidebarToggleWidth
                
                if shouldShowSidebar && columnVisibility == .detailOnly && !userCollapsedSidebar {
                    // Window is wide enough and sidebar was auto-hidden, show it
                    withAnimation {
                        columnVisibility = .all
                    }
                } else if !shouldShowSidebar && columnVisibility != .detailOnly {
                    // Window is too narrow, auto-hide sidebar
                    withAnimation {
                        columnVisibility = .detailOnly
                    }
                    // Don't set userCollapsedSidebar here - this is automatic
                }
            }
            .onChange(of: columnVisibility) { oldValue, newValue in
                // Track if user manually toggled the sidebar
                if oldValue != newValue {
                    // If changing to detailOnly when window is wide enough, user manually collapsed it
                    if newValue == .detailOnly && (NSApp.mainWindow?.frame.width ?? 0) >= sidebarToggleWidth {
                        userCollapsedSidebar = true
                    }
                    // If changing to .all, user manually expanded it
                    else if newValue == .all {
                        userCollapsedSidebar = false
                    }
                }
            }
            .onChange(of: appState.isSidebarVisible) { oldValue, newValue in
                columnVisibility = newValue ? .all : .detailOnly
                // When toggled via app state, respect it as user action
                userCollapsedSidebar = !newValue
            }
            .onAppear {
                columnVisibility = appState.isSidebarVisible ? .all : .detailOnly
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Play/Pause Button

private struct PlayPauseButton: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        Button(action: { viewModel.playPause() }) {
            Label(
                viewModel.isPlaying ? "Pause" : "Play",
                systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill"
            )
        }
        .help(viewModel.isPlaying ? "Pause" : "Play")
    }
}

// MARK: - Preview

#Preview("Loading State") {
    VStack(spacing: 20) {
        ProgressView()
            .scaleEffect(1.5)
        Text("Loading...")
            .foregroundColor(.secondary)
    }
    .frame(width: 900, height: 600)
}

#Preview("Player State") {
    PlayerView(viewModel: PreviewPlayerViewModel(
        song: .mock(
            title: "Bohemian Rhapsody",
            artist: "Queen",
            album: "A Night at the Opera"
        ),
        isPlaying: true,
        playbackPosition: 125.5,
        duration: 354.0,
        volume: 0.5,
        isLiked: false
    ))
    .frame(width: 600, height: 400)
}

#Preview("Error State") {
    ErrorView(
        errorMessage: "Failed to connect to Pandora servers. Please check your internet connection and try again."
    ) {
        print("Retry tapped")
    }
    .frame(width: 900, height: 600)
}
