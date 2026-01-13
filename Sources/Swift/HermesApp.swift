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
        
        MenuBarExtra {
            StatusBarMenuContent(playerViewModel: appState.playerViewModel)
        } label: {
            StatusBarIcon(playerViewModel: appState.playerViewModel)
        }
    }
}

// MARK: - Status Bar Icon

struct StatusBarIcon: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    
    var body: some View {
        Image(systemName: playerViewModel.isPlaying ? "play.fill" : "pause.fill")
    }
}

// MARK: - Status Bar Menu Content

struct StatusBarMenuContent: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button(playerViewModel.isPlaying ? "Pause" : "Play") {
            playerViewModel.playPause()
        }
        .keyboardShortcut(.space, modifiers: [])
        
        Button("Next Song") {
            playerViewModel.next()
        }
        
        Divider()
        
        Button("Like Song") {
            playerViewModel.like()
        }
        
        Button("Dislike Song") {
            playerViewModel.dislike()
        }
        
        Button("Tired of Song") {
            playerViewModel.tired()
        }
        
        Divider()
        
        Button("Show Hermes") {
            openWindow(id: "main")
        }
        
        Button("Settings...") {
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
        
        Divider()
        
        Button("Quit Hermes") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
