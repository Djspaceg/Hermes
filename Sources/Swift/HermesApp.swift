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
    
    @State private var appState: AppState
    @NSApplicationDelegateAdaptor(MinimalAppDelegate.self) var appDelegate
    @State private var showingNewStation = false

    init() {
        TestProcessIsolationGuard.enforceBeforeAppStateInitialization()
        _appState = State(initialValue: AppState.shared)
    }
    
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

enum TestProcessIsolationGuard {
    struct ValidationSnapshot: Equatable {
        let rootPath: String
        let homePath: String
        let statePath: String
    }

    private(set) static var validatedAtAppEntry = false

    static var appEntryValidationSnapshot: ValidationSnapshot? {
        guard validatedAtAppEntry else {
            return nil
        }
        return validation
    }

    static func enforceBeforeAppStateInitialization() {
        _ = validation
        if TestProcessDetection.isRunningTests {
            validatedAtAppEntry = true
        }
    }

    private static let validation: ValidationSnapshot? = {
        guard TestProcessDetection.isRunningTests else {
            return nil
        }

        let environment = ProcessInfo.processInfo.environment
        guard let rootPath = environment["HERMES_TEST_ROOT"],
              let canonicalTmpPath = environment["HERMES_TEST_CANONICAL_TMP"],
              let expectedHomePath = environment["HERMES_TEST_HOME"],
              let expectedStatePath = environment["HERMES_TEST_STATE_PATH"] else {
            fatalError("HERMES_TEST_HOST_ISOLATION_ABORT missing guarded test environment")
        }

        let rootURL = canonicalURL(rootPath)
        let canonicalTmpURL = canonicalURL(canonicalTmpPath)
        let expectedHomeURL = canonicalURL(expectedHomePath)
        let expectedStateURL = canonicalURL(expectedStatePath)
        let nsHomeURL = canonicalURL(NSHomeDirectory())
        let fileManagerHomeURL = FileManager.default.homeDirectoryForCurrentUser
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let statePath = ("~/Library/Application Support/Hermes" as NSString).expandingTildeInPath
        let stateURL = canonicalURL(statePath)

        guard rootURL.path.hasPrefix(canonicalTmpURL.path + "/hermes-tests."),
              isDescendant(rootURL, of: canonicalTmpURL),
              nsHomeURL == expectedHomeURL,
              fileManagerHomeURL == expectedHomeURL,
              stateURL == expectedStateURL,
              isDescendant(expectedHomeURL, of: rootURL),
              isDescendant(stateURL, of: rootURL) else {
            fatalError(
                "HERMES_TEST_HOST_ISOLATION_ABORT root=\(rootURL.path) " +
                "nsHome=\(nsHomeURL.path) fileManagerHome=\(fileManagerHomeURL.path) " +
                "state=\(stateURL.path)"
            )
        }

        print(
            "HERMES_TEST_HOST_ISOLATION_OK " +
            "root=\(rootURL.path) home=\(nsHomeURL.path) state=\(stateURL.path)"
        )
        let snapshot = ValidationSnapshot(
            rootPath: rootURL.path,
            homePath: nsHomeURL.path,
            statePath: stateURL.path
        )
        let proofURL = rootURL.appendingPathComponent("host-entry-isolation.txt")
        do {
            try proofText(for: snapshot).write(to: proofURL, atomically: true, encoding: .utf8)
        } catch {
            fatalError("HERMES_TEST_HOST_ISOLATION_ABORT unable to write proof: \(error)")
        }
        return snapshot
    }()

    private static func canonicalURL(_ path: String) -> URL {
        URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
    }

    private static func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        candidate.path.hasPrefix(root.path + "/")
    }

    private static func proofText(for snapshot: ValidationSnapshot) -> String {
        """
        phase=HermesApp.init before AppState.shared
        root=\(snapshot.rootPath)
        home=\(snapshot.homePath)
        state=\(snapshot.statePath)
        """
    }
}
