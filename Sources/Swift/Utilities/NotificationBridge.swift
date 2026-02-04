//
//  NotificationBridge.swift
//  Hermes
//
//  Bridges Objective-C NSNotifications to Combine publishers
//  All publishers dispatch to main thread since Obj-C posts from background threads
//

import Foundation
import Combine

extension NotificationCenter {
    var pandoraAuthenticatedPublisher: AnyPublisher<Void, Never> {
        publisher(for: Notification.Name("PandoraDidAuthenticateNotification"))
            .receive(on: DispatchQueue.main)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    var pandoraStationsLoadedPublisher: AnyPublisher<Void, Never> {
        publisher(for: Notification.Name("PandoraDidLoadStationsNotification"))
            .receive(on: DispatchQueue.main)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    var songPlayingPublisher: AnyPublisher<Song, Never> {
        publisher(for: Notification.Name("StationDidPlaySongNotification"))
            .receive(on: DispatchQueue.main)
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
            .receive(on: DispatchQueue.main)
            .compactMap { notification -> Bool? in
                // The notification object is the AudioStreamer
                guard let streamer = notification.object as? AudioStreamer else {
                    return nil
                }
                return streamer.isPlaying
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var pandoraErrorPublisher: AnyPublisher<String, Never> {
        publisher(for: Notification.Name("PandoraDidErrorNotification"))
            .receive(on: DispatchQueue.main)
            .compactMap { notification -> String? in
                // Pandora.m uses "err" key for error message
                if let err = notification.userInfo?["err"] as? String {
                    return err
                }
                // Fallback to "error" for any other sources
                return notification.userInfo?["error"] as? String
            }
            .eraseToAnyPublisher()
    }
}
