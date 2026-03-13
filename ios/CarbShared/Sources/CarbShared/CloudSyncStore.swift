import Foundation
import os.log

/// Syncs app data across devices using NSUbiquitousKeyValueStore (iCloud key-value store).
/// Placed in CarbShared so all targets (app, widget, watch, Siri) can access it.
///
/// Data flows entirely through the MethodChannel: Flutter serializes data on push
/// and writes it back to SharedPreferences on pull. This avoids UserDefaults domain
/// mismatches between the Flutter SharedPreferences store and the App Group store.
///
/// **Thread Safety:** All public methods are thread-safe and can be called from any thread.
/// Internally uses a serial queue to synchronize access to shared state.
@MainActor
public final class CloudSyncStore {
    
    // MARK: - Singleton
    
    public static let shared = CloudSyncStore()
    
    // MARK: - Properties

    private let kvStore = NSUbiquitousKeyValueStore.default
    private let logger = Logger(subsystem: "com.carpecarb", category: "CloudSyncStore")
    
    /// Keys synced to iCloud — must match StorageKeys in Dart
    private enum Key {
        static let foodItems = "food_items"
        static let savedFoods = "saved_foods"
        static let dailyCarbGoal = "daily_carb_goal"
        static let dailyResetHour = "daily_reset_hour"
        static let lastSaveDate = "last_save_date"
        static let lastModified = "cloud_last_modified"
    }

    /// All data keys (excluding the timestamp)
    private static let dataKeys = [
        Key.foodItems, Key.savedFoods, Key.dailyCarbGoal,
        Key.dailyResetHour, Key.lastSaveDate,
    ]

    /// Callback invoked when remote changes are detected
    /// Thread-safe: stored on MainActor
    private var onChange: (([String: Any]) -> Void)?
    
    /// Track observation state
    /// Thread-safe: stored on MainActor
    private var observing = false
    
    /// Track the last sync timestamp to detect changes
    /// Thread-safe: stored on MainActor
    private var lastKnownTimestamp: String?

    private init() {
        logger.info("CloudSyncStore initialized")
    }
    
    deinit {
        if observing {
            // Note: deinit is not async, so we do synchronous cleanup
            NotificationCenter.default.removeObserver(
                self,
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: kvStore
            )
            logger.info("CloudSyncStore deallocated - cleaned up observers")
        }
    }

    // MARK: - Availability

    /// Checks if iCloud is available for this user
    /// Thread-safe: FileManager is thread-safe for this property
    public var isAvailable: Bool {
        let available = FileManager.default.ubiquityIdentityToken != nil
        logger.debug("iCloud availability checked: \(available)")
        return available
    }

    // MARK: - Push (Flutter → iCloud)

    /// Writes the data dict received from Flutter directly into iCloud KV store.
    /// Flutter is responsible for providing all syncable keys.
    ///
    /// - Parameter data: Dictionary of key-value pairs to sync
    /// - Note: Thread-safe. Can be called from any thread.
    public func pushToCloud(_ data: [String: Any]) {
        guard isAvailable else {
            logger.warning("Push aborted: iCloud not available")
            return
        }
        
        guard !data.isEmpty else {
            logger.warning("Push aborted: Empty data provided")
            return
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        logger.info("Pushing \(data.count) keys to iCloud")

        // Write to NSUbiquitousKeyValueStore
        // Note: NSUbiquitousKeyValueStore is thread-safe
        for (key, value) in data {
            kvStore.set(value, forKey: key)
            logger.debug("Set key '\(key)'")
        }
        
        kvStore.set(timestamp, forKey: Key.lastModified)
        lastKnownTimestamp = timestamp
        
        // Note: synchronize() is deprecated but still used for forcing sync
        // The system will sync automatically, but this is best-effort
        let synced = kvStore.synchronize()
        
        if synced {
            logger.info("Successfully pushed to iCloud (timestamp: \(timestamp))")
        } else {
            logger.warning("Push completed but synchronize() returned false")
        }
    }

    // MARK: - Pull (iCloud → Flutter)

    /// Reads all data from iCloud KV store and returns it so Flutter can write
    /// it to SharedPreferences. Returns nil if iCloud is unavailable or empty.
    ///
    /// - Returns: Dictionary of synced data, or nil if unavailable/empty
    /// - Note: Thread-safe. Can be called from any thread.
    @discardableResult
    public func pullFromCloud() -> [String: Any]? {
        guard isAvailable else {
            logger.debug("Pull aborted: iCloud not available")
            return nil
        }

        // Best-effort sync from iCloud
        kvStore.synchronize()

        guard let timestamp = kvStore.string(forKey: Key.lastModified),
              !timestamp.isEmpty else {
            logger.info("Pull returned nil: No data in iCloud yet")
            return nil
        }

        var pulled: [String: Any] = [Key.lastModified: timestamp]

        for key in Self.dataKeys {
            if let value = kvStore.object(forKey: key) {
                pulled[key] = value
            }
        }
        
        lastKnownTimestamp = timestamp
        logger.info("Successfully pulled \(pulled.count) keys from iCloud (timestamp: \(timestamp))")

        return pulled
    }

    // MARK: - Observe Remote Changes
    
    /// Start listening for data pushed from other devices.
    ///
    /// - Parameter onChange: Callback invoked when remote changes are detected.
    ///   Called on the main thread.
    /// - Note: Thread-safe. Can be called from any thread.
    public func startObserving(onChange: @escaping ([String: Any]) -> Void) {
        // Check if already observing
        if observing {
            logger.warning("startObserving called but already observing - updating callback")
            self.onChange = onChange
            return
        }
        
        guard isAvailable else {
            logger.warning("Cannot start observing: iCloud not available")
            return
        }
        
        self.onChange = onChange
        observing = true

        // Add observer for external changes
        // NotificationCenter is thread-safe
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )
        
        logger.info("Started observing iCloud changes")
        
        // Initial sync
        kvStore.synchronize()
    }

    /// Stop listening for remote changes.
    /// - Note: Thread-safe. Safe to call multiple times.
    public func stopObserving() {
        guard observing else {
            logger.debug("stopObserving called but not currently observing")
            return
        }
        
        NotificationCenter.default.removeObserver(
            self,
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )
        
        observing = false
        onChange = nil
        
        logger.info("Stopped observing iCloud changes")
    }

    // MARK: - Notification Handlers
    
    /// Called when NSUbiquitousKeyValueStore detects external changes
    /// - Note: This is called on a background thread by NotificationCenter
    @objc private func kvStoreDidChange(_ notification: Notification) {
        logger.debug("Received external change notification")
        
        // Verify the notification is from our store
        guard let store = notification.object as? NSUbiquitousKeyValueStore,
              store == kvStore else {
            logger.warning("Notification from unexpected store - ignoring")
            return
        }
        
        // Get the change reason
        if let changeReason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int {
            logChangeReason(changeReason)
        }
        
        // Get changed keys if available
        if let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            logger.debug("Changed keys: \(changedKeys.joined(separator: ", "))")
        }
        
        // Pull the latest data
        // MainActor isolated method called from background thread needs await
        Task { @MainActor in
            if let pulled = self.pullFromCloud() {
                // Only notify if timestamp changed (avoid duplicate notifications)
                if let newTimestamp = pulled[Key.lastModified] as? String,
                   newTimestamp != self.lastKnownTimestamp {
                    logger.info("Notifying of remote change")
                    self.onChange?(pulled)
                } else {
                    logger.debug("Skipping notification - timestamp unchanged")
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Logs the change reason from the notification
    private func logChangeReason(_ reason: Int) {
        switch reason {
        case NSUbiquitousKeyValueStoreServerChange:
            logger.debug("Change reason: Server change")
        case NSUbiquitousKeyValueStoreInitialSyncChange:
            logger.debug("Change reason: Initial sync")
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            logger.error("Change reason: Quota violation!")
        case NSUbiquitousKeyValueStoreAccountChange:
            logger.info("Change reason: Account change")
        default:
            logger.debug("Change reason: Unknown (\(reason))")
        }
    }
}
// MARK: - Thread Safety Documentation

/*
 Thread Safety Implementation:
 
 1. @MainActor Isolation:
    - All public methods and properties are isolated to the MainActor
    - This ensures all state mutations happen on the main thread
    - Prevents data races on onChange, observing, and lastKnownTimestamp
 
 2. NSUbiquitousKeyValueStore Safety:
    - NSUbiquitousKeyValueStore is thread-safe by design
    - Can be accessed from any thread safely
 
 3. NotificationCenter Safety:
    - NotificationCenter is thread-safe
    - Notifications may be delivered on background threads
    - We use Task { @MainActor } to safely access isolated state
 
 4. Observer Pattern:
    - kvStoreDidChange may be called on a background thread
    - Uses Task { @MainActor } to hop to main thread for state access
    - onChange callback is invoked on main thread via MainActor
 
 Usage from any thread:
 
 ```swift
 // Safe to call from background thread
 Task {
     await CloudSyncStore.shared.pushToCloud(data)
 }
 
 // Safe to call from main thread
 await CloudSyncStore.shared.pushToCloud(data)
 ```
 
 Alternative: If @MainActor causes issues with existing code,
 see CloudSyncStore+SerialQueue.swift for a serial queue implementation.
 */

