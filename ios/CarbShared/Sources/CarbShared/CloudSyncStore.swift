import Foundation

/// Syncs app data across devices using NSUbiquitousKeyValueStore (iCloud key-value store).
/// Placed in CarbShared so all targets (app, widget, watch, Siri) can access it.
///
/// Data flows entirely through the MethodChannel: Flutter serializes data on push
/// and writes it back to SharedPreferences on pull. This avoids UserDefaults domain
/// mismatches between the Flutter SharedPreferences store and the App Group store.
public final class CloudSyncStore {
    public static let shared = CloudSyncStore()

    private let kvStore = NSUbiquitousKeyValueStore.default

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

    private var onChange: (([String: Any]) -> Void)?
    private var observing = false

    private init() {}

    // MARK: - Availability

    public var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Push (Flutter → iCloud)

    /// Writes the data dict received from Flutter directly into iCloud KV store.
    /// Flutter is responsible for providing all syncable keys.
    public func pushToCloud(_ data: [String: Any]) {
        guard isAvailable else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())

        for (key, value) in data {
            kvStore.set(value, forKey: key)
        }
        kvStore.set(timestamp, forKey: Key.lastModified)
        kvStore.synchronize()
    }

    // MARK: - Pull (iCloud → Flutter)

    /// Reads all data from iCloud KV store and returns it so Flutter can write
    /// it to SharedPreferences. Returns nil if iCloud is unavailable or empty.
    @discardableResult
    public func pullFromCloud() -> [String: Any]? {
        guard isAvailable else { return nil }

        kvStore.synchronize()

        guard let timestamp = kvStore.string(forKey: Key.lastModified),
              !timestamp.isEmpty else { return nil }

        var pulled: [String: Any] = [Key.lastModified: timestamp]

        for key in Self.dataKeys {
            if let value = kvStore.object(forKey: key) {
                pulled[key] = value
            }
        }

        return pulled
    }

    // MARK: - Observe remote changes

    /// Start listening for data pushed from other devices.
    public func startObserving(onChange: @escaping ([String: Any]) -> Void) {
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
        if let pulled = pullFromCloud() {
            onChange?(pulled)
        }
    }
}
