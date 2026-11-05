//
//  ContentView.swift
//  Hermes
//
//  Root view that switches between login, loading, player, and error states
//

import SwiftUI

struct ContentView: View {
    // MARK: - Properties
    
    // Use @Bindable to properly observe @Observable AppState changes
    @Bindable var appState: AppState
    @Bindable private var playerViewModel: PlayerViewModel
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isHovering = false
    @State private var hasCompletedInitialLoad = false
    
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    
    private let sidebarToggleWidth: CGFloat = 500
    
    // MARK: - Initialization
    
    init(appState: AppState) {
        self.appState = appState
        self.playerViewModel = appState.playerViewModel
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            switch appState.currentView {
            case .checking:
                CredentialCheckingView()
            case .login:
                LoginView(
                    viewModel: appState.loginViewModel,
                    onRetrySavedCredentials: appState.retrySavedCredentials
                )
            case .loading:
                LoadingView()
            case .player:
                playerView
            case .error(let message):
                ErrorView(errorMessage: message, onRetry: { appState.retry() })
            }
        }
        .overlay(alignment: .top) {
            if let message = appState.loginViewModel.credentialPersistenceErrorMessage {
                Text(message)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .background(.orange.opacity(0.9))
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
        .onAppear {
            // Initial view state logged for debugging if needed
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequested)) { _ in
            openSettings()
        }
    }
    
    // MARK: - Player View
    
    private var playerView: some View {
        ZStack {
            // Album art background - always visible, covers entire window
            if let song = playerViewModel.currentSong {
                GeometryReader { geo in
                    AlbumArtworkView(
                        song: song,
                        artworkImage: playerViewModel.artworkImage,
                        onTap: { openWindow(id: WindowID.artworkPreview) }
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
                            appState: appState,
                            stationsViewModel: appState.stationsViewModel,
                            historyViewModel: appState.historyViewModel
                        )
                        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300 - 8 * 2)
                    } detail: {
                        PlayerControlsView(
                            viewModel: playerViewModel,
                            onBackgroundTap: { openWindow(id: WindowID.artworkPreview) }
                        )
                        .navigationTitle("")
                        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                    }
                    .navigationSplitViewStyle(.balanced)
                    .toolbar(removing: .sidebarToggle)
                    .opacity(controlsOpacity)
                    .allowsHitTesting(controlsVisible)
                    
                    errorOverlay
                }
                .overlay {
                    TitlebarSidebarControls(appState: appState)
                        .frame(width: 0, height: 0)
                        .allowsHitTesting(false)
                }
                .onChange(of: isWindowTooNarrow) { _, tooNarrow in
                    if tooNarrow {
                        appState.isSidebarVisible = false
                    } else if !settingsManager.userCollapsedSidebar {
                        appState.isSidebarVisible = true
                    }
                }
                .onChange(of: columnVisibility) { oldValue, newValue in
                    guard !isWindowTooNarrow else { return }
                    if oldValue != newValue {
                        settingsManager.userCollapsedSidebar = (newValue == .detailOnly)
                        appState.isSidebarVisible = (newValue != .detailOnly)
                    }
                }
                .onChange(of: appState.isSidebarVisible) { _, isSidebarVisible in
                    withAnimation {
                        columnVisibility = isSidebarVisible ? .all : .detailOnly
                    }
                }
                .onAppear {
                    if isWindowTooNarrow {
                        columnVisibility = .detailOnly
                        appState.isSidebarVisible = false
                    } else {
                        appState.isSidebarVisible = !settingsManager.userCollapsedSidebar
                        columnVisibility = appState.isSidebarVisible ? .all : .detailOnly
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

struct TitlebarSidebarControls: NSViewRepresentable {
    @Bindable var appState: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> TitlebarAccessoryAnchorView {
        let anchorView = TitlebarAccessoryAnchorView()
        anchorView.coordinator = context.coordinator
        return anchorView
    }

    func updateNSView(_ anchorView: TitlebarAccessoryAnchorView, context: Context) {
        context.coordinator.update(appState: appState, in: anchorView.window)
    }

    static func dismantleNSView(_ anchorView: TitlebarAccessoryAnchorView, coordinator: Coordinator) {
        coordinator.remove()
    }

    @MainActor
    final class Coordinator {
        private weak var window: NSWindow?
        private(set) var accessoryController: NSTitlebarAccessoryViewController?
        private var hostingView: NSHostingView<SidebarTitlebarButtons>?
        private var rootView: SidebarTitlebarButtons?

        func update(appState: AppState, in window: NSWindow?) {
            let rootView = SidebarTitlebarButtons(appState: appState)
            self.rootView = rootView
            if let hostingView {
                hostingView.rootView = rootView
            }

            guard let window else { return }
            installIfNeeded(in: window)
        }

        func installIfNeeded(in window: NSWindow) {
            guard accessoryController == nil else { return }
            guard let rootView else { return }

            let hostingView = NSHostingView(rootView: rootView)
            let accessoryController = NSTitlebarAccessoryViewController()
            accessoryController.view = hostingView
            accessoryController.layoutAttribute = .left

            window.addTitlebarAccessoryViewController(accessoryController)
            self.window = window
            self.hostingView = hostingView
            self.accessoryController = accessoryController
        }

        func remove() {
            guard let accessoryController else { return }
            if let index = window?.titlebarAccessoryViewControllers.firstIndex(
                where: { $0 === accessoryController }
            ) {
                window?.removeTitlebarAccessoryViewController(at: index)
            }
            self.accessoryController = nil
            hostingView = nil
            rootView = nil
            window = nil
        }
    }
}

final class TitlebarAccessoryAnchorView: NSView {
    weak var coordinator: TitlebarSidebarControls.Coordinator?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        coordinator?.installIfNeeded(in: window)
    }
}

private struct SidebarTitlebarButtons: View {
    @Bindable var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            ForEach(SidebarSelection.allCases) { selection in
                if appState.selectedSidebar == selection {
                    button(for: selection)
                        .buttonStyle(.glassProminent)
                } else {
                    button(for: selection)
                        .buttonStyle(.glass)
                }
            }
        }
    }

    private func button(for selection: SidebarSelection) -> some View {
        Button {
            appState.selectSidebar(selection)
        } label: {
            Image(systemName: selection.systemImage)
                .frame(width: 16, height: 16)
                .accessibilityLabel(selection.title)
        }
        .help(selection.title)
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

private struct CredentialCheckingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Checking saved credentials...")
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
