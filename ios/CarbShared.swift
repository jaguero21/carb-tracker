import AppIntents
import Foundation
#if !os(watchOS)
import WidgetKit
#endif

// MARK: - Shared UserDefaults reader/writer

struct CarbDataStore {
    static let appGroupID = "group.com.carpecarb.shared"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func totalCarbs() -> Double {
        defaults?.double(forKey: "totalCarbs") ?? 0.0
    }

    static func lastFoodName() -> String {
        defaults?.string(forKey: "lastFoodName") ?? ""
    }

    static func lastFoodCarbs() -> Double {
        defaults?.double(forKey: "lastFoodCarbs") ?? 0.0
    }

    static func dailyCarbGoal() -> Double? {
        let value = defaults?.double(forKey: "dailyCarbGoal") ?? 0.0
        return value > 0 ? value : nil
    }

    static func addFood(name: String, carbs: Double, details: String? = nil) {
        let newTotal = totalCarbs() + carbs
        defaults?.set(newTotal, forKey: "totalCarbs")
        defaults?.set(name, forKey: "lastFoodName")
        defaults?.set(carbs, forKey: "lastFoodCarbs")

        // Also update the Flutter SharedPreferences key so the app sees the new total
        defaults?.set(newTotal, forKey: "flutter.total_carbs")

        // Store Siri-logged items as JSON string so Flutter can read via HomeWidget
        var siriItems: [[String: Any]] = []
        if let existing = defaults?.string(forKey: "siriLoggedItems"),
           let data = existing.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            siriItems = parsed
        }
        var entry: [String: Any] = ["name": name, "carbs": carbs]
        if let details = details { entry["details"] = details }
        siriItems.append(entry)
        if let jsonData = try? JSONSerialization.data(withJSONObject: siriItems),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            defaults?.set(jsonString, forKey: "siriLoggedItems")
        }

        #if !os(watchOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

// MARK: - Firebase Cloud Function client

struct PerplexityClient {
    private static let cloudFunctionURL = "https://us-central1-carpecarb.cloudfunctions.net/getMultipleCarbCounts"

    static func lookupCarbs(for foodItem: String) async throws -> (name: String, carbs: Double, details: String?) {
        let url = URL(string: cloudFunctionURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "data": [
                "input": foodItem
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntentError.message("Invalid response from server.")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw IntentError.message("Rate limit exceeded. Try again shortly.")
            }
            throw IntentError.message("Server error (\(httpResponse.statusCode)).")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let items = result["items"] as? [[String: Any]],
              let first = items.first else {
            throw IntentError.message("Could not parse server response.")
        }

        let name = first["name"] as? String ?? "Unknown"
        let carbs: Double
        if let carbNum = first["carbs"] as? NSNumber {
            carbs = carbNum.doubleValue
        } else if let carbStr = first["carbs"] as? String, let parsed = Double(carbStr) {
            carbs = parsed
        } else {
            carbs = 0
        }
        let details = first["details"] as? String

        return (name: name, carbs: carbs, details: details)
    }
}

// MARK: - Error helper

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case message(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let msg):
            return "\(msg)"
        }
    }
}

// MARK: - Log Food Intent

struct LogFoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Food in CarpeCarb"
    static var description = IntentDescription("Look up carbs for a food item and add it to today's total.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Food Item", requestValueDialog: "What food would you like to log?")
    var foodItem: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try await PerplexityClient.lookupCarbs(for: foodItem)

        CarbDataStore.addFood(name: result.name, carbs: result.carbs, details: result.details)

        let formattedCarbs = String(format: "%.1f", result.carbs)
        let formattedTotal = String(format: "%.1f", CarbDataStore.totalCarbs())

        return .result(dialog: "\(result.name) has \(formattedCarbs) grams of carbs. Your total today is \(formattedTotal) grams.")
    }
}

// MARK: - Check Carbs Intent

struct CheckCarbsIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Today's Carbs"
    static var description = IntentDescription("Check how many carbs you've eaten today.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let total = CarbDataStore.totalCarbs()
        let lastFood = CarbDataStore.lastFoodName()
        let lastCarbs = CarbDataStore.lastFoodCarbs()
        let goal = CarbDataStore.dailyCarbGoal()

        let formattedTotal = String(format: "%.1f", total)

        if total == 0.0 {
            return .result(dialog: "You haven't tracked any carbs today. Open CarpeCarb to start logging.")
        }

        var message = "You've had \(formattedTotal) grams of carbs today."

        if let goal = goal {
            let formattedGoal = String(format: "%.0f", goal)
            if total >= goal {
                let over = String(format: "%.1f", total - goal)
                message += " You're \(over) grams over your \(formattedGoal) gram goal."
            } else {
                let remaining = String(format: "%.1f", goal - total)
                message += " You have \(remaining) grams remaining of your \(formattedGoal) gram goal."
            }
        }

        if !lastFood.isEmpty {
            let formattedLast = String(format: "%.1f", lastCarbs)
            message += " Your last entry was \(lastFood) at \(formattedLast) grams."
        }

        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
