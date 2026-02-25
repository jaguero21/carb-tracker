import AppIntents
import Foundation

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
    }
}

// MARK: - .env file reader

struct EnvReader {
    static func apiKey() -> String? {
        guard let path = Bundle.main.path(forResource: ".env", ofType: nil) else {
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
    static func lookupCarbs(for foodItem: String) async throws -> (name: String, carbs: Double, details: String?) {
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
                        + "and \"details\" (one sentence citing the source and serving size, e.g. 'Per USDA FoodData Central, 1 medium banana (118g)'). "
                        + "Use official nutrition data from the restaurant or manufacturer website when available. "
                        + "For generic foods, use USDA FoodData Central values. "
                        + "Example: {\"name\":\"Banana\",\"carbs\":27,\"details\":\"Per USDA FoodData Central, 1 medium banana (118g).\"} "
                        + "Return ONLY the JSON object, no other text."
                ],
                [
                    "role": "user",
                    "content": foodItem
                ]
            ],
            "max_tokens": 250,
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

        return try parseFood(from: content.trimmingCharacters(in: .whitespacesAndNewlines))
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
