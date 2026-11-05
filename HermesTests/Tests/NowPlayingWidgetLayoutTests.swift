//
//  NowPlayingWidgetLayoutTests.swift
//  HermesTests
//

import Testing
@testable import Hermes

@Suite("Now Playing Widget Layout")
struct NowPlayingWidgetLayoutTests {
    @Test("keeps feedback controls in the medium layout")
    func keepsFeedbackControlsInMediumLayout() {
        #expect(NowPlayingWidgetLayout.medium.showsFeedbackControls)
    }

    @Test("uses compact controls in the small layout")
    func usesCompactControlsInSmallLayout() {
        #expect(!NowPlayingWidgetLayout.small.showsFeedbackControls)
    }
}
