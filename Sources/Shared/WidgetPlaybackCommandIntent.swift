//
//  WidgetPlaybackCommandIntent.swift
//  Hermes
//

import AppIntents

enum WidgetPlaybackCommand: String, AppEnum, CaseIterable, Sendable {
    case play
    case pause
    case next
    case thumbsUp
    case thumbsDown

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Playback Command"
    )

    static let caseDisplayRepresentations: [WidgetPlaybackCommand: DisplayRepresentation] = [
        .play: "Play",
        .pause: "Pause",
        .next: "Next",
        .thumbsUp: "Thumbs Up",
        .thumbsDown: "Thumbs Down"
    ]
}

@MainActor
protocol WidgetPlaybackCommandHandling: AnyObject {
    func handleWidgetPlaybackCommand(_ command: WidgetPlaybackCommand) -> Bool
}

@MainActor
enum WidgetPlaybackCommandRouter {
    private static weak var handler: (any WidgetPlaybackCommandHandling)?

    static func setHandler(_ handler: (any WidgetPlaybackCommandHandling)?) {
        self.handler = handler
    }

    static func route(_ command: WidgetPlaybackCommand) -> Bool {
        handler?.handleWidgetPlaybackCommand(command) ?? false
    }
}

struct WidgetPlaybackCommandIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Hermes Playback Command"

    @Parameter(title: "Command")
    var command: WidgetPlaybackCommand

    init() {
        command = .play
    }

    init(command: WidgetPlaybackCommand) {
        self.command = command
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            _ = WidgetPlaybackCommandRouter.route(command)
        }
        return .result()
    }
}
