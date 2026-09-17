//
//  HermesApp.swift
//  Hermes
//
//  Main SwiftUI application entry point
//

import SwiftUI

private enum TestStateIsolationPrecondition {
    private static let expectedHome = "/tmp/HermesTests"

    static func enforceIfNeeded() {
        guard isRunningTests else { return }

        let environment = ProcessInfo.processInfo.environment
        precondition(environment["TMPDIR"] == "/tmp", "Hermes tests require TMPDIR=/tmp")
        precondition(environment["HOME"] == expectedHome, "Hermes tests require HOME=\(expectedHome)")
        precondition(
            environment["CFFIXED_USER_HOME"] == expectedHome,
            "Hermes tests require CFFIXED_USER_HOME=\(expectedHome)"
        )
        precondition(
            environment["HERMES_EXPECTED_STATE_TEST_HOME"] == expectedHome,
            "Hermes tests require HERMES_EXPECTED_STATE_TEST_HOME=\(expectedHome)"
        )
        precondition(NSHomeDirectory() == expectedHome, "Hermes tests resolved an unsafe home directory")

        let temporaryDirectory = URL(fileURLWithPath: "/tmp")
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let resolvedHome = URL(fileURLWithPath: expectedHome)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        precondition(
            isDescendant(resolvedHome, of: temporaryDirectory),
            "Hermes tests resolved a home directory outside /tmp"
        )

        let resolvedStateDirectory = URL(
            fileURLWithPath: NSString(
                string: "~/Library/Application Support/Hermes/"
            ).expandingTildeInPath
        )
        .standardizedFileURL
        .resolvingSymlinksInPath()
        let expectedStateDirectory = resolvedHome
            .appendingPathComponent("Library/Application Support/Hermes")
            .standardizedFileURL
            .resolvingSymlinksInPath()

        precondition(
            resolvedStateDirectory == expectedStateDirectory,
            "Hermes tests resolved an unsafe state directory"
        )
        precondition(
            isDescendant(resolvedStateDirectory, of: resolvedHome)
                && isDescendant(resolvedStateDirectory, of: temporaryDirectory),
            "Hermes tests resolved state outside the isolated home"
        )
    }

    private static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments

        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTest") != nil
            || NSClassFromString("XCTestCase") != nil
            || arguments.contains(where: {
                $0.contains("XCTest") || $0.contains(".xctest")
            })
    }

    private static func isDescendant(_ child: URL, of parent: URL) -> Bool {
        let childComponents = child.pathComponents
        let parentComponents = parent.pathComponents

        return childComponents.count > parentComponents.count
            && childComponents.prefix(parentComponents.count).elementsEqual(parentComponents)
    }
}

@main
struct HermesApp: App {
    // MARK: - Properties
    
    @State private var appState: AppState = {
        TestStateIsolationPrecondition.enforceIfNeeded()
        return AppState.shared
    }()
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
