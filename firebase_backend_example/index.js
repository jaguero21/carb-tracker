const functions = require('firebase-functions');
const fetch = require('node-fetch');

/**
 * Cloud Function to get carb count from Perplexity API
 *
 * This keeps your API key secure on the server
 *
 * Usage from Flutter:
 *   FirebaseFunctions.instance.httpsCallable('getCarbCount')
 *     .call({'foodItem': 'apple'});
 */
exports.getCarbCount = functions.https.onCall(async (data, context) => {
  // Optional: Require authentication
  // if (!context.auth) {
  //   throw new functions.https.HttpsError(
  //     'unauthenticated',
  //     'User must be authenticated to use this function'
  //   );
  // }

  const { foodItem } = data;

  // Validate input
  if (!foodItem || typeof foodItem !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'foodItem is required');
  }

  if (foodItem.length < 2 || foodItem.length > 100) {
    throw new functions.https.HttpsError('invalid-argument', 'foodItem must be 2-100 characters');
  }

  try {
    // Get API key from Firebase config (set with: firebase functions:config:set perplexity.key="your-key")
    const apiKey = functions.config().perplexity.key;

    if (!apiKey) {
      throw new Error('API key not configured');
    }

    // Call Perplexity API
    const response = await fetch('https://api.perplexity.ai/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'sonar',
        messages: [
          {
            role: 'system',
            content: 'You are a nutrition assistant. When given a food item, respond with ONLY the number of carbohydrates in grams for a standard serving. Return just the numeric value, nothing else. If the food item is ambiguous, use a typical serving size.'
          },
          {
            role: 'user',
            content: `How many grams of carbohydrates are in: ${foodItem}`
          }
        ],
        max_tokens: 50,
        temperature: 0.2
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Perplexity API error:', response.status, errorText);

      if (response.status === 401) {
        throw new functions.https.HttpsError('internal', 'API authentication failed');
      }
      if (response.status === 429) {
        throw new functions.https.HttpsError('resource-exhausted', 'API rate limit exceeded');
      }

      throw new functions.https.HttpsError('internal', 'API request failed');
    }

    const result = await response.json();

    // Extract carb count from response
    if (!result.choices || !result.choices[0]) {
      throw new functions.https.HttpsError('internal', 'Invalid API response');
    }

    const content = result.choices[0].message.content;

    // Extract number from response
    const numMatch = content.match(/(\d+\.?\d*)/);
    const carbs = numMatch ? parseFloat(numMatch[1]) : null;

    if (carbs === null) {
      throw new functions.https.HttpsError('internal', 'Could not parse carb count');
    }

    // Return the carb count
    return {
      foodItem,
      carbs,
      rawResponse: content
    };

  } catch (error) {
    console.error('Error in getCarbCount:', error);

    // Re-throw HttpsErrors
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    // Wrap other errors
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Optional: HTTP endpoint version (for testing or non-Firebase apps)
 *
 * Usage:
 *   POST https://your-project.cloudfunctions.net/getCarbCountHttp
 *   Body: {"foodItem": "apple"}
 */
exports.getCarbCountHttp = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');

  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  try {
    const { foodItem } = req.body;

    // Call the main function logic
    const result = await exports.getCarbCount.run({ foodItem }, { auth: null });

    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
