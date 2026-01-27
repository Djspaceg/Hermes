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
        ZStack {
            // Album art background - always visible, covers entire window
            if let song = playerViewModel.currentSong {
                GeometryReader { geo in
                    AlbumArtView(
                        song: song,
                        artworkImage: playerViewModel.artworkImage,
                        availableSize: geo.size,
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
                        .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
                    } detail: {
                        PlayerControlsView(viewModel: playerViewModel)
                            .navigationTitle("")
                            .toolbarTitleDisplayMode(.inline)
                            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                            .toolbar {
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
                    }
                    .navigationSplitViewStyle(.prominentDetail)
                    .opacity(controlsOpacity)
                    .allowsHitTesting(controlsVisible)
                    
                    // Stream error overlay (always visible when present)
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
                    // Delay enabling fade-out behavior until after initial load settles
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
    
    /// Controls should be visible when hovering, error present, or still in initial load.
    private var controlsVisible: Bool {
        isHovering || playerViewModel.streamError != nil || !hasCompletedInitialLoad
    }
    
    /// Opacity for controls - 1 when visible OR when no song is playing
    private var controlsOpacity: Double {
        (controlsVisible || playerViewModel.currentSong == nil) ? 1 : 0
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
