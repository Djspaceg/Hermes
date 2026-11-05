//
//  WidgetPlaybackCommandIntent.swift
//  Hermes
//

import AppIntents
import OSLog

private let widgetPlaybackCommandIntentLogger = Logger(
    subsystem: "com.alexcrichton.Hermes",
    category: "WidgetPlaybackCommandIntent"
)

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

enum WidgetPlaybackStateIntentError: Error, Equatable {
    case commandNotHandled
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
        widgetPlaybackCommandIntentLogger.info(
            "perform command=\(command.rawValue, privacy: .public)"
        )
        let handled = await MainActor.run {
            WidgetPlaybackCommandRouter.route(command)
        }
        widgetPlaybackCommandIntentLogger.info(
            "completed command=\(command.rawValue, privacy: .public) handled=\(handled, privacy: .public)"
        )
        return .result()
    }
}

struct WidgetPlaybackStateIntent: AudioPlaybackIntent, SetValueIntent {
    static let title: LocalizedStringResource = "Hermes Playback State"

    @Parameter(title: "Playing")
    var value: Bool

    init() {
        value = false
    }

    init(value: Bool) {
        self.value = value
    }

    func perform() async throws -> some IntentResult {
        widgetPlaybackCommandIntentLogger.info(
            "perform state value=\(value, privacy: .public)"
        )
        let handled = await MainActor.run {
            WidgetPlaybackCommandRouter.route(value ? .play : .pause)
        }
        widgetPlaybackCommandIntentLogger.info(
            "completed state value=\(value, privacy: .public) handled=\(handled, privacy: .public)"
        )
        guard handled else { throw WidgetPlaybackStateIntentError.commandNotHandled }
        return .result()
    }
}
