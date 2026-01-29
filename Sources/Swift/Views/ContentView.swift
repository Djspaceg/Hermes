//
//  ContentView.swift
//  Hermes
//
//  Root view that switches between login, loading, player, and error states
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var playerViewModel: PlayerViewModel
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isHovering = false
    @State private var hasCompletedInitialLoad = false
    
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    
    private let sidebarToggleWidth: CGFloat = 500
    
    init(appState: AppState) {
        self.appState = appState
        self.playerViewModel = appState.playerViewModel
    }
    
    var body: some View {
        Group {
            switch appState.currentView {
            case .login:
                LoginView(viewModel: appState.loginViewModel)
            case .loading:
                LoadingView()
            case .player:
                playerView
            case .error(let message):
                ErrorView(errorMessage: message, onRetry: { appState.retry() })
            }
        }
        .onAppear {
            // Initial view state logged for debugging if needed
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSettingsRequested"))) { _ in
            openSettings()
        }
    }
    
    // MARK: - Player View
    
    private var playerView: some View {
        ZStack {
            // Album art background - always visible, covers entire window
            if let song = playerViewModel.currentSong {
                GeometryReader { geo in
                    AlbumArtView(
                        song: song,
                        artworkImage: playerViewModel.artworkImage,
                        onTap: { openWindow(id: "artworkPreview") }
                    )
                }
                .ignoresSafeArea()
            }
            
            // Controls overlay - fades as a unit
            GeometryReader { geometry in
                let isWindowTooNarrow = geometry.size.width < sidebarToggleWidth
                
                ZStack {
                    NavigationSplitView(columnVisibility: $columnVisibility) {
                        SidebarView(
                            stationsViewModel: appState.stationsViewModel,
                            historyViewModel: appState.historyViewModel
                        )
                        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300 - 8 * 2)
                    } detail: {
                        PlayerControlsView(
                            viewModel: playerViewModel,
                            onBackgroundTap: { openWindow(id: "artworkPreview") }
                        )
                        .navigationTitle("")
                        .toolbarTitleDisplayMode(.inline)
                        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                        .toolbar { playbackToolbar }
                    }
                    .navigationSplitViewStyle(.balanced)
                    .opacity(controlsOpacity)
                    .allowsHitTesting(controlsVisible)
                    
                    errorOverlay
                }
                .onChange(of: isWindowTooNarrow) { _, tooNarrow in
                    if tooNarrow {
                        withAnimation { columnVisibility = .detailOnly }
                    } else if !settingsManager.userCollapsedSidebar {
                        withAnimation { columnVisibility = .all }
                    }
                }
                .onChange(of: columnVisibility) { oldValue, newValue in
                    guard !isWindowTooNarrow else { return }
                    if oldValue != newValue {
                        settingsManager.userCollapsedSidebar = (newValue == .detailOnly)
                    }
                }
                .onAppear {
                    if isWindowTooNarrow {
                        columnVisibility = .detailOnly
                    } else {
                        columnVisibility = settingsManager.userCollapsedSidebar ? .detailOnly : .all
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        hasCompletedInitialLoad = true
                    }
                }
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .background(WindowHoverTracker(isHovering: $isHovering))
        .animation(.easeOut(duration: controlsVisible ? 0.2 : 2), value: controlsOpacity)
    }
    
    @ToolbarContentBuilder
    private var playbackToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: { playerViewModel.next() }) {
                Label("Next", systemImage: "forward.fill")
            }
            .help("Next")
            
            Button(action: { playerViewModel.like() }) {
                Label(
                    playerViewModel.isLiked ? "Unlike" : "Like",
                    systemImage: playerViewModel.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup"
                )
            }
            .foregroundStyle(playerViewModel.isLiked ? .green : .primary)
            .help(playerViewModel.isLiked ? "Unlike" : "Like")
            
            Button(action: { playerViewModel.dislike() }) {
                Label("Dislike", systemImage: "hand.thumbsdown")
            }
            .help("Dislike")
            
            Button(action: { playerViewModel.tired() }) {
                Label("Tired", systemImage: "moon.zzz")
            }
            .help("Tired of this song")
        }
    }
    
    @ViewBuilder
    private var errorOverlay: some View {
        if let error = playerViewModel.streamError {
            StreamErrorOverlay(
                error: error,
                isRetrying: playerViewModel.isRetrying,
                onRetry: { playerViewModel.retryPlayback() },
                onDismiss: { playerViewModel.dismissError() }
            )
        } else if playerViewModel.isRetrying {
            RetryingOverlay()
        }
    }
    
    // MARK: - Computed Properties
    
    private var controlsVisible: Bool {
        isHovering || playerViewModel.streamError != nil || !hasCompletedInitialLoad
    }
    
    private var controlsOpacity: Double {
        (controlsVisible || playerViewModel.currentSong == nil) ? 1 : 0
    }
}

// MARK: - Loading View

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("Player") {
    PlayerView(viewModel: PreviewPlayerViewModel(
        song: .mock(title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera"),
        isPlaying: true,
        playbackPosition: 125.5,
        duration: 354.0,
        volume: 0.5,
        isLiked: false
    ))
    .frame(width: 600, height: 400)
}

#Preview("Loading") {
    LoadingView()
        .frame(width: 900, height: 600)
}

#Preview("Error") {
    ErrorView(
        errorMessage: "Failed to connect to Pandora servers. Please check your internet connection and try again.",
        onRetry: {}
    )
    .frame(width: 900, height: 600)
}
