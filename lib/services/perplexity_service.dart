import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/input_validation.dart';

class PerplexityService {
  // Load API key from environment variables instead of hardcoding
  static String get _apiKey => dotenv.env['PERPLEXITY_API_KEY'] ?? '';
  static const String _apiUrl = 'https://api.perplexity.ai/chat/completions';

  // Rate limiting to prevent API abuse
  static DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 1500);

  Future<double> getCarbCount(String foodItem) async {
    // Enforce rate limiting
    await _enforceRateLimit();

    // SECURITY: Sanitize input before sending to API (extra defense layer)
    final sanitizedInput = InputValidation.sanitizeForApi(foodItem);

    try {
      // Add timeout to prevent hanging requests
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'sonar',
              'messages': [
                {
                  'role': 'system',
                  'content': 'You are a nutrition assistant. When given a food item, '
                      'respond with ONLY the number of carbohydrates in grams for a '
                      'standard serving. Return just the numeric value, nothing else. '
                      'If the food item is ambiguous, use a typical serving size.',
                },
                {
                  'role': 'user',
                  'content': 'How many grams of carbohydrates are in: $sanitizedInput',
                },
              ],
              'max_tokens': 50,
              'temperature': 0.2,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timed out. Please check your internet connection and try again.');
            },
          );

      if (response.statusCode == 200) {
        // Handle malformed JSON responses
        try {
          final data = jsonDecode(response.body);

          // Validate response structure
          if (data == null || data['choices'] == null || data['choices'].isEmpty) {
            throw Exception('Invalid response format from API');
          }

          final content = data['choices'][0]['message']['content'] as String;

          // Extract the numeric value from the response
          final numericValue = _extractNumber(content);

          if (numericValue != null) {
            return numericValue;
          } else {
            throw Exception('Could not parse carb count from response: "$content"');
          }
        } on FormatException {
          throw Exception('Received malformed response from API');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Invalid API key. Please check your configuration.');
      } else if (response.statusCode == 429) {
        throw Exception('API rate limit exceeded. Please try again later.');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error. Please try again later.');
      } else {
        throw Exception('API request failed (${response.statusCode}): ${response.reasonPhrase}');
      }
    } on http.ClientException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on FormatException {
      throw Exception('Invalid response format received.');
    } catch (e) {
      // Re-throw if it's already our custom exception
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      // Otherwise wrap in a generic error
      throw Exception('Failed to get carb count: ${e.toString()}');
    }
  }

  double? _extractNumber(String text) {
    final lowerText = text.toLowerCase().trim();

    // Handle text-based zero values
    if (lowerText.contains('zero') ||
        lowerText.contains('no carbs') ||
        lowerText.contains('none')) {
      return 0.0;
    }

    // Strategy 1: Check for range format (e.g., "20-25" or "20 to 25")
    // Take the first (lower) value for conservative estimate
    final rangeMatch = RegExp(r'(\d+\.?\d*)\s*(?:-|to)\s*(\d+\.?\d*)').firstMatch(text);
    if (rangeMatch != null) {
      return double.tryParse(rangeMatch.group(1)!);
    }

    // Strategy 2: Find the first standalone number in the text
    // This handles most common cases: "25", "25.5g", "approximately 25 grams"
    final numberMatch = RegExp(r'(\d+\.?\d*)').firstMatch(text);
    if (numberMatch != null) {
      return double.tryParse(numberMatch.group(1)!);
    }

    // Strategy 3: Fallback - try removing all non-numeric chars except dots
    // Only if previous strategies found nothing
    final cleaned = text.replaceAll(RegExp(r'[^\d.]'), '');
    if (cleaned.isNotEmpty && !cleaned.contains('..')) {
      return double.tryParse(cleaned);
    }

    return null;
  }

  /// Enforces rate limiting between API requests
  Future<void> _enforceRateLimit() async {
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        final waitTime = _minRequestInterval - timeSinceLastRequest;
        await Future.delayed(waitTime);
      }
    }
    _lastRequestTime = DateTime.now();
  }
}
