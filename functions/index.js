const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const perplexityApiKey = defineSecret("PERPLEXITY_API_KEY");
const appStoreSharedSecret = defineSecret("APP_STORE_SHARED_SECRET");

const APPLE_PRODUCTION_VERIFY_URL = "https://buy.itunes.apple.com/verifyReceipt";
const APPLE_SANDBOX_VERIFY_URL = "https://sandbox.itunes.apple.com/verifyReceipt";
const PREMIUM_PRODUCT_IDS = new Set([
  "carpecarb_premium_monthlysub",
  "carpecarb_premium_yearly",
]);

function parseMillis(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function getReceiptTransactions(body) {
  const latest = Array.isArray(body.latest_receipt_info) ? body.latest_receipt_info : [];
  const receiptInApp = Array.isArray(body.receipt?.in_app) ? body.receipt.in_app : [];
  return [...latest, ...receiptInApp];
}

function findLatestActiveSubscription(body) {
  const now = Date.now();
  const transactions = getReceiptTransactions(body);

  let latestActive = null;

  for (const transaction of transactions) {
    const productId = typeof transaction.product_id === "string"
      ? transaction.product_id
      : null;

    if (!productId || !PREMIUM_PRODUCT_IDS.has(productId)) {
      continue;
    }

    const expiresDateMs = parseMillis(transaction.expires_date_ms);
    if (expiresDateMs == null || expiresDateMs <= now) {
      continue;
    }

    if (!latestActive || expiresDateMs > latestActive.expiresDateMs) {
      latestActive = {
        productId,
        expiresDateMs,
        transactionId: transaction.transaction_id ?? null,
        originalTransactionId: transaction.original_transaction_id ?? null,
      };
    }
  }

  return latestActive;
}

async function postReceiptVerification(url, receiptData, sharedSecret) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      "receipt-data": receiptData,
      password: sharedSecret,
      "exclude-old-transactions": true,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    console.error(`Apple receipt verification HTTP ${response.status}: ${body}`);
    throw new HttpsError("internal", "Apple receipt verification request failed.");
  }

  return response.json();
}

async function verifyReceiptWithApple(receiptData, sharedSecret, preferSandbox = false) {
  const firstUrl = preferSandbox
    ? APPLE_SANDBOX_VERIFY_URL
    : APPLE_PRODUCTION_VERIFY_URL;
  const firstResponse = await postReceiptVerification(firstUrl, receiptData, sharedSecret);

  if (firstResponse.status === 21007 && !preferSandbox) {
    return postReceiptVerification(APPLE_SANDBOX_VERIFY_URL, receiptData, sharedSecret);
  }

  if (firstResponse.status === 21008 && preferSandbox) {
    return postReceiptVerification(APPLE_PRODUCTION_VERIFY_URL, receiptData, sharedSecret);
  }

  return firstResponse;
}

exports.validateAppStoreReceipt = onCall(
  {
    secrets: [appStoreSharedSecret],
    timeoutSeconds: 30,
  },
  async (request) => {
    const { receiptData, expectedProductId } = request.data || {};

    if (!receiptData || typeof receiptData !== "string") {
      throw new HttpsError("invalid-argument", "receiptData is required.");
    }

    if (
      expectedProductId != null &&
      (typeof expectedProductId !== "string" || !PREMIUM_PRODUCT_IDS.has(expectedProductId))
    ) {
      throw new HttpsError("invalid-argument", "expectedProductId is not recognized.");
    }

    const sharedSecret = appStoreSharedSecret.value();
    if (!sharedSecret) {
      console.error("APP_STORE_SHARED_SECRET is not configured.");
      throw new HttpsError("internal", "Receipt verification is not configured.");
    }

    const verification = await verifyReceiptWithApple(receiptData, sharedSecret);

    if (verification.status === 21004) {
      console.error("App Store shared secret mismatch.");
      throw new HttpsError("internal", "Receipt verification is misconfigured.");
    }

    if (![0, 21006].includes(verification.status)) {
      console.error("App Store rejected receipt:", verification.status, verification.environment);
      throw new HttpsError("failed-precondition", "App Store could not validate this receipt.");
    }

    const activeSubscription = findLatestActiveSubscription(verification);
    if (!activeSubscription) {
      return {
        isValid: false,
        reason: "no-active-subscription",
        environment: verification.environment ?? null,
        bundleId: verification.receipt?.bundle_id ?? null,
      };
    }

    if (expectedProductId && activeSubscription.productId !== expectedProductId) {
      return {
        isValid: false,
        reason: "product-mismatch",
        productId: activeSubscription.productId,
        expiresDateMs: activeSubscription.expiresDateMs,
        environment: verification.environment ?? null,
        bundleId: verification.receipt?.bundle_id ?? null,
      };
    }

    return {
      isValid: true,
      productId: activeSubscription.productId,
      transactionId: activeSubscription.transactionId,
      originalTransactionId: activeSubscription.originalTransactionId,
      expiresDateMs: activeSubscription.expiresDateMs,
      environment: verification.environment ?? null,
      bundleId: verification.receipt?.bundle_id ?? null,
    };
  }
);

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
                    "IMPORTANT: Return exactly ONE result per distinct food item the user mentions. " +
                    "If the user says 'tortilla', return only the single best match — do NOT return multiple varieties or sizes. " +
                    "Only return multiple items if the user explicitly lists multiple foods (e.g. 'burger and fries' = 2 items). " +
                    "Respond with ONLY a valid JSON array — no markdown, no code fences, no extra text. " +
                    'Each element must have "name" (string, the full product name including brand if given), "carbs" (number, grams of carbohydrates), ' +
                    '"protein" (number, grams of protein), "fat" (number, grams of total fat), "fiber" (number, grams of dietary fiber), ' +
                    '"calories" (number, kcal), and "details" (string, cite the specific source and serving size). ' +
                    "All numeric fields must be plain numbers — no units, no strings. " +
                    "Priority for data sources: " +
                    "1. Official manufacturer/restaurant/store-brand nutrition info (product packaging, website). " +
                    "2. USDA FoodData Central. " +
                    "3. Reliable nutrition databases (Nutritionix, CalorieKing, MyFitnessPal verified entries). " +
                    "If the exact brand product cannot be found, use the closest matching generic version and note this in details. " +
                    "Always include the serving size in details. " +
                    "You MUST always return a valid JSON array with at least one item — never refuse or return empty results. " +
                    'Example: [{"name":"HEB Fajita Tortilla","carbs":26,"protein":4,"fat":3,"fiber":1,"calories":150,"details":"Per HEB product nutrition label, one fajita-size flour tortilla (1 tortilla, 45g serving)."}]',
                },
                {
                  role: "user",
                  content: sanitized,
                },
              ],
              max_tokens: 1024,
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
          if (attempt < maxAttempts) {
            await new Promise((r) => setTimeout(r, attempt * 1000));
            continue;
          }
          throw new HttpsError("internal", "Invalid API response");
        }

        let content = result.choices[0].message.content.trim();
        const citations = result.citations || [];

        console.log("Raw API response content:", content);

        // Strip markdown code fences if present
        content = content.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "").trim();

        // Parse JSON array from response
        const arrayMatch = content.match(/\[[\s\S]*\]/);
        if (!arrayMatch) {
          console.error(`Could not find JSON array (attempt ${attempt}/${maxAttempts}):`, content);
          if (attempt < maxAttempts) {
            await new Promise((r) => setTimeout(r, attempt * 1000));
            continue;
          }
          throw new HttpsError("internal", "Could not parse food items");
        }

        let items;
        try {
          items = JSON.parse(arrayMatch[0]);
        } catch (parseErr) {
          console.error(`JSON parse error (attempt ${attempt}/${maxAttempts}):`, parseErr.message, "Content:", arrayMatch[0]);
          if (attempt < maxAttempts) {
            await new Promise((r) => setTimeout(r, attempt * 1000));
            continue;
          }
          throw new HttpsError("internal", "Could not parse food items");
        }

        if (!Array.isArray(items) || items.length === 0) {
          console.error(`Empty result array (attempt ${attempt}/${maxAttempts}):`, JSON.stringify(items));
          if (attempt < maxAttempts) {
            await new Promise((r) => setTimeout(r, attempt * 1000));
            continue;
          }
          throw new HttpsError("internal", "No food items found in response");
        }

        const mapped = items.map((item) => {
          const parseNum = (val) => {
            if (typeof val === "string") {
              const m = val.match(/(\d+\.?\d*)/);
              val = m ? parseFloat(m[1]) : null;
            }
            return typeof val === "number" && !isNaN(val) ? val : null;
          };

          const carbs = parseNum(item.carbs) ?? 0;

          return {
            name: String(item.name || "Unknown"),
            carbs: carbs,
            protein: parseNum(item.protein),
            fat: parseNum(item.fat),
            fiber: parseNum(item.fiber),
            calories: parseNum(item.calories),
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
