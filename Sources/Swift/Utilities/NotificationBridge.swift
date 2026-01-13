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
            .handleEvents(receiveOutput: { _ in
                print("NotificationBridge: Received PandoraDidAuthenticateNotification")
            })
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    var pandoraStationsLoadedPublisher: AnyPublisher<Void, Never> {
        publisher(for: Notification.Name("PandoraDidLoadStationsNotification"))
            .handleEvents(receiveOutput: { _ in
                print("NotificationBridge: Received PandoraDidLoadStationsNotification")
            })
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    var songPlayingPublisher: AnyPublisher<Song, Never> {
        publisher(for: Notification.Name("StationDidPlaySongNotification"))
            .handleEvents(receiveOutput: { notification in
                print("NotificationBridge: Received StationDidPlaySongNotification")
                print("NotificationBridge: Notification object = \(String(describing: notification.object))")
            })
            .compactMap { notification -> Song? in
                // The notification object is the Station
                guard let station = notification.object as? Station else {
                    print("NotificationBridge: ERROR - notification object is not a Station!")
                    return nil
                }
                let song = station.playingSong
                print("NotificationBridge: Got song from station - \(song?.title ?? "nil")")
                return song
            }
            .eraseToAnyPublisher()
    }
    
    var playbackStatePublisher: AnyPublisher<Bool, Never> {
        publisher(for: Notification.Name("ASStatusChangedNotification"))
            .handleEvents(receiveOutput: { notification in
                print("NotificationBridge: Received ASStatusChangedNotification")
                print("NotificationBridge: Notification object = \(String(describing: notification.object))")
            })
            .compactMap { notification -> Bool? in
                // The notification object is the AudioStreamer
                // We need to check if any station is playing
                // For now, we'll assume if the notification is posted, something changed
                // The actual state needs to be queried from the Station
                guard let streamer = notification.object as? AudioStreamer else {
                    print("NotificationBridge: Object is not AudioStreamer")
                    return nil
                }
                
                // Check if the streamer is playing
                let isPlaying = streamer.isPlaying()
                print("NotificationBridge: AudioStreamer isPlaying = \(isPlaying)")
                return isPlaying
            }
            .eraseToAnyPublisher()
    }
    
    var pandoraErrorPublisher: AnyPublisher<String, Never> {
        publisher(for: Notification.Name("PandoraDidErrorNotification"))
            .handleEvents(receiveOutput: { _ in
                print("NotificationBridge: Received PandoraDidErrorNotification")
            })
            .compactMap { $0.userInfo?["error"] as? String }
            .eraseToAnyPublisher()
    }
}
