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
  {
    secrets: [perplexityApiKey],
    timeoutSeconds: 60,
    // Keep one instance warm to avoid cold starts
    minInstances: 1,
  },
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

    console.log(`Looking up: "${sanitized}"`);

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
                    "Interpret the input carefully: words may refer to a brand/store name, a style/variety, or the actual food product. " +
                    "For example, 'heb fajita tortilla' means a fajita-style tortilla sold by the brand HEB — NOT a fajita, NOT a taco. " +
                    "Parse the EXACT product the user is describing before looking up nutrition data. " +
                    "Respond with ONLY a JSON array. " +
                    'Each element must have "name" (the full product name including brand if given), "carbs" (number of carb grams as a number, not a string), ' +
                    'and "details" (cite the specific source used e.g. product packaging, manufacturer website, USDA database). ' +
                    "IMPORTANT: Always use official nutrition data from the manufacturer, store brand, or restaurant website when available. " +
                    "For store-brand items (HEB, Kirkland, Great Value, etc.), look up the specific product from that brand. " +
                    "For restaurant items (McDonald's, Chick-fil-A, etc.), use the exact values from their published nutrition information. " +
                    "For generic foods, use USDA FoodData Central values. " +
                    "Never estimate or average — use the most authoritative source available. " +
                    "Include the serving size in the details. " +
                    'Example: [{"name":"HEB Fajita Tortilla","carbs":26,"details":"Per HEB product nutrition label, one fajita-size flour tortilla contains 26g carbs (1 tortilla serving)."}] ' +
                    "Return ONLY the JSON array, no other text.",
                },
                {
                  role: "user",
                  content: sanitized,
                },
              ],
              max_tokens: 600,
              temperature: 0.1,
            }),
          }
        );

        if (response.status === 401) {
          console.error("Perplexity API auth failed (401)");
          throw new HttpsError("internal", "API authentication failed");
        }
        if (response.status === 429) {
          console.error("Perplexity API rate limited (429)");
          throw new HttpsError(
            "resource-exhausted",
            "Rate limit exceeded. Try again later."
          );
        }
        if (response.status >= 500) {
          console.error(`Perplexity API server error (${response.status}), attempt ${attempt}/${maxAttempts}`);
          if (attempt < maxAttempts) {
            await new Promise((r) => setTimeout(r, attempt * 1000));
            continue;
          }
          throw new HttpsError("internal", "Server error. Try again later.");
        }
        if (!response.ok) {
          const errorBody = await response.text();
          console.error(`Perplexity API error (${response.status}): ${errorBody}`);
          throw new HttpsError(
            "internal",
            `API request failed (${response.status})`
          );
        }

        const result = await response.json();

        if (!result.choices || !result.choices[0]) {
          console.error("Invalid API response structure:", JSON.stringify(result).substring(0, 500));
          throw new HttpsError("internal", "Invalid API response");
        }

        const content = result.choices[0].message.content.trim();
        const citations = result.citations || [];

        console.log("Raw API response content:", content);

        // Parse JSON array from response (handle markdown code fences)
        const arrayMatch = content.match(/\[[\s\S]*\]/);
        if (!arrayMatch) {
          console.error("Could not find JSON array in response:", content);
          throw new HttpsError("internal", "Could not parse food items");
        }

        let items;
        try {
          items = JSON.parse(arrayMatch[0]);
        } catch (parseErr) {
          console.error("JSON parse error:", parseErr.message, "Content:", arrayMatch[0]);
          throw new HttpsError("internal", "Could not parse food items");
        }

        if (!Array.isArray(items) || items.length === 0) {
          console.error("Parsed result is not a non-empty array:", JSON.stringify(items));
          throw new HttpsError("internal", "No food items found in response");
        }

        const mapped = items.map((item) => {
          // Ensure carbs is a number — handle string values like "45" or "45g"
          let carbs = item.carbs;
          if (typeof carbs === "string") {
            const numMatch = carbs.match(/(\d+\.?\d*)/);
            carbs = numMatch ? parseFloat(numMatch[1]) : 0;
          }
          carbs = typeof carbs === "number" ? carbs : 0;

          return {
            name: String(item.name || "Unknown"),
            carbs: carbs,
            details: item.details ? String(item.details) : null,
          };
        });

        console.log(`Returning ${mapped.length} item(s):`, JSON.stringify(mapped));

        return {
          items: mapped,
          citations: citations,
        };
      } catch (error) {
        if (error instanceof HttpsError) throw error;

        console.error(`Attempt ${attempt}/${maxAttempts} failed:`, error.message);

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
