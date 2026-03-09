//
//  PlayerView.swift
//  Hermes
//
//  Player view with responsive album art and anchored controls
//

import SwiftUI

// MARK: - Player View Model Protocol

@MainActor
protocol PlayerViewModelProtocol: AnyObject {
  associatedtype ErrorType: Identifiable

  var currentSong: Song? { get }
  var isPlaying: Bool { get }
  var playbackPosition: TimeInterval { get }
  var duration: TimeInterval { get }
  var volume: Double { get set }
  var isLiked: Bool { get }
  var artworkImage: NSImage? { get }
  var streamError: ErrorType? { get }
  var isRetrying: Bool { get }

  func playPause()
  func next()
  func like()
  func dislike()
  func tired()
  func setVolume(_ newVolume: Double)
  func retryPlayback()
  func dismissError()
}

// MARK: - Player View

struct PlayerView<ViewModel: PlayerViewModelProtocol & Observable>: View {
  // MARK: - Properties
  
  // Use @Bindable to properly observe @Observable ViewModel changes
  @Bindable var viewModel: ViewModel
  @State private var isHovering = false
  @Environment(\.openWindow) private var openWindow

  // MARK: - Body
  
  var body: some View {
    ZStack {
      if let song = viewModel.currentSong {
        AlbumArtworkView(
          song: song,
          artworkImage: viewModel.artworkImage,
          onTap: { openWindow(id: WindowID.artworkPreview) }
        )
        .ignoresSafeArea()

        errorOverlay
      } else {
        EmptyPlayerStateView()
      }
    }
    .background(WindowHoverTracker(isHovering: $isHovering))
  }

  // MARK: - Subviews

  @ViewBuilder
  private var errorOverlay: some View {
    if let error = viewModel.streamError {
      StreamErrorOverlay(
        error: error,
        isRetrying: viewModel.isRetrying,
        onRetry: { viewModel.retryPlayback() },
        onDismiss: { viewModel.dismissError() }
      )
    } else if viewModel.isRetrying {
      RetryingOverlay()
    }
  }

  private var shouldShowControls: Bool {
    isHovering && viewModel.streamError == nil
  }

  private var controlsAnimation: Animation {
    isHovering ? .easeIn(duration: 0.2) : .easeOut(duration: 2)
  }
}

// MARK: - Player Controls View (for ContentView integration)

struct PlayerControlsView<ViewModel: PlayerViewModelProtocol & Observable>: View {
  // MARK: - Properties
  
  @Bindable var viewModel: ViewModel
  var onBackgroundTap: (() -> Void)? = nil
  var paddingInside: CGFloat = 8
  var paddingOutside: CGFloat = 8

  // MARK: - Body
  
  var body: some View {
    ZStack {
      if let song = viewModel.currentSong {
        // Background tap catcher
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture {
            onBackgroundTap?()
          }

        // Main column layout
        VStack(spacing: 0) {
          // Upper box: expands, centers play button
          ZStack {
            GlassEffectContainer(spacing: 24) {
              HStack(spacing: 2) {
                Spacer()
                  .frame(width: 32, height: 32)

                // Play button centered in full area
                PlayPauseButton(
                  isPlaying: viewModel.isPlaying,
                  action: { viewModel.playPause() }
                )
                .padding(.horizontal, 2)

                Button(action: { viewModel.next() }) {
                  Image(systemName: "forward.fill")
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .help("Next")
              }
            }

            // Song info - bottom leading
            SongInfoView(song: song)
              .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .bottomLeading
              )
              .padding(.leading, paddingOutside + paddingInside)
              .padding(.bottom, paddingOutside)
              .allowsHitTesting(false)
          }
          .frame(maxHeight: .infinity)

          // Progress bar at bottom
          ProgressBarView(
            currentTime: viewModel.playbackPosition,
            totalTime: viewModel.duration,
            padding: paddingInside
          )
          .padding(.horizontal, paddingOutside)
          .padding(.bottom, paddingOutside)
          .allowsHitTesting(false)
        }

        // Volume slider - top right corner
        VolumeControlView(
          volume: $viewModel.volume,
          onVolumeChange: { viewModel.setVolume($0) }
        )
        .padding(paddingInside)
        .glassEffect(.regular.interactive())
        .padding(paddingOutside)
        .frame(
          maxWidth: .infinity,
          maxHeight: .infinity,
          alignment: .topTrailing
        )

        // Rating controls - top left corner
        RatingControlsView(
          isLiked: viewModel.isLiked,
//          onNext: { viewModel.next() },
          onLike: { viewModel.like() },
          onDislike: { viewModel.dislike() },
          onTired: { viewModel.tired() }
        )
        .padding(paddingOutside)
        .frame(
          maxWidth: .infinity,
          maxHeight: .infinity,
          alignment: .topLeading
        )
      } else {
        EmptyPlayerStateView()
      }
    }
  }
}

// MARK: - Empty State

struct EmptyPlayerStateView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "music.note")
        .font(.system(size: 80))
        .foregroundColor(.gray)

      Text("No Song Playing")
        .font(.title2)

      Text("Select a station to start listening")
        .font(.body)
    }
    .foregroundColor(.secondary)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Error Overlays

struct StreamErrorOverlay<E: Identifiable>: View {
  let error: E
  let isRetrying: Bool
  let onRetry: () -> Void
  let onDismiss: () -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.7)

      VStack(spacing: 20) {
        Image(systemName: "wifi.exclamationmark")
          .font(.system(size: 48))
          .foregroundColor(.orange)

        Text("Connection Lost")
          .font(.title2)
          .fontWeight(.semibold)

        Text("Unable to stream audio. Check your network connection.")
          .font(.body)
          .opacity(0.8)
          .multilineTextAlignment(.center)

        HStack(spacing: 16) {
          Button("Dismiss", action: onDismiss)
            .buttonStyle(.glass)

          Button(action: onRetry) {
            HStack {
              if isRetrying {
                ProgressView()
                  .scaleEffect(0.45)
                  .frame(width: 16, height: 16)
              }
              Text(isRetrying ? "Retrying..." : "Retry")
            }
          }
          .buttonStyle(.glassProminent)
          .disabled(isRetrying)
        }
      }
      .foregroundColor(.primary)
      .padding(32)
    }
    .transition(.opacity)
  }
}

struct RetryingOverlay: View {
  var body: some View {
    ZStack {
      Color.black.opacity(0.5)

      VStack(spacing: 16) {
        ProgressView()
          .scaleEffect(1.5)
          .tint(.primary)

        Text("Reconnecting...")
          .font(.headline)
          .foregroundColor(.primary)
      }
    }
    .transition(.opacity)
  }
}

// MARK: - Window Hover Tracking

struct WindowHoverTracker: NSViewRepresentable {
  @Binding var isHovering: Bool

  func makeNSView(context: Context) -> WindowHoverView {
    let view = WindowHoverView()
    view.onHoverChanged = { [weak view] hovering in
      DispatchQueue.main.async {
        isHovering = hovering
        if let window = view?.window, isMainHermesWindow(window) {
          setWindowControlsHidden(!hovering, for: window)
        }
      }
    }
    return view
  }

  func updateNSView(_ nsView: WindowHoverView, context: Context) {
    if let window = nsView.window, isMainHermesWindow(window) {
      setWindowControlsHidden(!isHovering, for: window)
    }
  }

  private func isMainHermesWindow(_ window: NSWindow) -> Bool {
    window.identifier?.rawValue == "main"
      || (window.title == "Hermes" && !window.title.isEmpty)
  }

  private func setWindowControlsHidden(_ hidden: Bool, for window: NSWindow) {
    let duration = hidden ? 2.0 : 0.2

    if let titlebarContainer = window.standardWindowButton(.closeButton)?
      .superview?.superview
    {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = duration
        titlebarContainer.animator().alphaValue = hidden ? 0 : 1
      }
    }
  }
}

class WindowHoverView: NSView {
  var onHoverChanged: ((Bool) -> Void)?
  private var trackingArea: NSTrackingArea?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    setupWindowTracking()
  }

  private func setupWindowTracking() {
    guard let window = window, let contentView = window.contentView else {
      return
    }

    if let existing = trackingArea {
      contentView.removeTrackingArea(existing)
    }

    trackingArea = NSTrackingArea(
      rect: .zero,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )

    if let area = trackingArea {
      contentView.addTrackingArea(area)
    }

    let mouseLocation = window.mouseLocationOutsideOfEventStream
    let isInWindow = contentView.bounds.contains(
      contentView.convert(mouseLocation, from: nil)
    )
    onHoverChanged?(isInWindow)
  }

  override func mouseEntered(with event: NSEvent) {
    onHoverChanged?(true)
  }

  override func mouseExited(with event: NSEvent) {
    onHoverChanged?(false)
  }

  deinit {
    if let area = trackingArea, let contentView = window?.contentView {
      contentView.removeTrackingArea(area)
    }
  }
}

// MARK: - Window Size Reader

struct WindowSizeReader: NSViewRepresentable {
  let onWidthChange: (CGFloat) -> Void

  func makeNSView(context: Context) -> WindowSizeView {
    let view = WindowSizeView()
    view.onWidthChange = onWidthChange
    return view
  }

  func updateNSView(_ nsView: WindowSizeView, context: Context) {
    nsView.onWidthChange = onWidthChange
  }
}

class WindowSizeView: NSView {
  var onWidthChange: ((CGFloat) -> Void)?
  private var windowObserver: NSObjectProtocol?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    windowObserver = nil

    guard let window = window else { return }

    // Report initial size
    onWidthChange?(window.frame.width)

    // Observe window resize
    windowObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didResizeNotification,
      object: window,
      queue: .main
    ) { [weak self] notification in
      guard let window = notification.object as? NSWindow else { return }
      self?.onWidthChange?(window.frame.width)
    }
  }

  deinit {
    if let observer = windowObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }
}

// MARK: - Previews

#Preview("Player - Playing") {
  PlayerControlsView(
    viewModel: PreviewPlayerViewModel(
      song: .mock(
        title: "Bohemian Rhapsody",
        artist: "Queen",
        album: "A Night at the Opera",
        rating: 1
      ),
      isPlaying: true,
      playbackPosition: 125.5,
      duration: 245.0
    )
  )
  .frame(width: 600, height: 400)
}

#Preview("Player - Empty") {
  PlayerView(viewModel: PreviewPlayerViewModel(song: nil))
    .frame(width: 600, height: 400)
}

#Preview("Player - Error") {
  PlayerView(
    viewModel: PreviewPlayerViewModel(
      song: .mock(
        title: "Test Song",
        artist: "Test Artist",
        album: "Test Album"
      ),
      isPlaying: false,
      streamError: PreviewPlayerViewModel.PreviewError(
        message: "Connection lost"
      ),
      isRetrying: false
    )
  )
  .frame(width: 600, height: 400)
}
