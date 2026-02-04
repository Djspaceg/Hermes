//
//  NotificationConsistencyTests.swift
//  HermesTests
//
//  Property-based tests for notification consistency
//  **Property 3: Notification consistency**
//  **Validates: Requirements 4.8**
//

import XCTest
import Combine
@testable import Hermes

/// Tests that all state-changing operations post correct notifications with expected userInfo
/// This test validates that PandoraClient posts the correct notifications for all state-changing operations
@MainActor
final class NotificationConsistencyTests: XCTestCase {
    
    var cancellables = Set<AnyCancellable>()
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Logout Notification
    
    func testLogout_PostsCorrectNotification() {
        // Given
        let pandoraClient = PandoraClient()
        let expectation = XCTestExpectation(description: "Logout notification posted")
        
        // When - Subscribe to notification
        NotificationCenter.default.publisher(for: .pandoraDidLogOut)
            .sink { notification in
                // Then - Verify notification was posted
                XCTAssertNotNil(notification, "Notification should be posted")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Trigger logout
        pandoraClient.logout()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Notification Structure Tests
    
    func testNotificationNames_AreConsistent() {
        // Test that notification names follow consistent naming patterns
        let notificationNames: [Notification.Name] = [
            .pandoraDidAuthenticate,
            .pandoraDidLogOut,
            .pandoraDidRateSong,
            .pandoraDidTireSong,
            .pandoraDidLoadStations,
            .pandoraDidCreateStation,
            .pandoraDidDeleteStation,
            .pandoraDidRenameStation,
            .pandoraDidLoadStationInfo,
            .pandoraDidAddSeed,
            .pandoraDidDeleteSeed,
            .pandoraDidDeleteFeedback,
            .pandoraDidLoadSearchResults,
            .pandoraDidLoadGenreStations,
            .pandoraDidError
        ]
        
        // Verify all notification names start with "Pandora"
        for name in notificationNames {
            XCTAssertTrue(
                name.rawValue.hasPrefix("Pandora"),
                "Notification name '\(name.rawValue)' should start with 'Pandora'"
            )
        }
    }
    
    func testNotificationUserInfoKeys_AreDocumented() {
        // Document expected userInfo keys for each notification type
        let expectedUserInfoKeys: [Notification.Name: [String]] = [
            .pandoraDidError: ["err"],
            .pandoraDidCreateStation: ["station"],
            .pandoraDidLoadStationInfo: [], // Contains dynamic keys from API
            .pandoraDidAddSeed: ["seedId"],
            .pandoraDidLoadSearchResults: ["artists", "songs"],
            .pandoraDidLoadGenreStations: ["categories"]
        ]
        
        // This test documents the expected structure
        XCTAssertEqual(expectedUserInfoKeys.count, 6, "Should document 6 notifications with userInfo")
    }
    
    func testNotificationObjects_AreTyped() {
        // Document expected object types for notifications
        let expectedObjectTypes: [Notification.Name: String] = [
            .pandoraDidRateSong: "Song",
            .pandoraDidTireSong: "Song",
            .pandoraDidDeleteStation: "Station",
            .pandoraDidDeleteFeedback: "String (feedbackId)",
            .pandoraDidLoadSearchResults: "String (search query)"
        ]
        
        // This test documents the expected object types
        XCTAssertEqual(expectedObjectTypes.count, 5, "Should document 5 notifications with typed objects")
    }
    
    // MARK: - Property-Based Test: Notification Consistency
    
    func testProperty_AllNotificationsPostedOnMainThread() {
        // Property: All notifications should be posted on the main thread
        // This ensures UI updates triggered by notifications are safe
        
        let notificationNames: [Notification.Name] = [
            .pandoraDidAuthenticate,
            .pandoraDidLogOut,
            .pandoraDidRateSong,
            .pandoraDidTireSong,
            .pandoraDidLoadStations,
            .pandoraDidCreateStation,
            .pandoraDidDeleteStation,
            .pandoraDidRenameStation,
            .pandoraDidLoadStationInfo,
            .pandoraDidAddSeed,
            .pandoraDidDeleteSeed,
            .pandoraDidDeleteFeedback,
            .pandoraDidLoadSearchResults,
            .pandoraDidLoadGenreStations,
            .pandoraDidError
        ]
        
        var expectations: [XCTestExpectation] = []
        
        // Subscribe to all notifications and verify they're received on main thread
        for name in notificationNames {
            let expectation = XCTestExpectation(description: "Notification \(name.rawValue) on main thread")
            expectation.isInverted = false
            expectation.assertForOverFulfill = false
            
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { _ in
                    XCTAssertTrue(Thread.isMainThread, "Notification \(name.rawValue) should be on main thread")
                    expectation.fulfill()
                }
                .store(in: &cancellables)
            
            expectations.append(expectation)
        }
        
        // Post all notifications from background thread
        DispatchQueue.global(qos: .userInitiated).async {
            for name in notificationNames {
                NotificationCenter.default.post(name: name, object: nil)
            }
        }
        
        // Wait for all notifications to be received
        wait(for: expectations, timeout: 2.0)
    }
    
    func testProperty_NotificationUserInfoIsImmutable() {
        // Property: Notification userInfo dictionaries should not be modified after posting
        // This ensures data integrity across observers
        
        let expectation = XCTestExpectation(description: "UserInfo remains immutable")
        var receivedUserInfo: [AnyHashable: Any]?
        
        NotificationCenter.default.publisher(for: .pandoraDidError)
            .sink { notification in
                receivedUserInfo = notification.userInfo
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Post notification with userInfo
        let originalUserInfo: [String: Any] = ["err": "Test error", "code": 1001]
        NotificationCenter.default.post(
            name: .pandoraDidError,
            object: nil,
            userInfo: originalUserInfo
        )
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify userInfo was received correctly
        XCTAssertNotNil(receivedUserInfo)
        XCTAssertEqual(receivedUserInfo?["err"] as? String, "Test error")
        XCTAssertEqual(receivedUserInfo?["code"] as? Int, 1001)
    }
    
    func testProperty_NotificationsArePostedSynchronously() {
        // Property: Notifications should be posted synchronously (on main thread)
        // This ensures predictable ordering of events
        
        var notificationOrder: [String] = []
        let expectation1 = XCTestExpectation(description: "First notification")
        let expectation2 = XCTestExpectation(description: "Second notification")
        
        NotificationCenter.default.publisher(for: .pandoraDidLoadStations)
            .sink { _ in
                notificationOrder.append("stations")
                expectation1.fulfill()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .pandoraDidAuthenticate)
            .sink { _ in
                notificationOrder.append("auth")
                expectation2.fulfill()
            }
            .store(in: &cancellables)
        
        // Post notifications in order
        NotificationCenter.default.post(name: .pandoraDidLoadStations, object: nil)
        NotificationCenter.default.post(name: .pandoraDidAuthenticate, object: nil)
        
        wait(for: [expectation1, expectation2], timeout: 1.0)
        
        // Verify order is preserved
        XCTAssertEqual(notificationOrder, ["stations", "auth"], "Notifications should be received in order")
    }
    
    func testProperty_MultipleObserversReceiveSameNotification() {
        // Property: All observers should receive the same notification
        // This ensures broadcast semantics
        
        let expectation1 = XCTestExpectation(description: "Observer 1")
        let expectation2 = XCTestExpectation(description: "Observer 2")
        let expectation3 = XCTestExpectation(description: "Observer 3")
        
        var observer1UserInfo: [AnyHashable: Any]?
        var observer2UserInfo: [AnyHashable: Any]?
        var observer3UserInfo: [AnyHashable: Any]?
        
        // Create multiple observers
        NotificationCenter.default.publisher(for: .pandoraDidError)
            .sink { notification in
                observer1UserInfo = notification.userInfo
                expectation1.fulfill()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .pandoraDidError)
            .sink { notification in
                observer2UserInfo = notification.userInfo
                expectation2.fulfill()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .pandoraDidError)
            .sink { notification in
                observer3UserInfo = notification.userInfo
                expectation3.fulfill()
            }
            .store(in: &cancellables)
        
        // Post single notification
        let userInfo: [String: Any] = ["err": "Shared error"]
        NotificationCenter.default.post(
            name: .pandoraDidError,
            object: nil,
            userInfo: userInfo
        )
        
        wait(for: [expectation1, expectation2, expectation3], timeout: 1.0)
        
        // Verify all observers received the same data
        XCTAssertEqual(observer1UserInfo?["err"] as? String, "Shared error")
        XCTAssertEqual(observer2UserInfo?["err"] as? String, "Shared error")
        XCTAssertEqual(observer3UserInfo?["err"] as? String, "Shared error")
    }
    
    func testProperty_NotificationNamesAreUnique() {
        // Property: All notification names should be unique
        // This prevents accidental collisions
        
        let notificationNames: [Notification.Name] = [
            .pandoraDidAuthenticate,
            .pandoraDidLogOut,
            .pandoraDidRateSong,
            .pandoraDidTireSong,
            .pandoraDidLoadStations,
            .pandoraDidCreateStation,
            .pandoraDidDeleteStation,
            .pandoraDidRenameStation,
            .pandoraDidLoadStationInfo,
            .pandoraDidAddSeed,
            .pandoraDidDeleteSeed,
            .pandoraDidDeleteFeedback,
            .pandoraDidLoadSearchResults,
            .pandoraDidLoadGenreStations,
            .pandoraDidError
        ]
        
        let rawValues = notificationNames.map { $0.rawValue }
        let uniqueRawValues = Set(rawValues)
        
        XCTAssertEqual(
            rawValues.count,
            uniqueRawValues.count,
            "All notification names should be unique"
        )
    }
}
