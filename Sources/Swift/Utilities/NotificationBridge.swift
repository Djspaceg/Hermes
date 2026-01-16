//
//  NotificationBridge.swift
//  Hermes
//
//  Bridges Objective-C NSNotifications to Combine publishers
//

import Foundation
import Combine

extension NotificationCenter {
    var pandoraAuthenticatedPublisher: AnyPublisher<Void, Never> {
        publisher(for: Notification.Name("PandoraDidAuthenticateNotification"))
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    var pandoraStationsLoadedPublisher: AnyPublisher<Void, Never> {
        publisher(for: Notification.Name("PandoraDidLoadStationsNotification"))
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    var songPlayingPublisher: AnyPublisher<Song, Never> {
        publisher(for: Notification.Name("StationDidPlaySongNotification"))
            .compactMap { notification -> Song? in
                // The notification object is the Station
                guard let station = notification.object as? Station else {
                    return nil
                }
                return station.playingSong
            }
            .removeDuplicates { $0.title == $1.title && $0.artist == $1.artist }
            .eraseToAnyPublisher()
    }
    
    var playbackStatePublisher: AnyPublisher<Bool, Never> {
        publisher(for: Notification.Name("ASStatusChangedNotification"))
            .compactMap { notification -> Bool? in
                // The notification object is the AudioStreamer
                guard let streamer = notification.object as? AudioStreamer else {
                    return nil
                }
                return streamer.isPlaying()
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var pandoraErrorPublisher: AnyPublisher<String, Never> {
        publisher(for: Notification.Name("PandoraDidErrorNotification"))
            .compactMap { $0.userInfo?["error"] as? String }
            .eraseToAnyPublisher()
    }
}
