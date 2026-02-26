import Foundation

public struct PerplexityClient {
    public static func lookupCarbs(for foodItem: String) async throws -> (name: String, carbs: Double, details: String?, citations: [String]) {
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
