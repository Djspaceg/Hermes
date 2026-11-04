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

    @Test("routes control state to play and pause commands")
    @MainActor
    func routesControlStateToPlaybackCommand() async throws {
        let handler = WidgetPlaybackCommandHandlerStub()
        WidgetPlaybackCommandRouter.setHandler(handler)
        defer { WidgetPlaybackCommandRouter.setHandler(nil) }

        _ = try await WidgetPlaybackStateIntent(value: true).perform()
        _ = try await WidgetPlaybackStateIntent(value: false).perform()

        #expect(handler.commands == [.play, .pause])
    }

    @Test("reports only playing snapshots as enabled controls")
    func mapsPlaybackStateToControlState() {
        #expect(NowPlayingPlaybackState.playing.isControlEnabled)
        #expect(!NowPlayingPlaybackState.paused.isControlEnabled)
        #expect(!NowPlayingPlaybackState.idle.isControlEnabled)
    }

    @Test("rejects a control state when no app handler is available")
    @MainActor
    func rejectsUnhandledControlState() async {
        WidgetPlaybackCommandRouter.setHandler(nil)

        do {
            _ = try await WidgetPlaybackStateIntent(value: true).perform()
            Issue.record("Expected an unhandled control state to fail")
        } catch let error as WidgetPlaybackStateIntentError {
            #expect(error == .commandNotHandled)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
