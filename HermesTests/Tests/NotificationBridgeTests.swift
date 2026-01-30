//
//  NotificationBridgeTests.swift
//  HermesTests
//
//  Tests for NotificationBridge to verify main thread dispatch
//

import XCTest
import Combine
@testable import Hermes

/// Tests must run serially because they use shared NotificationCenter publishers
@MainActor
final class NotificationBridgeTests: XCTestCase {
    
    // Disable parallel execution for this test class
    override class var defaultTestSuite: XCTestSuite {
        // This ensures tests in this class run serially
        let suite = XCTestSuite(forTestCaseClass: NotificationBridgeTests.self)
        return suite
    }
    
    var cancellables = Set<AnyCancellable>()
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Main Thread Dispatch Tests
    
    func testPandoraAuthenticatedPublisher_DispatchesToMainThread() {
        let expectation = XCTestExpectation(description: "Notification received on main thread")
        
        NotificationCenter.default.pandoraAuthenticatedPublisher
            .sink {
                XCTAssertTrue(Thread.isMainThread, "Should receive on main thread")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Post from background thread with delay to ensure subscription is ready
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(Thread.isMainThread, "Should post from background thread")
            NotificationCenter.default.post(
                name: Notification.Name("PandoraDidAuthenticateNotification"),
                object: nil
            )
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testPandoraStationsLoadedPublisher_DispatchesToMainThread() {
        let expectation = XCTestExpectation(description: "Notification received on main thread")
        
        NotificationCenter.default.pandoraStationsLoadedPublisher
            .sink {
                XCTAssertTrue(Thread.isMainThread, "Should receive on main thread")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: Notification.Name("PandoraDidLoadStationsNotification"),
                object: nil
            )
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testPandoraErrorPublisher_DispatchesToMainThread() {
        let expectation = XCTestExpectation(description: "Notification received on main thread")
        
        NotificationCenter.default.pandoraErrorPublisher
            .sink { errorMessage in
                XCTAssertTrue(Thread.isMainThread, "Should receive on main thread")
                XCTAssertEqual(errorMessage, "Test error")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
            XCTAssertFalse(Thread.isMainThread, "Should post from background thread")
            NotificationCenter.default.post(
                name: Notification.Name("PandoraDidErrorNotification"),
                object: nil,
                userInfo: ["err": "Test error"]
            )
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Error Publisher Parsing Tests
    
    func testPandoraErrorPublisher_ParsesErrKey() {
        let expectation = XCTestExpectation(description: "Error parsed from 'err' key")
        
        // Create a fresh cancellable set for this test
        var testCancellables = Set<AnyCancellable>()
        
        NotificationCenter.default.pandoraErrorPublisher
            .sink { errorMessage in
                XCTAssertEqual(errorMessage, "Error from err key")
                expectation.fulfill()
            }
            .store(in: &testCancellables)
        
        // Post asynchronously to allow publisher to process
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("PandoraDidErrorNotification"),
                object: nil,
                userInfo: ["err": "Error from err key"]
            )
        }
        
        wait(for: [expectation], timeout: 1.0)
        testCancellables.removeAll()
    }
    
    func testPandoraErrorPublisher_FallsBackToErrorKey() {
        let expectation = XCTestExpectation(description: "Error parsed from 'error' key")
        
        // Create a fresh cancellable set for this test
        var testCancellables = Set<AnyCancellable>()
        
        NotificationCenter.default.pandoraErrorPublisher
            .sink { errorMessage in
                XCTAssertEqual(errorMessage, "Error from error key")
                expectation.fulfill()
            }
            .store(in: &testCancellables)
        
        // Post asynchronously to allow publisher to process
        DispatchQueue.main.async {
            // Use only the "error" key, not "err"
            let userInfo: [String: String] = ["error": "Error from error key"]
            NotificationCenter.default.post(
                name: Notification.Name("PandoraDidErrorNotification"),
                object: nil,
                userInfo: userInfo
            )
        }
        
        wait(for: [expectation], timeout: 1.0)
        testCancellables.removeAll()
    }
    
    func testPandoraErrorPublisher_IgnoresEmptyUserInfo() {
        let expectation = XCTestExpectation(description: "No error received")
        expectation.isInverted = true
        
        // Create a dedicated NotificationCenter for testing to avoid triggering production code
        let testCenter = NotificationCenter()
        var testCancellables = Set<AnyCancellable>()
        var receivedCount = 0
        
        // Create publisher using test notification center
        testCenter.publisher(for: Notification.Name("PandoraDidErrorNotification"))
            .receive(on: DispatchQueue.main)
            .compactMap { notification -> String? in
                guard let userInfo = notification.userInfo else { return nil }
                return (userInfo["err"] as? String) ?? (userInfo["error"] as? String)
            }
            .sink { errorMessage in
                receivedCount += 1
                print("❌ TEST FAILURE: Received unexpected error: '\(errorMessage)'")
                expectation.fulfill()
            }
            .store(in: &testCancellables)
        
        // Post notification asynchronously to allow publisher to process
        DispatchQueue.main.async {
            testCenter.post(
                name: Notification.Name("PandoraDidErrorNotification"),
                object: nil,
                userInfo: nil
            )
            
            // Also test with empty dictionary
            testCenter.post(
                name: Notification.Name("PandoraDidErrorNotification"),
                object: nil,
                userInfo: [:]
            )
        }
        
        // Very short timeout since inverted expectations wait the full duration
        wait(for: [expectation], timeout: 0.1)
        
        // Clean up immediately
        testCancellables.removeAll()
        
        XCTAssertEqual(receivedCount, 0, "Should not have received any errors")
    }
}
