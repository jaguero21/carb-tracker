import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public struct CarbDataStore {
    public static let appGroupID = "group.com.jamesaguero.mycarbtracker"

    // UserDefaults key constants — must match StorageKeys in Dart
    public struct Keys {
        public static let totalCarbs = "totalCarbs"
        public static let lastFoodName = "lastFoodName"
        public static let lastFoodCarbs = "lastFoodCarbs"
        public static let dailyCarbGoal = "dailyCarbGoal"
        public static let siriLoggedItems = "siriLoggedItems"
        public static let flutterTotalCarbs = "flutter.total_carbs"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    public static func totalCarbs() -> Double {
        defaults?.double(forKey: Keys.totalCarbs) ?? 0.0
    }

    public static func lastFoodName() -> String {
        defaults?.string(forKey: Keys.lastFoodName) ?? ""
    }

    public static func lastFoodCarbs() -> Double {
        defaults?.double(forKey: Keys.lastFoodCarbs) ?? 0.0
    }

    public static func dailyCarbGoal() -> Double? {
        let value = defaults?.double(forKey: Keys.dailyCarbGoal) ?? 0.0
        return value > 0 ? value : nil
    }

    public static func addFood(name: String, carbs: Double, details: String? = nil, citations: [String] = []) {
        let newTotal = totalCarbs() + carbs
        defaults?.set(newTotal, forKey: Keys.totalCarbs)
        defaults?.set(name, forKey: Keys.lastFoodName)
        defaults?.set(carbs, forKey: Keys.lastFoodCarbs)

        // Also update the Flutter SharedPreferences key so the app sees the new total
        defaults?.set(newTotal, forKey: Keys.flutterTotalCarbs)

        // Store Siri-logged items as JSON string so Flutter can read via HomeWidget
        var siriItems: [[String: Any]] = []
        if let existing = defaults?.string(forKey: Keys.siriLoggedItems),
           let data = existing.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            siriItems = parsed
        }
        var item: [String: Any] = [
            "name": name,
            "carbs": carbs,
            "loggedAt": ISO8601DateFormatter().string(from: Date()),
        ]
        if let details = details {
            item["details"] = details
        }
        if !citations.isEmpty {
            item["citations"] = citations
        }
        siriItems.append(item)
        if let jsonData = try? JSONSerialization.data(withJSONObject: siriItems),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            defaults?.set(jsonString, forKey: Keys.siriLoggedItems)
        }

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
