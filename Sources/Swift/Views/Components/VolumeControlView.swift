//
//  VolumeControlView.swift
//  Hermes
//
//  Reusable volume control slider component
//

import SwiftUI

// MARK: - Volume Control View

/// Vertical volume slider with speaker icons
struct VolumeControlView: View {
  // MARK: - Properties
  
  @Binding var volume: Double
  let onVolumeChange: (Double) -> Void
  
  private let sliderHeight: CGFloat = 80
  
  // MARK: - Body
  
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "speaker.wave.3.fill")
        .padding(.top, 2)

      Slider(value: $volume, in: 0...1)
        .rotationEffect(.degrees(-90))
        .frame(width: sliderHeight, height: sliderHeight)
        .frame(width: 16, height: sliderHeight)
        .clipped()
        .onChange(of: volume) { _, newValue in
          onVolumeChange(newValue)
        }

      Image(systemName: "speaker.fill")
        .padding(.bottom, 2)
    }
    .font(.caption)
    .foregroundStyle(.primary)
  }
}

// MARK: - Previews

#Preview("Volume Low") {
  VolumeControlView(
    volume: .constant(0.2),
    onVolumeChange: { print("Volume: \($0)") }
  )
  .padding()
  .glassEffect(.regular.interactive())
  .frame(width: 100, height: 150)
  .background(.black)
}

#Preview("Volume Medium") {
  VolumeControlView(
    volume: .constant(0.5),
    onVolumeChange: { print("Volume: \($0)") }
  )
  .padding()
  .glassEffect(.regular.interactive())
  .frame(width: 100, height: 150)
  .background(.black)
}

#Preview("Volume High") {
  VolumeControlView(
    volume: .constant(0.9),
    onVolumeChange: { print("Volume: \($0)") }
  )
  .padding()
  .glassEffect(.regular.interactive())
  .frame(width: 100, height: 150)
  .background(.black)
}
