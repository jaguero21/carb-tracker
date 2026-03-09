import Foundation

/// Syncs app data across devices using NSUbiquitousKeyValueStore (iCloud key-value store).
/// Placed in CarbShared so all targets (app, widget, watch, Siri) can access it.
public final class CloudSyncStore {
    public static let shared = CloudSyncStore()

    private let kvStore = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults(suiteName: CarbDataStore.appGroupID)

    /// Keys synced to iCloud — must match StorageKeys in Dart
    private enum Key {
        static let foodItems = "food_items"
        static let savedFoods = "saved_foods"
        static let dailyCarbGoal = "daily_carb_goal"
        static let dailyResetHour = "daily_reset_hour"
        static let lastSaveDate = "last_save_date"
        static let lastModified = "cloud_last_modified"
    }

    /// All syncable keys (excluding the timestamp itself)
    private static let syncKeys = [
        Key.foodItems, Key.savedFoods, Key.dailyCarbGoal,
        Key.dailyResetHour, Key.lastSaveDate,
    ]

    private var onChange: (() -> Void)?
    private var observing = false

    private init() {}

    // MARK: - Availability

    public var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Push (local → cloud)

    /// Reads from App Group UserDefaults and writes to iCloud KVStore.
    public func pushToCloud() {
        guard isAvailable, let defaults = defaults else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())

        for key in Self.syncKeys {
            if let value = defaults.object(forKey: key) {
                kvStore.set(value, forKey: key)
            } else {
                // Propagate local deletions to cloud so removed items don't
                // reappear on other devices during the next pull.
                kvStore.removeObject(forKey: key)
            }
        }
        kvStore.set(timestamp, forKey: Key.lastModified)
        kvStore.synchronize()
    }

    // MARK: - Pull (cloud → local)

    /// Reads from iCloud KVStore and writes to App Group UserDefaults if cloud is newer.
    /// Returns a dictionary of the pulled data, or nil if local was already up to date.
    @discardableResult
    public func pullFromCloud() -> [String: Any]? {
        guard isAvailable, let defaults = defaults else { return nil }

        kvStore.synchronize()

        let cloudTimestamp = kvStore.string(forKey: Key.lastModified) ?? ""
        let localTimestamp = defaults.string(forKey: Key.lastModified) ?? ""

        // Only overwrite local if cloud has newer data
        guard !cloudTimestamp.isEmpty, cloudTimestamp > localTimestamp else { return nil }

        var pulled: [String: Any] = [:]

        for key in Self.syncKeys {
            if let value = kvStore.object(forKey: key) {
                defaults.set(value, forKey: key)
                pulled[key] = value
            }
        }
        defaults.set(cloudTimestamp, forKey: Key.lastModified)
        pulled[Key.lastModified] = cloudTimestamp

        return pulled
    }

    // MARK: - Observe remote changes

    /// Start listening for changes pushed from other devices.
    public func startObserving(onChange: @escaping () -> Void) {
        self.onChange = onChange
        guard !observing else { return }
        observing = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )
        kvStore.synchronize()
    }

    public func stopObserving() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )
        observing = false
        onChange = nil
    }

    @objc private func kvStoreDidChange(_ notification: Notification) {
        // Pull the new data into UserDefaults
        let didUpdate = pullFromCloud() != nil
        if didUpdate {
            onChange?()
        }
    }
}
