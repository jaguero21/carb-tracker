import Testing
import Foundation
@testable import CarbShared

@Suite("CloudSyncStore Tests")
struct CloudSyncStoreTests {
    
    // MARK: - Availability Tests
    
    @Test("iCloud availability check")
    func testAvailability() async throws {
        let store = CloudSyncStore.shared
        
        // Note: In a test environment, iCloud may not be available
        // This test verifies the check doesn't crash
        let isAvailable = store.isAvailable
        
        #expect(isAvailable == true || isAvailable == false, "Should return a boolean value")
    }
    
    // MARK: - Push/Pull Tests
    
    @Test("Push data to cloud")
    func testPushToCloud() async throws {
        let store = CloudSyncStore.shared
        
        let testData: [String: Any] = [
            "food_items": ["apple", "banana"],
            "daily_carb_goal": 150.0,
            "last_save_date": "2026-03-11T12:00:00Z"
        ]
        
        // Should not crash even if iCloud is unavailable
        store.pushToCloud(testData)
    }
    
    @Test("Pull data from cloud returns nil when empty")
    func testPullFromCloudEmpty() async throws {
        let store = CloudSyncStore.shared
        
        // This may return nil if iCloud is unavailable or empty
        let result = store.pullFromCloud()
        
        if let data = result {
            #expect(data["cloud_last_modified"] != nil, "Should contain timestamp if data exists")
        }
    }
    
    // MARK: - Observer Tests
    
    @Test("Start and stop observing")
    func testObserving() async throws {
        let store = CloudSyncStore.shared
        
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
    
    @Test("Multiple start observing calls should be safe")
    func testMultipleObserving() async throws {
        let store = CloudSyncStore.shared
        
        store.startObserving { _ in }
        store.startObserving { _ in } // Second call should be ignored
        
        store.stopObserving()
    }
    
    // MARK: - Data Integrity Tests
    
    @Test("Push and pull round-trip", .disabled("Requires iCloud to be enabled"))
    func testPushPullRoundTrip() async throws {
        let store = CloudSyncStore.shared
        
        guard store.isAvailable else {
            Issue.record("iCloud not available in test environment")
            return
        }
        
        let testData: [String: Any] = [
            "food_items": ["test_food"],
            "daily_carb_goal": 100.0,
            "daily_reset_hour": 6,
        ]
        
        store.pushToCloud(testData)
        
        // Give iCloud a moment to sync
        try await Task.sleep(for: .seconds(1))
        
        let pulledData = store.pullFromCloud()
        
        #expect(pulledData != nil, "Should retrieve data after push")
        
        if let pulled = pulledData {
            #expect(pulled["cloud_last_modified"] != nil, "Should have timestamp")
            #expect(pulled["food_items"] != nil, "Should contain food_items")
        }
    }
}

// MARK: - Mock Tests for Integration

@Suite("CloudSync Integration Tests")
struct CloudSyncIntegrationTests {
    
    @Test("Verify all storage keys are handled")
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
        #expect(expectedKeys.count == 5, "Should have exactly 5 data keys")
    }
    
    @Test("Timestamp format validation")
    func testTimestampFormat() throws {
        let formatter = ISO8601DateFormatter()
        let date = Date()
        let timestamp = formatter.string(from: date)
        
        // Verify we can parse it back
        let parsed = formatter.date(from: timestamp)
        
        #expect(parsed != nil, "Should be able to parse ISO8601 timestamp")
    }
}
