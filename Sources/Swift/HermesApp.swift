//
//  HermesApp.swift
//  Hermes
//
//  Main SwiftUI application entry point
//

import SwiftUI

@main
struct HermesApp: App {
    @StateObject private var appState = AppState.shared
    @NSApplicationDelegateAdaptor(MinimalAppDelegate.self) var appDelegate
    @State private var showingNewStation = false
    
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(appState: appState)
                .frame(minWidth: 300, minHeight: 300)
                .sheet(isPresented: $showingNewStation) {
                    StationAddView(viewModel: StationAddViewModel(pandora: appState.pandora))
                        .onAppear {
                            WindowTracker.shared.windowOpened("newStation")
                        }
                        .onDisappear {
                            WindowTracker.shared.windowClosed("newStation")
                        }
                }
                .onAppear {
                    WindowTracker.shared.windowOpened("main")
                }
                .onDisappear {
                    WindowTracker.shared.windowClosed("main")
                }
        }
        .defaultSize(width: 900, height: 600)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Station...") {
                    showingNewStation = true
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!appState.isAuthenticated)
            }
            
            CommandMenu("Pandora") {
                Button(appState.playerViewModel.isPlaying ? "Pause" : "Play") {
                    appState.playerViewModel.playPause()
                }
                .keyboardShortcut(.space, modifiers: [])
                
                Button("Next Song") {
                    appState.playerViewModel.next()
                }
                .keyboardShortcut("e", modifiers: .command)
                
                Divider()
                
                Button("Like Song") {
                    appState.playerViewModel.like()
                }
                .keyboardShortcut("l", modifiers: .command)
                
                Button("Dislike Song") {
                    appState.playerViewModel.dislike()
                }
                .keyboardShortcut("d", modifiers: .command)
                
                Button("Tired of Song") {
                    appState.playerViewModel.tired()
                }
                .keyboardShortcut("t", modifiers: .command)
            }
            
            CommandGroup(replacing: .help) {
                Button("Hermes Help") {
                    if let url = URL(string: "https://github.com/HermesApp/Hermes/wiki") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Divider()
                
                Button("View Changelog") {
                    if let url = URL(string: "https://github.com/HermesApp/Hermes/blob/master/CHANGELOG.md") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Button("Hermes on GitHub") {
                    if let url = URL(string: "https://github.com/HermesApp/Hermes") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Button("Report an Issue...") {
                    if let url = URL(string: "https://github.com/HermesApp/Hermes/issues/new") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Divider()
                
                Button("Hermes Homepage") {
                    if let url = URL(string: "https://hermesapp.org") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        
        Settings {
            PreferencesView()
                .onAppear {
                    WindowTracker.shared.windowOpened("settings")
                }
                .onDisappear {
                    WindowTracker.shared.windowClosed("settings")
                }
        }
        
        Window("Album Art", id: "artworkPreview") {
            AlbumArtPreviewWindow(playerViewModel: appState.playerViewModel)
                .onAppear {
                    WindowTracker.shared.windowOpened("artworkPreview")
                }
                .onDisappear {
                    WindowTracker.shared.windowClosed("artworkPreview")
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 600, height: 600)
        .windowToolbarStyle(.unified)
        
        MenuBarExtra {
            StatusBarWindowContent(
                playerViewModel: appState.playerViewModel,
                stationsViewModel: appState.stationsViewModel
            )
        } label: {
            StatusBarIcon(playerViewModel: appState.playerViewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Status Bar Icon

struct StatusBarIcon: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    
    var body: some View {
        Image(systemName: playerViewModel.isPlaying ? "play.fill" : "pause.fill")
    }
}

// MARK: - Menu Item Button Style

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

struct IconButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(
                Circle()
                    .fill(isHovered ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Status Bar Window Content

struct StatusBarWindowContent: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @ObservedObject var stationsViewModel: StationsViewModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    
    private var currentStationName: String? {
        guard let playingId = stationsViewModel.playingStationId else { return nil }
        return stationsViewModel.stations.first { $0.id == playingId }?.name
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Now Playing section
            if let song = playerViewModel.currentSong {
                nowPlayingSection(song: song)
                Divider()
                    .padding(.vertical, 8)
            }
            
            // Playback controls
            playbackControlsSection
            
            Divider()
                .padding(.vertical, 8)
            
            // Rating controls
            ratingControlsSection
            
            Divider()
                .padding(.vertical, 8)
            
            // App controls
            appControlsSection
        }
        .padding(12)
        .frame(width: 300)
    }
    
    // MARK: - Now Playing Section
    
    @ViewBuilder
    private func nowPlayingSection(song: SongModel) -> some View {
        VStack(spacing: 8) {
            // Album artwork
            if let artwork = playerViewModel.artworkImage {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
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
        HStack(spacing: 12) {
            Button {
                playerViewModel.playPause()
            } label: {
                Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .buttonStyle(IconButtonStyle())
            .keyboardShortcut(.space, modifiers: [])
            
            Button {
                playerViewModel.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .buttonStyle(IconButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Rating Controls Section
    
    private var ratingControlsSection: some View {
        HStack(spacing: 12) {
            Button {
                playerViewModel.like()
            } label: {
                Image(systemName: playerViewModel.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.title3)
            }
            .buttonStyle(IconButtonStyle())
            .disabled(playerViewModel.currentSong == nil)
            
            Button {
                playerViewModel.dislike()
            } label: {
                Image(systemName: "hand.thumbsdown")
                    .font(.title3)
            }
            .buttonStyle(IconButtonStyle())
            .disabled(playerViewModel.currentSong == nil)
            
            Button {
                playerViewModel.tired()
            } label: {
                Image(systemName: "moon.zzz")
                    .font(.title3)
            }
            .buttonStyle(IconButtonStyle())
            .disabled(playerViewModel.currentSong == nil)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - App Controls Section
    
    private var appControlsSection: some View {
        VStack(spacing: 2) {
            Button {
                openWindow(id: "main")
            } label: {
                Label("Show Hermes", systemImage: "macwindow")
            }
            .buttonStyle(MenuItemButtonStyle())
            
            Button {
                openSettings()
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
