//
//  PreferencesView.swift
//  Hermes
//
//  Preferences/Settings view with General, Playback, and Network tabs
//

import SwiftUI

struct PreferencesView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralPreferencesView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(0)
            
            PlaybackPreferencesView()
                .tabItem {
                    Label("Playback", systemImage: "play.fill")
                }
                .tag(1)
            
            NetworkPreferencesView()
                .tabItem {
                    Label("Network", systemImage: "network")
                }
                .tag(2)
        }
        .frame(width: 500)
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
    }
}

// MARK: - General Preferences

struct GeneralPreferencesView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var menuBarIconType: MenuBarIconType = .color
    
    enum MenuBarIconType: Int {
        case color = 0
        case blackAndWhite = 1
        case albumArt = 2
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Media Controls
            GroupBox("Media Controls") {
                Toggle("Control playback with media keys", isOn: $settings.bindMediaKeys)
                    .help("Use keyboard play/pause and next track keys to control Hermes from any application")
                    .onChange(of: settings.bindMediaKeys) { _, _ in
                        settings.applyMediaKeys()
                    }
            }
            .groupBoxStyle(ModernGroupBoxStyle())
            
            // Dock Options
            GroupBox("Dock") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show album art as Dock icon", isOn: $settings.showAlbumArtInDock)
                        .help("Replace the Hermes icon with the current song's album artwork")
                        .onChange(of: settings.showAlbumArtInDock) { _, _ in
                            settings.applyDockIcon()
                        }
                    
                    Toggle("Show play/pause overlay on album art", isOn: $settings.showPlayPauseOverArt)
                        .padding(.leading, 20)
                        .disabled(!settings.showAlbumArtInDock)
                        .onChange(of: settings.showPlayPauseOverArt) { _, _ in
                            settings.applyDockIcon()
                        }
                }
            }
            .groupBoxStyle(ModernGroupBoxStyle())
            
            // Menu Bar Options
            GroupBox("Menu Bar") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Run as menu bar accessory (hide Dock icon)", isOn: $settings.showStatusBarIcon)
                        .help("Hide the Dock icon and run Hermes as a menu bar app only")
                        .onChange(of: settings.showStatusBarIcon) { _, _ in
                            settings.applyStatusBarVisibility()
                        }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Show in menu bar:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Toggle("Song title", isOn: $settings.showSongInMenuBar)
                            .padding(.leading, 16)
                        
                        Toggle("Artist name", isOn: $settings.showArtistInMenuBar)
                            .padding(.leading, 16)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Menu bar icon style:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Picker("Menu bar icon", selection: $menuBarIconType) {
                            Text("Color icon").tag(MenuBarIconType.color)
                            Text("Monochrome with play/pause").tag(MenuBarIconType.blackAndWhite)
                            Text("Album artwork").tag(MenuBarIconType.albumArt)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        .padding(.leading, 16)
                        .onChange(of: menuBarIconType) { _, newValue in
                            settings.menuBarIconBW = (newValue == .blackAndWhite)
                            settings.menuBarIconAlbumArt = (newValue == .albumArt)
                        }
                    }
                }
            }
            .groupBoxStyle(ModernGroupBoxStyle())
            
            // Window Behavior
            GroupBox("Window") {
                Toggle("Keep Hermes on top of other windows", isOn: $settings.alwaysOnTop)
                    .help("Window will float above all other applications")
                    .onChange(of: settings.alwaysOnTop) { _, _ in
                        settings.applyAlwaysOnTop()
                    }
            }
            .groupBoxStyle(ModernGroupBoxStyle())
            
            // Updates
            GroupBox("Updates") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Toggle("Check for updates", isOn: $settings.automaticUpdateChecks)
                        
                        Picker("", selection: $settings.updateCheckInterval) {
                            Text("Hourly").tag(3600.0)
                            Text("Daily").tag(86400.0)
                            Text("Weekly").tag(604800.0)
                            Text("Monthly").tag(2592000.0)
                        }
                        .labelsHidden()
                        .frame(width: 100)
                        .disabled(!settings.automaticUpdateChecks)
                    }
                    
                    Toggle("Automatically download updates", isOn: $settings.automaticallyDownloadUpdates)
                        .disabled(!settings.automaticUpdateChecks)
                }
            }
            .groupBoxStyle(ModernGroupBoxStyle())
        }
        .padding(20)
        .onAppear {
            // Sync menu bar icon type from stored values
            if settings.menuBarIconAlbumArt {
                menuBarIconType = .albumArt
            } else if settings.menuBarIconBW {
                menuBarIconType = .blackAndWhite
            } else {
                menuBarIconType = .color
            }
        }
    }
}

// MARK: - Modern GroupBox Style

struct ModernGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            configuration.content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

// MARK: - Playback Preferences

struct PlaybackPreferencesView: View {
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Audio Quality
            GroupBox("Audio Quality") {
                Picker("Quality:", selection: $settings.audioQuality) {
                    Text("High").tag(0)
                    Text("Medium").tag(1)
                    Text("Low").tag(2)
                }
                .pickerStyle(.radioGroup)
            }
            .groupBoxStyle(ModernGroupBoxStyle())
            
            // Notifications
            GroupBox("Notifications") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Toggle("Show notifications", isOn: $settings.enableNotifications)
                        
                        Picker("", selection: $settings.notificationType) {
                            Text("macOS Notifications").tag(1)
                        }
                        .labelsHidden()
                        .frame(width: 180)
                        .disabled(!settings.enableNotifications)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("When a song starts playing", isOn: $settings.notifyOnNewSong)
                            .padding(.leading, 20)
                        
                        Toggle("When resuming playback", isOn: $settings.notifyOnResume)
                            .padding(.leading, 20)
                    }
                    .disabled(!settings.enableNotifications)
                }
            }
            .groupBoxStyle(ModernGroupBoxStyle())
            
            // Last.fm Scrobbling
            GroupBox("Last.fm") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Scrobble tracks to Last.fm", isOn: $settings.enableScrobbling)
                        .help("Send your listening history to Last.fm")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Only scrobble liked tracks", isOn: $settings.onlyScrobbleLiked)
                            .padding(.leading, 20)
                        
                        Toggle("Scrobble likes and dislikes", isOn: $settings.scrobbleLikes)
                            .padding(.leading, 20)
                    }
                    .disabled(!settings.enableScrobbling)
                }
            }
            .groupBoxStyle(ModernGroupBoxStyle())
            
            // Playback Behavior
            GroupBox("Playback Behavior") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Play automatically after launching", isOn: $settings.playAutomaticallyOnLaunch)
                        .help("Start playback automatically when the app launches")
                    Toggle("Pause when screen saver starts", isOn: $settings.pauseOnScreensaver)
                    Toggle("Play when screen saver stops", isOn: $settings.playOnScreensaverStop)
                    Toggle("Pause when screen locks", isOn: $settings.pauseOnLock)
                    Toggle("Play when screen unlocks", isOn: $settings.playOnUnlock)
                }
            }
            .groupBoxStyle(ModernGroupBoxStyle())
        }
        .padding(20)
    }
}

// MARK: - Network Preferences

struct NetworkPreferencesView: View {
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Proxy Settings
            GroupBox("Proxy") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Proxy type:", selection: $settings.proxyType) {
                        Text("Use system proxy settings").tag(0)
                        Text("HTTP(S) proxy server").tag(1)
                        Text("SOCKS proxy server").tag(2)
                    }
                    .pickerStyle(.radioGroup)
                    .help("Configure how Hermes connects to Pandora")
                    
                    if settings.proxyType == 1 {
                        Divider()
                            .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("Host:")
                                    .frame(width: 60, alignment: .trailing)
                                TextField("proxy.example.com", text: $settings.httpProxyHost)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack(spacing: 8) {
                                Text("Port:")
                                    .frame(width: 60, alignment: .trailing)
                                TextField("8080", value: $settings.httpProxyPort, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                        }
                    }
                    
                    if settings.proxyType == 2 {
                        Divider()
                            .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("Host:")
                                    .frame(width: 60, alignment: .trailing)
                                TextField("proxy.example.com", text: $settings.socksProxyHost)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack(spacing: 8) {
                                Text("Port:")
                                    .frame(width: 60, alignment: .trailing)
                                TextField("1080", value: $settings.socksProxyPort, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                        }
                    }
                }
            }
            .groupBoxStyle(ModernGroupBoxStyle())
            
            // Audio Streaming
            GroupBox("Audio Streaming") {
                Toggle("Use proxy for audio streams", isOn: $settings.useProxyForAudio)
                    .help("Pandora typically only blocks API access, not audio streams. Disabling this may improve performance.")
            }
            .groupBoxStyle(ModernGroupBoxStyle())
        }
        .padding(20)
    }
}


// MARK: - Previews

#Preview("Preferences") {
    PreferencesView()
        .frame(width: 600, height: 500)
}

#Preview("General") {
    GeneralPreferencesView()
        .frame(width: 500, height: 600)
}

#Preview("Playback") {
    PlaybackPreferencesView()
        .frame(width: 500, height: 600)
}

#Preview("Network") {
    NetworkPreferencesView()
        .frame(width: 500, height: 600)
}
