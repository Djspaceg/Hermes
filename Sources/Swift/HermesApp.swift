//
//  HermesApp.swift
//  Hermes
//
//  Main SwiftUI application entry point
//

import SwiftUI

@main
struct HermesApp: App {
    // MARK: - Properties
    
    @State private var appState = AppState.shared
    @NSApplicationDelegateAdaptor(MinimalAppDelegate.self) var appDelegate
    @State private var showingNewStation = false
    
    // MARK: - Body
    
    var body: some Scene {
        Window("Hermes", id: WindowID.main) {
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
        .windowStyle(.hiddenTitleBar)
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
            
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    UpdateChecker.shared.checkForUpdatesNow()
                }
            }
            
            CommandGroup(replacing: .help) {
                Button("Hermes Help") {
                    if let url = URL(string: "https://github.com/Djspaceg/Hermes/wiki") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Divider()
                
                Button("View Changelog") {
                    if let url = URL(string: "https://github.com/Djspaceg/Hermes/blob/master/CHANGELOG.md") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Button("Hermes on GitHub") {
                    if let url = URL(string: "https://github.com/Djspaceg/Hermes") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Button("Report an Issue...") {
                    if let url = URL(string: "https://github.com/Djspaceg/Hermes/issues/new") {
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
        
        Window("Album Art", id: WindowID.artworkPreview) {
            AlbumArtPreviewWindow(playerViewModel: appState.playerViewModel)
                .onAppear {
                    WindowTracker.shared.windowOpened("artworkPreview")
                }
                .onDisappear {
                    WindowTracker.shared.windowClosed("artworkPreview")
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 600, height: 600)
        
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
