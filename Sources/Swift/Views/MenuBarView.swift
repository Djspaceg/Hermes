//
//  MenuBarView.swift
//  Hermes
//
//  Menu bar extra icon and dropdown content
//

import SwiftUI

// MARK: - Status Bar Icon

struct StatusBarIcon: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @ObservedObject private var settings = SettingsManager.shared
    
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
    @ObservedObject var playerViewModel: PlayerViewModel
    @ObservedObject var stationsViewModel: StationsViewModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    
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
    }
    
    // MARK: - Now Playing Section
    
    @ViewBuilder
    private func nowPlayingSection(song: SongModel) -> some View {
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
        HStack(spacing: 16) {
            Button {
                playerViewModel.playPause()
            } label: {
                Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .frame(width: 44, height: 44)
            }
            .padding(4)
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .keyboardShortcut(.space, modifiers: [])
            
            Button {
                playerViewModel.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .frame(width: 44, height: 44)
            }
            .padding(4)
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .disabled(playerViewModel.currentSong == nil)
            
            Button {
                playerViewModel.dislike()
            } label: {
                Label("Dislike", systemImage: "hand.thumbsdown")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .disabled(playerViewModel.currentSong == nil)
            
            Button {
                playerViewModel.tired()
            } label: {
                Label("Tired", systemImage: "moon.zzz")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .disabled(playerViewModel.currentSong == nil)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - App Controls Section
    
    private var appControlsSection: some View {
        VStack(spacing: 2) {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                // Find and bring forward existing main window instead of opening a new one
                if let mainWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" || $0.title == "Hermes" }) {
                    mainWindow.makeKeyAndOrderFront(nil)
                } else {
                    openWindow(id: "main")
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
