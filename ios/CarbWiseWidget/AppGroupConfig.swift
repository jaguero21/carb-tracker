import Foundation

/// Shared configuration constants for CarpeCarb app and extensions.
/// Ensures consistency across main app, widgets, and other extensions.
public enum AppGroupConfig {
    
    // MARK: - App Group
    
    /// The App Group identifier shared across all targets.
    /// 
    /// **Important:** This MUST match:
    /// - Xcode → Signing & Capabilities → App Groups
    /// - Entitlements files for all targets
    /// - Apple Developer Portal → App Group identifier
    ///
    /// **Current Value:** Change this to match your actual App Group ID
    public static let identifier = "group.com.carpecarb.shared"
    
    // MARK: - Shared UserDefaults
    
    /// UserDefaults suite for shared data between app and extensions.
    ///
    /// Use this instead of `UserDefaults.standard` when you need to share data
    /// with widgets or other extensions.
    ///
    /// **Example:**
    /// ```swift
    /// AppGroupConfig.sharedDefaults?.set(42.5, forKey: "totalCarbs")
    /// let carbs = AppGroupConfig.sharedDefaults?.double(forKey: "totalCarbs")
    /// ```
    public static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }
    
    // MARK: - Shared Keys
    
    /// Keys used for storing data in the shared UserDefaults.
    /// Centralizing these prevents typos and makes refactoring easier.
    public enum Keys {
        // Widget Data
        public static let totalCarbs = "totalCarbs"
        public static let lastFoodName = "lastFoodName"
        public static let lastFoodCarbs = "lastFoodCarbs"
        public static let dailyCarbGoal = "dailyCarbGoal"
        public static let dailyResetHour = "dailyResetHour"
        public static let lastSaveDate = "lastSaveDate"
        
        // iCloud Sync Keys (match CloudSyncStore)
        public static let foodItems = "food_items"
        public static let savedFoods = "saved_foods"
    }
    
    // MARK: - Validation
    
    /// Validates that the App Group is properly configured and accessible.
    ///
    /// - Returns: `true` if the App Group is accessible, `false` otherwise.
    ///
    /// **Usage:**
    /// ```swift
    /// if !AppGroupConfig.isValid {
    ///     print("⚠️ App Group not configured correctly!")
    /// }
    /// ```
    public static var isValid: Bool {
        guard let defaults = sharedDefaults else {
            return false
        }
        
        // Try to write and read a test value
        let testKey = "__app_group_test_key__"
        let testValue = "test"
        
        defaults.set(testValue, forKey: testKey)
        let readValue = defaults.string(forKey: testKey)
        defaults.removeObject(forKey: testKey)
        
        return readValue == testValue
    }
    
    // MARK: - Debug Info
    
    /// Returns debug information about the App Group configuration.
    ///
    /// Useful for logging and troubleshooting.
    public static var debugInfo: [String: Any] {
        var info: [String: Any] = [
            "identifier": identifier,
            "isValid": isValid,
            "defaultsAccessible": sharedDefaults != nil
        ]
        
        if let defaults = sharedDefaults,
           let domain = defaults.persistentDomain(forName: identifier) {
            info["keysCount"] = domain.count
            info["keys"] = Array(domain.keys)
        }
        
        return info
    }
}

// MARK: - Convenience Extensions

public extension UserDefaults {
    /// Returns the shared UserDefaults suite for the CarpeCarb App Group.
    ///
    /// This is a convenience accessor for `AppGroupConfig.sharedDefaults`.
    ///
    /// **Example:**
    /// ```swift
    /// UserDefaults.appGroup?.set(100.0, forKey: "dailyCarbGoal")
    /// ```
    static var appGroup: UserDefaults? {
        AppGroupConfig.sharedDefaults
    }
}
