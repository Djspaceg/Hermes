//
//  HermesWidget.swift
//  HermesWidget
//

import AppKit
import AppIntents
import SwiftUI
import WidgetKit

struct HermesNowPlayingEntry: TimelineEntry {
    let date: Date
    let snapshot: NowPlayingSnapshot
}

struct HermesNowPlayingTimelineProvider: TimelineProvider {
    private let store: NowPlayingSnapshotStore?

    init(
        store: NowPlayingSnapshotStore? = NowPlayingSnapshotStore.appGroupStore()
    ) {
        self.store = store
    }

    func placeholder(in context: Context) -> HermesNowPlayingEntry {
        HermesNowPlayingEntry(
            date: .now,
            snapshot: NowPlayingSnapshot(
                title: "Now Playing",
                artist: "Hermes",
                album: "",
                stationName: "Station",
                playbackState: .playing,
                rating: 0,
                duration: 210,
                elapsedTime: 42,
                playbackStartDate: .now.addingTimeInterval(-42),
                artworkFilename: nil
            )
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (HermesNowPlayingEntry) -> Void
    ) {
        completion(HermesNowPlayingEntry(date: .now, snapshot: currentSnapshot))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<HermesNowPlayingEntry>) -> Void
    ) {
        let snapshot = currentSnapshot
        let entry = HermesNowPlayingEntry(date: .now, snapshot: snapshot)
        completion(Timeline(entries: [entry], policy: .after(nextRefreshDate(for: snapshot))))
    }

    private var currentSnapshot: NowPlayingSnapshot {
        store?.readSnapshot() ?? .idle
    }

    private func nextRefreshDate(for snapshot: NowPlayingSnapshot) -> Date {
        guard snapshot.playbackState == .playing,
              snapshot.duration > 0,
              let playbackStartDate = snapshot.playbackStartDate else {
            return .now.addingTimeInterval(15 * 60)
        }

        return max(
            playbackStartDate.addingTimeInterval(snapshot.duration),
            .now.addingTimeInterval(60)
        )
    }
}

struct HermesNowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: NowPlayingWidgetConfiguration.kind,
            provider: HermesNowPlayingTimelineProvider()
        ) { entry in
            HermesNowPlayingWidgetView(entry: entry)
        }
        .configurationDisplayName("Now Playing")
        .description("Shows the current Hermes song and playback progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct HermesNowPlayingWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: HermesNowPlayingEntry

    var body: some View {
        if entry.snapshot.playbackState == .idle {
            idleView
        } else if widgetFamily == .systemSmall {
            smallNowPlayingView
        } else {
            mediumNowPlayingView
        }
    }

    private var idleView: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("Not playing")
                .font(.headline)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var smallNowPlayingView: some View {
        VStack(alignment: .leading, spacing: 5) {
            artwork
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            trackText
            progress
            controls
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumNowPlayingView: some View {
        HStack(spacing: 12) {
            artwork
                .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 7) {
                trackText
                Text(entry.snapshot.stationName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                progress
                controls
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var artwork: some View {
        if let artworkFilename = entry.snapshot.artworkFilename,
           let containerURL = FileManager.default.containerURL(
               forSecurityApplicationGroupIdentifier: NowPlayingWidgetConfiguration.appGroupIdentifier
           ),
           let image = NSImage(contentsOf: containerURL.appendingPathComponent(artworkFilename)) {
            Image(nsImage: image)
                .resizable()
                .widgetAccentedRenderingMode(.desaturated)
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var trackText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.snapshot.title)
                .font(.headline)
                .lineLimit(1)
            Text(entry.snapshot.artist)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if !entry.snapshot.album.isEmpty {
                Text(entry.snapshot.album)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            controlButton(
                entry.snapshot.playbackState == .playing ? .pause : .play,
                systemImage: entry.snapshot.playbackState == .playing
                    ? "pause.fill"
                    : "play.fill",
                label: entry.snapshot.playbackState == .playing ? "Pause" : "Play"
            )
            controlButton(.next, systemImage: "forward.fill", label: "Next")
            controlButton(
                .thumbsUp,
                systemImage: entry.snapshot.rating > 0
                    ? "hand.thumbsup.fill"
                    : "hand.thumbsup",
                label: "Thumbs Up"
            )
            controlButton(
                .thumbsDown,
                systemImage: entry.snapshot.rating < 0
                    ? "hand.thumbsdown.fill"
                    : "hand.thumbsdown",
                label: "Thumbs Down"
            )
        }
        .font(.body)
        .frame(maxWidth: .infinity)
    }

    private func controlButton(
        _ command: WidgetPlaybackCommand,
        systemImage: String,
        label: String
    ) -> some View {
        Button(intent: WidgetPlaybackCommandIntent(command: command)) {
            Label(label, systemImage: systemImage)
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var progress: some View {
        if entry.snapshot.duration > 0 {
            if entry.snapshot.playbackState == .playing,
               let startDate = entry.snapshot.playbackStartDate {
                ProgressView(
                    timerInterval: startDate...startDate.addingTimeInterval(entry.snapshot.duration),
                    countsDown: false
                )
            } else {
                ProgressView(
                    value: min(entry.snapshot.elapsedTime, entry.snapshot.duration),
                    total: entry.snapshot.duration
                )
            }
        }
    }
}

@main
struct HermesWidgetBundle: WidgetBundle {
    var body: some Widget {
        HermesNowPlayingWidget()
    }
}
