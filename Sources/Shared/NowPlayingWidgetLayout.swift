//
//  NowPlayingWidgetLayout.swift
//  Hermes
//

enum NowPlayingWidgetLayout: Equatable, Sendable {
    case small
    case medium

    var showsFeedbackControls: Bool {
        self == .medium
    }
}
