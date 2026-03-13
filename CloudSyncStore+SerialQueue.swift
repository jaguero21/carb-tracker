import Foundation
import os.log

/// Alternative thread-safe implementation using a serial DispatchQueue.
/// Use this version if @MainActor causes integration issues with existing code.
///
/// To use: Replace CloudSyncStore.swift with this file.
public final class CloudSyncStore_SerialQueue {
    
    // MARK: - Singleton
    
    public static let shared = CloudSyncStore_SerialQueue()
    
    // MARK: - Properties
    
    /// Serial queue for thread-safe access to mutable state
    private let syncQueue = DispatchQueue(
        label: "com.carpecarb.cloudsync",
        qos: .userInitiated
    )

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

    /// Protected by syncQueue
    private var onChange: (([String: Any]) -> Void)?
    
    /// Protected by syncQueue
    private var observing = false
    
    /// Protected by syncQueue
    private var lastKnownTimestamp: String?

    private init() {
        logger.info("CloudSyncStore initialized with serial queue")
    }
    
    deinit {
        // Synchronous cleanup
        syncQueue.sync {
            if observing {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                    object: kvStore
                )
                logger.info("CloudSyncStore deallocated - cleaned up observers")
            }
        }
    }

    // MARK: - Availability

    /// Thread-safe: FileManager is thread-safe for this property
    public var isAvailable: Bool {
        let available = FileManager.default.ubiquityIdentityToken != nil
        logger.debug("iCloud availability: \(available)")
        return available
    }

    // MARK: - Push (Thread-safe via barrier)

    public func pushToCloud(_ data: [String: Any]) {
        syncQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            guard self.isAvailable else {
                self.logger.warning("Push aborted: iCloud not available")
                return
            }
            
            guard !data.isEmpty else {
                self.logger.warning("Push aborted: Empty data")
                return
            }

            let timestamp = ISO8601DateFormatter().string(from: Date())
            
            self.logger.info("Pushing \(data.count) keys to iCloud")

            for (key, value) in data {
                self.kvStore.set(value, forKey: key)
            }
            
            self.kvStore.set(timestamp, forKey: Key.lastModified)
            self.lastKnownTimestamp = timestamp
            
            let synced = self.kvStore.synchronize()
            
            if synced {
                self.logger.info("Successfully pushed (timestamp: \(timestamp))")
            } else {
                self.logger.warning("synchronize() returned false")
            }
        }
    }

    // MARK: - Pull (Thread-safe)

    @discardableResult
    public func pullFromCloud() -> [String: Any]? {
        syncQueue.sync { [weak self] in
            guard let self = self else { return nil }
            
            guard self.isAvailable else {
                self.logger.debug("Pull aborted: iCloud not available")
                return nil
            }

            self.kvStore.synchronize()

            guard let timestamp = self.kvStore.string(forKey: Key.lastModified),
                  !timestamp.isEmpty else {
                self.logger.info("Pull returned nil: No data in iCloud")
                return nil
            }

            var pulled: [String: Any] = [Key.lastModified: timestamp]

            for key in Self.dataKeys {
                if let value = self.kvStore.object(forKey: key) {
                    pulled[key] = value
                }
            }
            
            self.lastKnownTimestamp = timestamp
            self.logger.info("Successfully pulled \(pulled.count) keys")

            return pulled
        }
    }

    // MARK: - Observe (Thread-safe)
    
    public func startObserving(onChange: @escaping ([String: Any]) -> Void) {
        syncQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if self.observing {
                self.logger.warning("Already observing - updating callback")
                self.onChange = onChange
                return
            }
            
            guard self.isAvailable else {
                self.logger.warning("Cannot observe: iCloud not available")
                return
            }
            
            self.onChange = onChange
            self.observing = true

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.kvStoreDidChange(_:)),
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: self.kvStore
            )
            
            self.logger.info("Started observing")
            self.kvStore.synchronize()
        }
    }

    public func stopObserving() {
        syncQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            guard self.observing else {
                self.logger.debug("Not currently observing")
                return
            }
            
            NotificationCenter.default.removeObserver(
                self,
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: self.kvStore
            )
            
            self.observing = false
            self.onChange = nil
            
            self.logger.info("Stopped observing")
        }
    }

    // MARK: - Notification Handler
    
    @objc private func kvStoreDidChange(_ notification: Notification) {
        logger.debug("External change notification received")
        
        guard let store = notification.object as? NSUbiquitousKeyValueStore,
              store == kvStore else {
            logger.warning("Unexpected store - ignoring")
            return
        }
        
        if let changeReason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int {
            logChangeReason(changeReason)
        }
        
        // Access callback on syncQueue
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let pulled = self.pullFromCloud() {
                if let newTimestamp = pulled[Key.lastModified] as? String,
                   newTimestamp != self.lastKnownTimestamp {
                    
                    // Capture callback to call outside the lock
                    let callback = self.onChange
                    
                    // Call on main thread for Flutter
                    DispatchQueue.main.async {
                        callback?(pulled)
                    }
                    
                    self.logger.info("Notified of remote change")
                } else {
                    self.logger.debug("Timestamp unchanged - skipping")
                }
            }
        }
    }
    
    private func logChangeReason(_ reason: Int) {
        switch reason {
        case NSUbiquitousKeyValueStoreServerChange:
            logger.debug("Server change")
        case NSUbiquitousKeyValueStoreInitialSyncChange:
            logger.debug("Initial sync")
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            logger.error("Quota violation!")
        case NSUbiquitousKeyValueStoreAccountChange:
            logger.info("Account change")
        default:
            logger.debug("Unknown reason: \(reason)")
        }
    }
}

// MARK: - Thread Safety Documentation

/*
 Serial Queue Thread Safety:
 
 1. All mutable state is protected by `syncQueue`
    - onChange: Read/write on syncQueue
    - observing: Read/write on syncQueue
    - lastKnownTimestamp: Read/write on syncQueue
 
 2. Barrier flags for write operations:
    - pushToCloud: Uses .barrier to ensure exclusive access
    - startObserving: Uses .barrier for state mutation
    - stopObserving: Uses .barrier for state mutation
 
 3. Sync for read operations:
    - pullFromCloud: Uses sync to return value safely
    - isAvailable: Thread-safe by nature (FileManager)
 
 4. NotificationCenter callbacks:
    - May arrive on any thread
    - Immediately hop to syncQueue for state access
    - Callback invoked on main thread for Flutter
 
 Usage from any thread:
 
 ```swift
 // Safe from background thread
 DispatchQueue.global().async {
     CloudSyncStore.shared.pushToCloud(data)
 }
 
 // Safe from main thread
 CloudSyncStore.shared.pushToCloud(data)
 ```
 
 Comparison with @MainActor:
 
 @MainActor:
 + More modern (Swift 5.5+)
 + Better with async/await
 + Type system enforced
 - Requires main thread context
 - Less flexible for background work
 
 Serial Queue:
 + Works from any thread
 + No async/await required
 + Compatible with older code
 + Better for background operations
 - More manual synchronization
 - Not type-system enforced
 */
