const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const perplexityApiKey = defineSecret("PERPLEXITY_API_KEY");

/**
 * Cloud Function to look up carb counts for one or more food items.
 *
 * Mirrors the prompt and parsing logic from the Flutter PerplexityService
 * so the API key stays server-side.
 *
 * Usage from Flutter:
 *   FirebaseFunctions.instance.httpsCallable('getMultipleCarbCounts')
 *     .call({'input': 'Big Mac and fries'});
 */
exports.getMultipleCarbCounts = onCall(
  { secrets: [perplexityApiKey], timeoutSeconds: 60 },
  async (request) => {
    const { input } = request.data;

    // Validate input
    if (!input || typeof input !== "string") {
      throw new HttpsError("invalid-argument", "input is required");
    }
    const trimmed = input.trim();
    if (trimmed.length < 2 || trimmed.length > 100) {
      throw new HttpsError(
        "invalid-argument",
        "input must be 2-100 characters"
      );
    }

    // Sanitize (mirrors InputValidation.sanitizeForApi)
    const sanitized = trimmed
      .replace(/[\n\r\t]/g, " ")
      .replace(/\0/g, "")
      .replace(/\u2019/g, "'")
      .replace(/\s+/g, " ")
      .trim();

    const maxAttempts = 3;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        const response = await fetch(
          "https://api.perplexity.ai/chat/completions",
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${perplexityApiKey.value()}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              model: "sonar-pro",
              messages: [
                {
                  role: "system",
                  content:
                    "You are a precise nutrition assistant. The user will describe one or more food items. " +
                    "Identify each distinct food item and respond with ONLY a JSON array. " +
                    'Each element must have "name" (short descriptive name), "carbs" (number of carb grams), ' +
                    'and "details" (cite the specific source used e.g. restaurant website, USDA database, nutrition label). ' +
                    "IMPORTANT: Always use official nutrition data from the restaurant or manufacturer website when available. " +
                    "For branded/restaurant items (McDonald's, Chick-fil-A, etc.), use the exact values from their published nutrition information. " +
                    "For generic foods, use USDA FoodData Central values. " +
                    "Never estimate or average \u2014 use the most authoritative source available. " +
                    "Include the serving size in the details. " +
                    'Example: [{"name":"Big Mac","carbs":45,"details":"Per McDonald\'s official nutrition information, a Big Mac contains 45g of carbs (standard serving)."}] ' +
                    "Return ONLY the JSON array, no other text.",
                },
                {
                  role: "user",
                  content: sanitized,
                },
              ],
              max_tokens: 600,
              temperature: 0.0,
            }),
          }
        );

        if (response.status === 401) {
          throw new HttpsError("internal", "API authentication failed");
        }
        if (response.status === 429) {
          throw new HttpsError(
            "resource-exhausted",
            "Rate limit exceeded. Try again later."
          );
        }
        if (response.status >= 500) {
          if (attempt < maxAttempts) {
            await new Promise((r) => setTimeout(r, attempt * 1000));
            continue;
          }
          throw new HttpsError("internal", "Server error. Try again later.");
        }
        if (!response.ok) {
          throw new HttpsError(
            "internal",
            `API request failed (${response.status})`
          );
        }

        const result = await response.json();

        if (!result.choices || !result.choices[0]) {
          throw new HttpsError("internal", "Invalid API response");
        }

        const content = result.choices[0].message.content.trim();
        const citations = result.citations || [];

        // Parse JSON array from response (handle markdown code fences)
        const arrayMatch = content.match(/\[[\s\S]*\]/);
        if (!arrayMatch) {
          throw new HttpsError("internal", "Could not parse food items");
        }

        const items = JSON.parse(arrayMatch[0]);

        return {
          items: items.map((item) => ({
            name: item.name,
            carbs: item.carbs,
            details: item.details || null,
          })),
          citations: citations,
        };
      } catch (error) {
        if (error instanceof HttpsError) throw error;

        // Retry on transient errors
        if (attempt < maxAttempts) {
          await new Promise((r) => setTimeout(r, attempt * 1000));
          continue;
        }

        throw new HttpsError("internal", error.message);
      }
    }
  }
);
