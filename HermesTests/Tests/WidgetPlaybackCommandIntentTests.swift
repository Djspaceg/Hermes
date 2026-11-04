//
//  WidgetPlaybackCommandIntentTests.swift
//  HermesTests
//

import Testing
@testable import Hermes

@MainActor
private final class WidgetPlaybackCommandHandlerStub:
    WidgetPlaybackCommandHandling {
    private(set) var commands: [WidgetPlaybackCommand] = []

    func handleWidgetPlaybackCommand(_ command: WidgetPlaybackCommand) -> Bool {
        commands.append(command)
        return true
    }
}

@Suite("Widget Playback Command Intent")
struct WidgetPlaybackCommandIntentTests {
    @Test("routes the widget intent command to the app handler")
    @MainActor
    func routesCommandToHandler() async throws {
        let handler = WidgetPlaybackCommandHandlerStub()
        WidgetPlaybackCommandRouter.setHandler(handler)
        defer { WidgetPlaybackCommandRouter.setHandler(nil) }

        _ = try await WidgetPlaybackCommandIntent(command: .next).perform()

        #expect(handler.commands == [.next])
    }
}
