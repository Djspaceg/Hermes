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
    @Environment(\.openSettings) private var openSettings
    
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
        GeometryReader { geometry in
            let isWindowTooNarrow = geometry.size.width < sidebarToggleWidth
            
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(
                    stationsViewModel: appState.stationsViewModel,
                    historyViewModel: appState.historyViewModel
                )
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
            } detail: {
                PlayerView(viewModel: playerViewModel)
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
            .navigationSplitViewStyle(.balanced)
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
