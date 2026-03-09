//
//  RatingControlsView.swift
//  Hermes
//
//  Reusable rating controls (next, like, dislike, tired)
//

import SwiftUI

// MARK: - Rating Controls View

/// Vertical stack of rating controls with glass effect
struct RatingControlsView: View {
  // MARK: - Properties
  
  let isLiked: Bool
//  let onNext: () -> Void
  let onLike: () -> Void
  let onDislike: () -> Void
  let onTired: () -> Void
  
  // MARK: - Body
  
  var body: some View {
    GlassEffectContainer(spacing: 24) {
      VStack(spacing: 2) {
//        Button(action: onNext) {
//          Image(systemName: "forward.fill")
//            .frame(width: 32, height: 32)
//        }
//        .buttonStyle(.glass)
//        .buttonBorderShape(.circle)
//        .help("Next")
//
//        Color.clear.frame(width: 4, height: 4)

        // Like and dislike buttons with no spacer - they morph together
        Button(action: onLike) {
          Image(
            systemName: isLiked
              ? "hand.thumbsup.fill" : "hand.thumbsup"
          )
          .frame(width: 24, height: 24)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .tint(isLiked ? .green : nil)
        .help(isLiked ? "Unlike" : "Like")

        Button(action: onDislike) {
          Image(systemName: "hand.thumbsdown")
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .help("Dislike")

        Color.clear.frame(width: 4, height: 4)

        Button(action: onTired) {
          Image(systemName: "moon.zzz")
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .help("Tired of this song")
      }
    }
  }
}

// MARK: - Previews

#Preview("Not Liked") {
  RatingControlsView(
    isLiked: false,
//    onNext: { print("Next") },
    onLike: { print("Like") },
    onDislike: { print("Dislike") },
    onTired: { print("Tired") }
  )
  .padding()
  .frame(width: 100, height: 300)
  .background(.black)
}

#Preview("Liked") {
  RatingControlsView(
    isLiked: true,
//    onNext: { print("Next") },
    onLike: { print("Unlike") },
    onDislike: { print("Dislike") },
    onTired: { print("Tired") }
  )
  .padding()
  .frame(width: 100, height: 300)
  .background(.black)
}
