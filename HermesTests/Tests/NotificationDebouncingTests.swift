//
//  NotificationDebouncingTests.swift
//  HermesTests
//
//  Property tests for notification debouncing behavior
//  Validates: Requirements 22.1, 22.3
//

import XCTest
import Combine
@testable import Hermes

/// Tests notification debouncing to ensure high-frequency notifications are properly throttled
@MainActor
final class NotificationDebouncingTests: XCTestCase {
    
    var cancellables = Set<AnyCancellable>()
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Property 3: Notification Debouncing Reduces Frequency
    
    /// **Validates: Requirements 22.1**
    ///
    /// Property: For any rapid sequence of notifications (more than 10 per second),
    /// debouncing should reduce the processing frequency to at most one per debounce interval.
    func testProgressNotificationDebouncing_ReducesFrequency() async throws {
        let testCenter = NotificationCenter()
        let receivedCount = ActorCounter()
        let expectation = XCTestExpectation(description: "Debounced notifications received")
        expectation.expectedFulfillmentCount = 1
        
        // Subscribe with debouncing (100ms)
        testCenter.publisher(for: .playbackProgressDidChange)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                Task {
                    await receivedCount.increment()
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Post 20 notifications rapidly (within 200ms = 100 per second)
        let postCount = 20
        for i in 0..<postCount {
            testCenter.post(
                name: .playbackProgressDidChange,
                object: nil,
                userInfo: ["progress": Double(i), "duration": 100.0]
            )
            // Small delay between posts (10ms = 100 per second)
            try await Task.sleep(for: .milliseconds(10))
        }
        
        // Wait for debounce period plus buffer
        try await Task.sleep(for: .milliseconds(150))
        
        let received = await receivedCount.value
        
        // With 100ms debounce and 200ms of rapid posts, we should get 1-2 notifications max
        // (one during the sequence, possibly one at the end)
        XCTAssertLessThanOrEqual(
            received,
            3,
            "Debouncing should reduce \(postCount) rapid notifications to at most 3 processed notifications"
        )
        
        // Verify significant reduction
        let reductionRatio = Double(received) / Double(postCount)
        XCTAssertLessThan(
            reductionRatio,
            0.2,
            "Debouncing should reduce notification processing by at least 80%"
        )
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /// **Validates: Requirements 22.1**
    ///
    /// Property: Audio status change notifications should be debounced to reduce UI update frequency
    func testAudioStatusChangeDebouncing_ReducesFrequency() async throws {
        let testCenter = NotificationCenter()
        let receivedCount = ActorCounter()
        let expectation = XCTestExpectation(description: "Debounced audio status received")
        expectation.expectedFulfillmentCount = 1
        
        // Subscribe with debouncing (100ms)
        testCenter.publisher(for: .audioStatusChanged)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                Task {
                    await receivedCount.increment()
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Post 15 notifications rapidly
        let postCount = 15
        for _ in 0..<postCount {
            testCenter.post(name: .audioStatusChanged, object: nil)
            try await Task.sleep(for: .milliseconds(10))
        }
        
        // Wait for debounce period
        try await Task.sleep(for: .milliseconds(150))
        
        let received = await receivedCount.value
        
        // Should receive significantly fewer notifications than posted
        XCTAssertLessThanOrEqual(
            received,
            3,
            "Debouncing should reduce \(postCount) rapid notifications to at most 3"
        )
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Property 4: Debouncing Processes Latest Value
    
    /// **Validates: Requirements 22.3**
    ///
    /// Property: For any debounced notification sequence, the final processed value
    /// should match the last notification value in the sequence.
    func testProgressNotificationDebouncing_ProcessesLatestValue() async throws {
        let testCenter = NotificationCenter()
        let receivedValues = ActorValueStore()
        let expectation = XCTestExpectation(description: "Latest value received")
        expectation.expectedFulfillmentCount = 1
        
        // Subscribe with debouncing
        testCenter.publisher(for: .playbackProgressDidChange)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { notification in
                Task {
                    if let progress = notification.userInfo?["progress"] as? Double {
                        await receivedValues.append(progress)
                        expectation.fulfill()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Post sequence of progress values
        let progressValues = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
        for progress in progressValues {
            testCenter.post(
                name: .playbackProgressDidChange,
                object: nil,
                userInfo: ["progress": progress, "duration": 200.0]
            )
            try await Task.sleep(for: .milliseconds(10))
        }
        
        // Wait for debounce to complete
        try await Task.sleep(for: .milliseconds(150))
        
        let received = await receivedValues.values
        
        // The last received value should be the last posted value
        XCTAssertFalse(received.isEmpty, "Should receive at least one value")
        if let lastReceived = received.last {
            XCTAssertEqual(
                lastReceived,
                progressValues.last,
                "Debouncing should process the latest value (100.0)"
            )
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /// **Validates: Requirements 22.3**
    ///
    /// Property: Multiple rapid bursts should each process their latest value
    func testMultipleBursts_ProcessLatestValueInEachBurst() async throws {
        let testCenter = NotificationCenter()
        let receivedValues = ActorValueStore()
        
        // Subscribe with debouncing
        testCenter.publisher(for: .playbackProgressDidChange)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { notification in
                Task {
                    if let progress = notification.userInfo?["progress"] as? Double {
                        await receivedValues.append(progress)
                    }
                }
            }
            .store(in: &cancellables)
        
        // First burst: 10-20
        for i in 10...20 {
            testCenter.post(
                name: .playbackProgressDidChange,
                object: nil,
                userInfo: ["progress": Double(i), "duration": 200.0]
            )
            try await Task.sleep(for: .milliseconds(5))
        }
        
        // Wait for debounce
        try await Task.sleep(for: .milliseconds(150))
        
        // Second burst: 30-40
        for i in 30...40 {
            testCenter.post(
                name: .playbackProgressDidChange,
                object: nil,
                userInfo: ["progress": Double(i), "duration": 200.0]
            )
            try await Task.sleep(for: .milliseconds(5))
        }
        
        // Wait for debounce
        try await Task.sleep(for: .milliseconds(150))
        
        let received = await receivedValues.values
        
        // Should have received values from both bursts
        XCTAssertGreaterThanOrEqual(received.count, 2, "Should process at least one value per burst")
        
        // Check that we got values near the end of each burst
        let hasFirstBurstValue = received.contains { $0 >= 18.0 && $0 <= 20.0 }
        let hasSecondBurstValue = received.contains { $0 >= 38.0 && $0 <= 40.0 }
        
        XCTAssertTrue(hasFirstBurstValue, "Should process latest value from first burst (18-20)")
        XCTAssertTrue(hasSecondBurstValue, "Should process latest value from second burst (38-40)")
    }
    
    // MARK: - Debounce Interval Consistency
    
    /// **Validates: Requirements 22.2**
    ///
    /// Verify that all debounced notifications use consistent 100ms interval
    func testDebouncingUsesConsistentInterval() async throws {
        let testCenter = NotificationCenter()
        let timestamps = ActorTimestampStore()
        
        // Subscribe with 100ms debounce
        testCenter.publisher(for: .playbackProgressDidChange)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                Task {
                    await timestamps.recordTimestamp()
                }
            }
            .store(in: &cancellables)
        
        // Post rapid notifications for 500ms
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < 0.5 {
            testCenter.post(
                name: .playbackProgressDidChange,
                object: nil,
                userInfo: ["progress": 50.0, "duration": 200.0]
            )
            try await Task.sleep(for: .milliseconds(10))
        }
        
        // Wait for final debounce
        try await Task.sleep(for: .milliseconds(150))
        
        let recordedTimestamps = await timestamps.timestamps
        
        // Verify intervals between received notifications are >= 100ms
        for i in 1..<recordedTimestamps.count {
            let interval = recordedTimestamps[i].timeIntervalSince(recordedTimestamps[i-1])
            XCTAssertGreaterThanOrEqual(
                interval,
                0.09, // Allow small timing variance
                "Debounce interval should be at least 100ms between processed notifications"
            )
        }
    }
}

// MARK: - Test Helpers

/// Thread-safe counter for async tests
actor ActorCounter {
    private var count = 0
    
    func increment() {
        count += 1
    }
    
    var value: Int {
        count
    }
}

/// Thread-safe value store for async tests
actor ActorValueStore {
    private var storage: [Double] = []
    
    func append(_ value: Double) {
        storage.append(value)
    }
    
    var values: [Double] {
        storage
    }
}

/// Thread-safe timestamp store for async tests
actor ActorTimestampStore {
    private var storage: [Date] = []
    
    func recordTimestamp() {
        storage.append(Date())
    }
    
    var timestamps: [Date] {
        storage
    }
}
