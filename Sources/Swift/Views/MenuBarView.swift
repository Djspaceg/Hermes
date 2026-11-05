//
//  MenuBarView.swift
//  Hermes
//
//  Menu bar extra icon and dropdown content
//

import AppKit
import Observation
import SwiftUI

@MainActor
final class MainWindowPresenter {
    static let shared = MainWindowPresenter()

    private var openMainWindow: (() -> Void)?

    private init() {}

    func register(openWindow: OpenWindowAction) {
        openMainWindow = {
            openWindow(id: WindowID.main)
        }
    }

    func revealMainWindow() -> Bool {
        if let window = mainWindow() {
            bringToFront(window)
            return true
        }

        guard let openMainWindow else {
            return false
        }

        if NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        openMainWindow()
        DispatchQueue.main.async { [weak self] in
            if let window = self?.mainWindow() {
                self?.bringToFront(window)
            }
        }
        return true
    }

    private func mainWindow() -> NSWindow? {
        NSApp.windows.first {
            $0.identifier?.rawValue == "main" || $0.title == "Hermes"
        }
    }

    private func bringToFront(_ window: NSWindow) {
        if NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

@MainActor
@Observable
final class MenuExtraStationSidebarState {
    private(set) var isPresented = false

    @ObservationIgnored
    var onDismiss: (() -> Void)?

    @ObservationIgnored
    weak var hostWindow: NSWindow?

    func toggle() {
        isPresented ? dismiss() : present()
    }

    func present() {
        isPresented = true
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false
        onDismiss?()
    }

    func select(_ station: Station, onSelect: (Station) -> Void) {
        onSelect(station)
        dismiss()
    }
}

@MainActor
final class MenuExtraStationSidebarPresenter {
    static let shared = MenuExtraStationSidebarPresenter()

    private let preferredWidth: CGFloat = 280
    private let preferredHeight: CGFloat = 460
    private let minimumWidth: CGFloat = 180
    private var panel: NSPanel?

    private init() {}

    func toggle(
        state: MenuExtraStationSidebarState,
        stationsViewModel: StationsViewModel
    ) {
        if state.isPresented {
            state.dismiss()
            return
        }

        guard let hostWindow = state.hostWindow else {
            return
        }

        let panel = panel ?? makePanel()
        self.panel = panel
        let frame = panelFrame(attachedTo: hostWindow)
        panel.contentView = NSHostingView(
            rootView: MenuExtraStationSidebar(
                state: state,
                stationsViewModel: stationsViewModel,
                width: frame.width,
                height: frame.height
            )
        )
        panel.setFrame(frame, display: false)
        hostWindow.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        state.onDismiss = { [weak self] in
            self?.hidePanel()
        }
        state.present()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = true
        return panel
    }

    private func hidePanel() {
        guard let panel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }

    private func panelFrame(attachedTo hostWindow: NSWindow) -> NSRect {
        let visibleFrame = hostWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? hostWindow.frame
        let leftSpace = hostWindow.frame.minX - visibleFrame.minX
        let rightSpace = visibleFrame.maxX - hostWindow.frame.maxX
        let availableWidth = max(leftSpace, rightSpace)
        let width = min(preferredWidth, availableWidth)
        let attachOnLeft = leftSpace >= minimumWidth || leftSpace >= rightSpace
        let x = attachOnLeft ? hostWindow.frame.minX - width : hostWindow.frame.maxX
        let height = min(preferredHeight, visibleFrame.height)
        let y = min(max(hostWindow.frame.maxY - height, visibleFrame.minY), visibleFrame.maxY - height)
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

private struct MenuExtraWindowReader: NSViewRepresentable {
    let setHostWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = view.window {
                setHostWindow(window)
            }
        }
    }
}

private struct MenuExtraStationSidebar: View {
    @Bindable var state: MenuExtraStationSidebarState
    @Bindable var stationsViewModel: StationsViewModel
    let width: CGFloat
    let height: CGFloat

    @State private var selectedStation: Station?
    @AppStorage(UserDefaultsKeys.sortStations) private var sortOrderRawValue: Int = 1

    private var sortOrder: StationsViewModel.SortOrder {
        get {
            switch sortOrderRawValue {
            case 0: return .name
            case 2: return .recentlyPlayed
            default: return .dateCreated
            }
        }
        nonmutating set {
            switch newValue {
            case .name: sortOrderRawValue = 0
            case .dateCreated: sortOrderRawValue = 1
            case .recentlyPlayed: sortOrderRawValue = 2
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Stations")
                    .font(.headline)
                Spacer()
                Button {
                    state.dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close station sidebar")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            StationsListView(
                viewModel: stationsViewModel,
                selectedStation: $selectedStation,
                sortOrder: Binding(
                    get: { sortOrder },
                    set: { sortOrder = $0 }
                ),
                onStationSelected: selectStation
            )
            .onChange(of: selectedStation) { _, station in
                if let station {
                    selectStation(station)
                }
            }
        }
        .frame(width: width, height: height)
        .background(.regularMaterial)
        .environment(\.sidebarWidth, width)
        .onChange(of: stationsViewModel.selectedStationId) { _, stationId in
            if let stationId,
               selectedStation?.id != stationId {
                selectedStation = stationsViewModel.stations.first { $0.id == stationId }
            }
        }
    }

    private func selectStation(_ station: Station) {
        guard state.isPresented else { return }
        state.select(station) { selectedStation in
            stationsViewModel.selectedStationId = selectedStation.id
            stationsViewModel.playStation(selectedStation)
        }
    }
}

// MARK: - Status Bar Icon

struct StatusBarIcon: View {
    // Use @Bindable to properly observe @Observable PlayerViewModel changes
    @Bindable var playerViewModel: PlayerViewModel
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        HStack(spacing: 0) {
            iconImage
            
            if let song = playerViewModel.currentSong {
                // Determine what text to show based on settings
                let text: String? = {
                    if settings.showSongInMenuBar && settings.showArtistInMenuBar {
                        return " \(song.title) - \(song.artist)"
                    } else if settings.showSongInMenuBar {
                        return " \(song.title)"
                    } else if settings.showArtistInMenuBar {
                        return " \(song.artist)"
                    } else {
                        return nil
                    }
                }()
                
                if let text = text {
                    Text(text)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .onAppear {
            MainWindowPresenter.shared.register(openWindow: openWindow)
        }
    }
    
    @ViewBuilder
    private var iconImage: some View {
        if settings.menuBarIconAlbumArt, let iconThumbnail = playerViewModel.menuBarIconThumbnail {
            // Album art icon - use pre-cached masked thumbnail
            Image(nsImage: iconThumbnail)
        } else if settings.menuBarIconBW {
            // Monochrome play/pause icon
            Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
        } else {
            // Default color icon (Pandora-style)
            Image(systemName: "radio.fill")
        }
    }
}

// MARK: - Status Bar Window Content

struct StatusBarWindowContent: View {
    // Use @Bindable to properly observe @Observable view model changes
    @Bindable var playerViewModel: PlayerViewModel
    @Bindable var stationsViewModel: StationsViewModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @State private var stationSidebarState = MenuExtraStationSidebarState()
    
    private var currentStationName: String? {
        guard let playingId = stationsViewModel.playingStationId else { return nil }
        return stationsViewModel.stations.first { $0.id == playingId }?.name
    }
    
    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                // Playback controls
                playbackControlsSection
                
                // Rating controls
                ratingControlsSection.padding(.bottom, 8)

                // Now Playing section
                if let song = playerViewModel.currentSong {
                  nowPlayingSection(song: song)
                }

                Divider()
                
                // App controls
                appControlsSection
            }
            .padding(12)
            .frame(width: 300)
        }
        .background(
            MenuExtraWindowReader { window in
                stationSidebarState.hostWindow = window
            }
        )
        .onDisappear {
            stationSidebarState.dismiss()
        }
    }
    
    // MARK: - Now Playing Section
    
    @ViewBuilder
    private func nowPlayingSection(song: Song) -> some View {
        VStack(spacing: 8) {
            // Album artwork - use pre-cached thumbnail to avoid main thread work
            if let thumbnail = playerViewModel.menuBarThumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: (300 - 12 * 2), height: (300 - 12 * 2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)
            }
            
            // Song info
            VStack(spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                if let stationName = currentStationName {
                    Label(stationName, systemImage: "radio")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Playback Controls Section
    
    private var playbackControlsSection: some View {
        HStack(spacing: 8) {
            Button {
                playerViewModel.playPause()
            } label: {
                Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .frame(width: 44, height: 44)
            }
            .padding(4)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .keyboardShortcut(.space, modifiers: [])
            
            Button {
                playerViewModel.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .frame(width: 44, height: 44)
            }
            .padding(4)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Rating Controls Section
    
    private var ratingControlsSection: some View {
        HStack(spacing: 0) {
            Button {
                playerViewModel.like()
            } label: {
                Label("Like", systemImage: playerViewModel.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .padding(.vertical, 2)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .disabled(playerViewModel.currentSong == nil)
            
            Button {
                playerViewModel.dislike()
            } label: {
                Label("Dislike", systemImage: "hand.thumbsdown")
                    .padding(.vertical, 2)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .disabled(playerViewModel.currentSong == nil)
            
            Button {
                playerViewModel.tired()
            } label: {
                Label("Tired", systemImage: "moon.zzz")
                    .padding(.vertical, 2)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .disabled(playerViewModel.currentSong == nil)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - App Controls Section
    
    private var appControlsSection: some View {
        VStack(spacing: 2) {
            Button {
                MenuExtraStationSidebarPresenter.shared.toggle(
                    state: stationSidebarState,
                    stationsViewModel: stationsViewModel
                )
            } label: {
                Label(
                    stationSidebarState.isPresented ? "Hide Stations" : "Show Stations",
                    systemImage: "sidebar.left"
                )
            }
            .buttonStyle(MenuItemButtonStyle())

            Button {
                NSApp.activate(ignoringOtherApps: true)
                // Find and bring forward existing main window instead of opening a new one
                if let mainWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" || $0.title == "Hermes" }) {
                    mainWindow.makeKeyAndOrderFront(nil)
                } else {
                    openWindow(id: WindowID.main)
                }
            } label: {
                Label("Show Hermes", systemImage: "macwindow")
            }
            .buttonStyle(MenuItemButtonStyle())
            
            Button {
                NSApp.activate(ignoringOtherApps: true)
                // Check if settings window is already open
                if let settingsWindow = NSApp.windows.first(where: { $0.title == "Settings" || $0.identifier?.rawValue.contains("settings") == true }) {
                    settingsWindow.makeKeyAndOrderFront(nil)
                } else {
                    openSettings()
                }
            } label: {
                Label("Settings...", systemImage: "gearshape")
            }
            .buttonStyle(MenuItemButtonStyle())
            
            Divider()
                .padding(.vertical, 4)
            
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Hermes", systemImage: "power")
            }
            .buttonStyle(MenuItemButtonStyle())
        }
    }
}

// MARK: - Button Styles

struct MenuItemButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor.opacity(0.8) : Color.clear)
            )
            .foregroundStyle(isHovered ? .white : .primary)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}


// MARK: - Previews

#Preview("Status Bar Window - Playing") {
    StatusBarWindowContent(
        playerViewModel: .mock(song: .mock(), isPlaying: true, isLiked: false),
        stationsViewModel: StationsViewModel.mock(stations: [
            .mock(name: "Today's Hits Radio"),
            .mock(name: "Chill Vibes")
        ])
    )
}

#Preview("Status Bar Window - Paused") {
    StatusBarWindowContent(
        playerViewModel: .mock(song: .mock(), isPlaying: false, isLiked: true),
        stationsViewModel: StationsViewModel.mock()
    )
}

#Preview("Status Bar Window - No Song") {
    StatusBarWindowContent(
        playerViewModel: .mock(song: nil, isPlaying: false),
        stationsViewModel: StationsViewModel.mock()
    )
}

#Preview("Status Bar Icon - Playing") {
    StatusBarIcon(playerViewModel: .mock(isPlaying: true))
        .padding()
}

#Preview("Status Bar Icon - Paused") {
    StatusBarIcon(playerViewModel: .mock(isPlaying: false))
        .padding()
}
