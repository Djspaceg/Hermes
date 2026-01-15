//
//  NotificationManager.swift
//  Hermes
//
//  Modern notification manager using UserNotifications framework
//

import Foundation
import UserNotifications
import AppKit

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = NotificationManager()
    
    // MARK: - Properties
    
    @Published var isAuthorized = false
    
    // MARK: - Notification Categories
    
    private let songCategoryIdentifier = "SONG_NOTIFICATION"
    private let skipActionIdentifier = "SKIP_ACTION"
    private let likeActionIdentifier = "LIKE_ACTION"
    private let dislikeActionIdentifier = "DISLIKE_ACTION"
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupNotificationCategories()
        checkAuthorization()
    }
    
    // MARK: - Setup
    
    private func setupNotificationCategories() {
        let skipAction = UNNotificationAction(
            identifier: skipActionIdentifier,
            title: "Skip",
            options: []
        )
        
        let likeAction = UNNotificationAction(
            identifier: likeActionIdentifier,
            title: "Like",
            options: []
        )
        
        let dislikeAction = UNNotificationAction(
            identifier: dislikeActionIdentifier,
            title: "Dislike",
            options: []
        )
        
        let songCategory = UNNotificationCategory(
            identifier: songCategoryIdentifier,
            actions: [skipAction, likeAction, dislikeAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([songCategory])
        UNUserNotificationCenter.current().delegate = self
    }
    
    private func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Public Methods
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("NotificationManager: Authorization request failed - \(error)")
            return false
        }
    }
    
    func showSongNotification(song: Song, image: NSImage?, isNewSong: Bool) {
        // Check user preferences
        let defaults = UserDefaults.standard
        let notificationsEnabled = defaults.bool(forKey: UserDefaultsKeys.pleaseGrowl)
        let notifyOnNew = defaults.bool(forKey: UserDefaultsKeys.pleaseGrowlNew)
        let notifyOnPlay = defaults.bool(forKey: UserDefaultsKeys.pleaseGrowlPlay)
        
        guard notificationsEnabled else { return }
        guard (isNewSong && notifyOnNew) || (!isNewSong && notifyOnPlay) else { return }
        
        // Remove previous notifications
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        // Build notification content
        let content = UNMutableNotificationContent()
        
        var title = song.title ?? "Unknown Song"
        if song.nrating?.intValue == 1 {
            title = "👍 \(title)"
        }
        content.title = title
        
        let artist = song.artist ?? "Unknown Artist"
        let album = song.album ?? "Unknown Album"
        content.body = "\(artist)\n\(album)"
        
        content.categoryIdentifier = songCategoryIdentifier
        content.sound = nil // Silent - music is playing
        
        // Add album art as attachment if available
        if let image = image {
            addImageAttachment(image: image, to: content)
        }
        
        // Create and schedule notification
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("NotificationManager: Failed to show notification - \(error)")
            }
        }
    }
    
    private func addImageAttachment(image: NSImage, to content: UNMutableNotificationContent) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        
        do {
            try pngData.write(to: tempURL)
            let attachment = try UNNotificationAttachment(
                identifier: "albumArt",
                url: tempURL,
                options: nil
            )
            content.attachments = [attachment]
        } catch {
            print("NotificationManager: Failed to create image attachment - \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Always show notifications even when app is active
        return [.banner]
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            handleNotificationResponse(response)
        }
    }
    
    @MainActor
    private func handleNotificationResponse(_ response: UNNotificationResponse) {
        guard let playbackController = MinimalAppDelegate.shared?.playbackController else {
            return
        }
        
        switch response.actionIdentifier {
        case skipActionIdentifier:
            playbackController.next()
            
        case likeActionIdentifier:
            playbackController.likeCurrent()
            
        case dislikeActionIdentifier:
            playbackController.dislikeCurrent()
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification - bring app to front
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            
        default:
            break
        }
        
        // Remove delivered notifications
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
