import AppIntents
import Foundation
import WidgetKit

// MARK: - Shared UserDefaults reader/writer

struct CarbDataStore {
    static let appGroupID = "group.com.jamesaguero.mycarbtracker"

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

    static func addFood(name: String, carbs: Double, details: String? = nil, citations: [String] = []) {
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
            defaults?.set(jsonString, forKey: "siriLoggedItems")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - .env file reader

struct EnvReader {
    static func apiKey() -> String? {
        guard let path = Bundle.main.path(forResource: ".env", ofType: nil) ??
                         Bundle.main.path(forResource: "env", ofType: nil) else {
            // Try flutter assets path
            if let assetsPath = Bundle.main.path(forResource: "flutter_assets/.env", ofType: nil) {
                return parseKey(from: assetsPath)
            }
            // Check in Frameworks/App.framework for release builds
            if let frameworkPath = Bundle.main.path(forResource: "Frameworks/App.framework/flutter_assets/.env", ofType: nil) {
                return parseKey(from: frameworkPath)
            }
            return nil
        }
        return parseKey(from: path)
    }

    private static func parseKey(from path: String) -> String? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("PERPLEXITY_API_KEY=") {
                return String(trimmed.dropFirst("PERPLEXITY_API_KEY=".count))
            }
        }
        return nil
    }
}

// MARK: - Perplexity API client

struct PerplexityClient {
    static func lookupCarbs(for foodItem: String) async throws -> (name: String, carbs: Double, details: String?, citations: [String]) {
        guard let apiKey = EnvReader.apiKey(), !apiKey.isEmpty else {
            throw IntentError.message("API key not configured.")
        }

        let url = URL(string: "https://api.perplexity.ai/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "sonar",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a precise nutrition assistant. The user will name a food item. "
                        + "Respond with ONLY a JSON object with \"name\" (short descriptive name), \"carbs\" (number of carb grams as a number), "
                        + "and \"details\" (cite the specific source used e.g. restaurant website, USDA database, nutrition label, and include the serving size). "
                        + "IMPORTANT: Always use official nutrition data from the restaurant or manufacturer website when available. "
                        + "For branded/restaurant items, use the exact values from their published nutrition information. "
                        + "For generic foods, use USDA FoodData Central values. "
                        + "Never estimate or average — use the most authoritative source available. "
                        + "Example: {\"name\":\"Big Mac\",\"carbs\":45,\"details\":\"Per McDonald's official nutrition information, a Big Mac contains 45g of carbs (standard serving).\"} "
                        + "Return ONLY the JSON object, no other text."
                ],
                [
                    "role": "user",
                    "content": foodItem
                ]
            ],
            "max_tokens": 300,
            "temperature": 0.0
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntentError.message("Invalid response from server.")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw IntentError.message("Invalid API key.")
            } else if httpResponse.statusCode == 429 {
                throw IntentError.message("Rate limit exceeded. Try again shortly.")
            }
            throw IntentError.message("Server error (\(httpResponse.statusCode)).")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw IntentError.message("Could not parse API response.")
        }

        // Extract top-level citations from Perplexity response
        let citations: [String]
        if let citationArray = json["citations"] as? [String] {
            citations = citationArray
        } else {
            citations = []
        }

        let parsed = try parseFood(from: content.trimmingCharacters(in: .whitespacesAndNewlines))
        return (name: parsed.name, carbs: parsed.carbs, details: parsed.details, citations: citations)
    }

    private static func parseFood(from content: String) throws -> (name: String, carbs: Double, details: String?) {
        // Extract JSON object from response (handle markdown code fences)
        var jsonStr = content
        if let match = jsonStr.range(of: #"\{[\s\S]*\}"#, options: .regularExpression) {
            jsonStr = String(jsonStr[match])
        }

        guard let data = jsonStr.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = obj["name"] as? String,
              let carbs = obj["carbs"] as? NSNumber else {
            throw IntentError.message("Could not parse food data.")
        }

        let details = obj["details"] as? String

        return (name: name, carbs: carbs.doubleValue, details: details)
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

        CarbDataStore.addFood(name: result.name, carbs: result.carbs, details: result.details, citations: result.citations)

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

// MARK: - Open App Intent

struct OpenCarpeCarbIntent: AppIntent {
    static var title: LocalizedStringResource = "Open CarpeCarb"
    static var description = IntentDescription("Open the CarpeCarb app.")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
