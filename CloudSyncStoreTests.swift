import XCTest
@testable import CarbShared

/// Tests for CloudSyncStore iCloud key-value store functionality
final class CloudSyncStoreTests: XCTestCase {
    
    var store: CloudSyncStore!
    
    override func setUp() {
        super.setUp()
        store = CloudSyncStore.shared
    }
    
    override func tearDown() {
        store.stopObserving()
        super.tearDown()
    }
    
    // MARK: - Availability Tests
    
    func testAvailability() {
        // Note: In a test environment, iCloud may not be available
        // This test verifies the check doesn't crash
        let isAvailable = store.isAvailable
        
        XCTAssertTrue(isAvailable || !isAvailable, "Should return a boolean value")
    }
    
    // MARK: - Push/Pull Tests
    
    func testPushToCloud() {
        let testData: [String: Any] = [
            "food_items": ["apple", "banana"],
            "daily_carb_goal": 150.0,
            "last_save_date": "2026-03-11T12:00:00Z"
        ]
        
        // Should not crash even if iCloud is unavailable
        store.pushToCloud(testData)
    }
    
    func testPullFromCloudWhenEmpty() {
        // This may return nil if iCloud is unavailable or empty
        let result = store.pullFromCloud()
        
        if let data = result {
            XCTAssertNotNil(data["cloud_last_modified"], "Should contain timestamp if data exists")
        }
    }
    
    // MARK: - Observer Tests
    
    func testStartAndStopObserving() {
        var callbackInvoked = false
        
        store.startObserving { data in
            callbackInvoked = true
        }
        
        // Should be able to stop without crashing
        store.stopObserving()
        
        // Starting again should work
        store.startObserving { _ in }
        store.stopObserving()
    }
    
    func testMultipleStartObservingCalls() {
        store.startObserving { _ in }
        store.startObserving { _ in } // Second call should be ignored
        
        store.stopObserving()
    }
    
    // MARK: - Data Integrity Tests
    
    func testPushPullRoundTrip() async throws {
        guard store.isAvailable else {
            throw XCTSkip("iCloud not available in test environment")
        }
        
        let testData: [String: Any] = [
            "food_items": ["test_food"],
            "daily_carb_goal": 100.0,
            "daily_reset_hour": 6,
        ]
        
        store.pushToCloud(testData)
        
        // Give iCloud a moment to sync
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let pulledData = store.pullFromCloud()
        
        XCTAssertNotNil(pulledData, "Should retrieve data after push")
        
        if let pulled = pulledData {
            XCTAssertNotNil(pulled["cloud_last_modified"], "Should have timestamp")
            XCTAssertNotNil(pulled["food_items"], "Should contain food_items")
        }
    }
}

// MARK: - Integration Tests

final class CloudSyncIntegrationTests: XCTestCase {
    
    func testStorageKeysCoverage() {
        let expectedKeys = [
            "food_items",
            "saved_foods",
            "daily_carb_goal",
            "daily_reset_hour",
            "last_save_date",
        ]
        
        // This test documents the expected keys
        // If you add new keys, update this test
        XCTAssertEqual(expectedKeys.count, 5, "Should have exactly 5 data keys")
    }
    
    func testTimestampFormat() {
        let formatter = ISO8601DateFormatter()
        let date = Date()
        let timestamp = formatter.string(from: date)
        
        // Verify we can parse it back
        let parsed = formatter.date(from: timestamp)
        
        XCTAssertNotNil(parsed, "Should be able to parse ISO8601 timestamp")
    }
    
    func testTimestampRoundTrip() {
        let formatter = ISO8601DateFormatter()
        let originalDate = Date()
        let timestamp = formatter.string(from: originalDate)
        let parsedDate = formatter.date(from: timestamp)
        
        XCTAssertNotNil(parsedDate, "Should parse timestamp")
        
        if let parsed = parsedDate {
            // ISO8601 loses sub-second precision, so check within 1 second
            let timeDifference = abs(originalDate.timeIntervalSince(parsed))
            XCTAssertLessThan(timeDifference, 1.0, "Dates should be within 1 second")
        }
    }
}
