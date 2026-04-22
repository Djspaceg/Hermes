//
//  DockMenuBuilder.swift
//  Hermes
//
//  Builds the contextual menu shown when right-clicking the Dock icon.
//

import AppKit

/// Builds an `NSMenu` reflecting the current player state for the Dock's
/// contextual menu. macOS asks for this menu every time the user right-clicks
/// the Dock icon, so a fresh snapshot is returned on each call.
@MainActor
enum DockMenuBuilder {

    // MARK: - Public API

    static func makeMenu(playerViewModel: PlayerViewModel) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let song = playerViewModel.currentSong
        let hasSong = song != nil

        appendSongInfo(to: menu, song: song)
        menu.addItem(.separator())
        appendPlaybackItems(to: menu, playerViewModel: playerViewModel, hasSong: hasSong)
        menu.addItem(.separator())
        appendRatingItems(to: menu, playerViewModel: playerViewModel, song: song)

        return menu
    }

    // MARK: - Sections

    private static func appendSongInfo(to menu: NSMenu, song: Song?) {
        guard let song, !song.title.isEmpty else {
            let item = NSMenuItem(title: "Not Playing", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return
        }

        menu.addItem(infoItem(title: song.title, emphasized: true))

        if !song.artist.isEmpty {
            menu.addItem(infoItem(title: song.artist))
        }
        if !song.album.isEmpty {
            menu.addItem(infoItem(title: song.album))
        }
    }

    private static func appendPlaybackItems(
        to menu: NSMenu,
        playerViewModel: PlayerViewModel,
        hasSong: Bool
    ) {
        let playPauseTitle = playerViewModel.isPlaying ? "Pause" : "Play"
        let playPause = actionItem(title: playPauseTitle) { $0.playPause() }
        playPause.isEnabled = hasSong || !playerViewModel.isPlaying
        menu.addItem(playPause)

        let next = actionItem(title: "Next Song") { $0.next() }
        next.isEnabled = hasSong
        menu.addItem(next)
    }

    private static func appendRatingItems(
        to menu: NSMenu,
        playerViewModel: PlayerViewModel,
        song: Song?
    ) {
        let currentRating = song?.nrating?.intValue ?? 0

        let like = actionItem(title: "Like") { $0.like() }
        like.state = currentRating == 1 ? .on : .off
        like.isEnabled = song != nil && currentRating != 1
        menu.addItem(like)

        let dislike = actionItem(title: "Dislike") { $0.dislike() }
        dislike.state = currentRating == -1 ? .on : .off
        dislike.isEnabled = song != nil && currentRating != -1
        menu.addItem(dislike)

        let tired = actionItem(title: "Tired of Song") { $0.tired() }
        tired.isEnabled = song != nil
        menu.addItem(tired)
    }

    // MARK: - Menu Item Helpers

    private static func infoItem(title: String, emphasized: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false

        let font = emphasized
            ? NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
            : NSFont.systemFont(ofSize: NSFont.systemFontSize)

        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: font]
        )
        return item
    }

    private static func actionItem(
        title: String,
        perform: @escaping (PlayerViewModel) -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let target = DockMenuActionTarget(perform: perform)
        item.target = target
        item.action = #selector(DockMenuActionTarget.invoke)
        item.representedObject = target // retain target for the lifetime of the item
        return item
    }
}

// MARK: - Action Target

/// Small helper that bridges a closure to an `@objc` selector so menu items
/// can invoke `PlayerViewModel` methods without polluting the view model with
/// AppKit-specific selectors.
@MainActor
private final class DockMenuActionTarget: NSObject {
    private let perform: (PlayerViewModel) -> Void

    init(perform: @escaping (PlayerViewModel) -> Void) {
        self.perform = perform
    }

    @objc func invoke() {
        perform(AppState.shared.playerViewModel)
    }
}
