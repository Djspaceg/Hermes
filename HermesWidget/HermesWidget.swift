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

private struct HermesPlaybackControlValueProvider: ControlValueProvider {
    private let store: NowPlayingSnapshotStore?

    init(store: NowPlayingSnapshotStore? = NowPlayingSnapshotStore.appGroupStore()) {
        self.store = store
    }

    var previewValue: Bool {
        false
    }

    func currentValue() async throws -> Bool {
        store?.readSnapshot().playbackState.isControlEnabled ?? false
    }
}

struct HermesPlaybackControl: ControlWidget {
    static let kind = NowPlayingWidgetConfiguration.playbackControlKind

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind,
            provider: HermesPlaybackControlValueProvider()
        ) { isPlaying in
            ControlWidgetToggle(
                isOn: isPlaying,
                action: WidgetPlaybackStateIntent()
            ) {
                Label("Hermes", systemImage: "music.note")
            } valueLabel: { isPlaying in
                Label(
                    isPlaying ? "Pause" : "Play",
                    systemImage: isPlaying ? "pause.fill" : "play.fill"
                )
            }
        }
        .displayName("Hermes Playback")
        .description("Play or pause Hermes from Control Center.")
    }
}

struct HermesNowPlayingWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: HermesNowPlayingEntry
    let artworkImage: NSImage?
    let layoutOverride: NowPlayingWidgetLayout?

    init(
        entry: HermesNowPlayingEntry,
        artworkImage: NSImage? = nil,
        layoutOverride: NowPlayingWidgetLayout? = nil
    ) {
        self.entry = entry
        self.artworkImage = artworkImage
        self.layoutOverride = layoutOverride
    }

    var body: some View {
        if entry.snapshot.playbackState == .idle {
            idleView
        } else {
            nowPlayingView
        }
    }

    private var idleView: some View {
        GeometryReader { geometry in
            ZStack {
                artwork
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                legibilityScrim
                    .frame(width: geometry.size.width, height: geometry.size.height)
                VStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 34))
                    Text("Not playing")
                        .font(.headline)
                }
                .foregroundStyle(.white)
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private var nowPlayingView: some View {
        GeometryReader { geometry in
            ZStack {
                artwork
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                legibilityScrim
                    .frame(width: geometry.size.width, height: geometry.size.height)

                VStack(spacing: 0) {
                    trackText
                        .padding(14)

                    Spacer(minLength: 0)

                    playbackControls

                    Spacer(minLength: 0)

                    if layout.showsFeedbackControls {
                        feedbackControls
                            .padding(.bottom, 14)
                    }
                }
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private var layout: NowPlayingWidgetLayout {
        layoutOverride ?? (widgetFamily == .systemSmall ? .small : .medium)
    }

    private var legibilityScrim: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.78),
                .black.opacity(0.08),
                .black.opacity(0.72)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    private var playbackControls: some View {
        ZStack {
            controlButton(
                entry.snapshot.playbackState == .playing ? .pause : .play,
                systemImage: entry.snapshot.playbackState == .playing
                    ? "pause.fill"
                    : "play.fill",
                label: entry.snapshot.playbackState == .playing ? "Pause" : "Play",
                size: layout == .small ? 56 : 64,
                symbolSize: layout == .small ? 25 : 29
            )

            controlButton(
                .next,
                systemImage: "forward.fill",
                label: "Next",
                size: layout == .small ? 34 : 38,
                symbolSize: layout == .small ? 14 : 16
            )
            .offset(x: layout == .small ? 46 : 52)
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let artworkImage {
            artworkView(artworkImage)
        } else if let artworkFilename = entry.snapshot.artworkFilename,
           let containerURL = FileManager.default.containerURL(
               forSecurityApplicationGroupIdentifier: NowPlayingWidgetConfiguration.appGroupIdentifier
           ),
           let image = NSImage(contentsOf: containerURL.appendingPathComponent(artworkFilename)) {
            artworkView(image)
        } else {
            LinearGradient(
                colors: [.indigo, .purple.opacity(0.7), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private func artworkView(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .widgetAccentedRenderingMode(.desaturated)
            .scaledToFill()
    }

    private var trackText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.snapshot.title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
            Text(entry.snapshot.artist)
                .font(.subheadline)
                .lineLimit(1)
                .opacity(0.88)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var feedbackControls: some View {
        HStack(spacing: 20) {
            controlButton(
                .thumbsUp,
                systemImage: entry.snapshot.rating > 0
                    ? "hand.thumbsup.fill"
                    : "hand.thumbsup",
                label: "Thumbs Up",
                size: 36,
                symbolSize: 16
            )
            controlButton(
                .thumbsDown,
                systemImage: entry.snapshot.rating < 0
                    ? "hand.thumbsdown.fill"
                    : "hand.thumbsdown",
                label: "Thumbs Down",
                size: 36,
                symbolSize: 16
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func controlButton(
        _ command: WidgetPlaybackCommand,
        systemImage: String,
        label: String,
        size: CGFloat,
        symbolSize: CGFloat
    ) -> some View {
        Button(intent: WidgetPlaybackCommandIntent(command: command)) {
            Image(systemName: systemImage)
                .font(.system(size: symbolSize, weight: .medium))
                .frame(width: size, height: size)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
    }
}

#if !WIDGET_EVIDENCE_RENDERER
@main
struct HermesWidgetBundle: WidgetBundle {
    var body: some Widget {
        HermesNowPlayingWidget()
        HermesPlaybackControl()
    }
}
#endif
