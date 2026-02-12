//
//  PlaybackControlsView.swift
//  Hermes
//
//  Reusable playback control components (play/pause, next, progress)
//

import SwiftUI

// MARK: - Play/Pause Button

/// Large circular play/pause button with glass effect
struct PlayPauseButton: View {
  // MARK: - Properties
  
  let isPlaying: Bool
  let action: () -> Void
  
  private let size: CGFloat = 96
  private let iconSize: CGFloat = 54
  
  // MARK: - Body
  
  var body: some View {
    Button(action: action) {
      ZStack {
        Circle()
          .fill(.clear)

        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: iconSize, weight: .medium))
          .foregroundColor(.primary)
          .offset(x: isPlaying ? 0 : 4)
      }
      .frame(width: size, height: size)
    }
    .buttonStyle(.glass)
    .buttonBorderShape(.circle)
    .help(isPlaying ? "Pause" : "Play")
  }
}

// MARK: - Progress Bar View

/// Progress bar with time labels showing current and total time
struct ProgressBarView: View {
  // MARK: - Properties
  
  let currentTime: TimeInterval
  let totalTime: TimeInterval
  let padding: CGFloat

  // MARK: - Initialization
  
  init(currentTime: TimeInterval, totalTime: TimeInterval, padding: CGFloat = 8) {
    self.currentTime = currentTime
    self.totalTime = totalTime
    self.padding = padding
  }

  // MARK: - Body
  
  var body: some View {
    GlassEffectContainer(spacing: 20) {
      VStack(spacing: 0) {
        HStack {
          Text(formatTime(currentTime))
            .padding(.top, padding / 2)
            .padding(.horizontal, padding)
            .glassEffect()
          
          Spacer()
          
          Text(formatTime(totalTime))
            .padding(.top, padding / 2)
            .padding(.horizontal, padding)
            .glassEffect()
        }
        .font(.caption2)
        .monospacedDigit()
        .foregroundColor(.primary)
        .contentOnGlass()

        ProgressView(value: max(0, min(currentTime, max(totalTime, 1))), total: max(totalTime, 1))
          .tint(.primary)
          .padding(.vertical, padding / 2)
          .padding(.horizontal, padding)
          .glassEffect()
      }
    }
  }
  
  // MARK: - Private Methods
  
  private func formatTime(_ time: TimeInterval) -> String {
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}

// MARK: - Previews

#Preview("Play Button") {
  PlayPauseButton(isPlaying: false, action: { print("Play") })
    .padding()
    .frame(width: 200, height: 200)
    .background(.black)
}

#Preview("Pause Button") {
  PlayPauseButton(isPlaying: true, action: { print("Pause") })
    .padding()
    .frame(width: 200, height: 200)
    .background(.black)
}

#Preview("Progress Bar") {
  ProgressBarView(currentTime: 125.5, totalTime: 245.0)
    .padding()
    .frame(width: 400)
    .background(.black)
}
