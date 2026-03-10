import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/food_item.dart';
import '../utils/input_validation.dart';

class PerplexityFirebaseService {
  FirebaseFunctions? _functions;

  FirebaseFunctions get _firebaseFunctions =>
      _functions ??= FirebaseFunctions.instance;

  // Rate limiting to prevent UI-level spamming
  static DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 1500);

  /// Looks up one or more food items via the Firebase Cloud Function.
  /// Returns a list of FoodItems with individual carb counts and citations.
  Future<List<FoodItem>> getMultipleCarbCounts(String input) async {
    await _enforceRateLimit();

    final validationError = InputValidation.validateFoodInput(input);
    if (validationError != null) {
      throw Exception(validationError);
    }

    try {
      final callable = _firebaseFunctions.httpsCallable(
        'getMultipleCarbCounts',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      final result = await callable.call<Map<String, dynamic>>(
        {'input': input},
      );

      final data = result.data;

      if (data['items'] == null) {
        debugPrint('Firebase response missing items: $data');
        throw Exception('No results returned. Please try again.');
      }

      final items = data['items'] as List<dynamic>;
      final citations = data['citations'] != null
          ? List<String>.from(data['citations'])
          : <String>[];

      if (items.isEmpty) {
        throw Exception(
            'No food items found. Please try a different description.');
      }

      return items.map((item) {
        final carbsRaw = item['carbs'];
        final carbs = carbsRaw is num
            ? carbsRaw.toDouble()
            : double.tryParse(carbsRaw.toString()) ?? 0.0;

        double? parseOptional(dynamic v) {
          if (v == null) return null;
          if (v is num) return v.toDouble();
          return double.tryParse(v.toString());
        }

        return FoodItem(
          name: (item['name'] as String?) ?? 'Unknown',
          carbs: carbs,
          protein: parseOptional(item['protein']),
          fat: parseOptional(item['fat']),
          fiber: parseOptional(item['fiber']),
          calories: parseOptional(item['calories']),
          details: item['details'] as String?,
          citations: citations,
        );
      }).toList();
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
          'FirebaseFunctionsException: code=${e.code} message=${e.message}');
      switch (e.code) {
        case 'invalid-argument':
          throw Exception('Invalid food item. Please try again.');
        case 'resource-exhausted':
          throw Exception('API rate limit exceeded. Please try again later.');
        case 'unauthenticated':
          throw Exception('Authentication error. Please restart the app.');
        case 'deadline-exceeded':
          throw Exception('Request timed out. Please try again.');
        default:
          throw Exception('Failed to get carb count. Please try again.');
      }
    } catch (e) {
      debugPrint('PerplexityFirebaseService error: $e');
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('Network error. Please check your connection.');
    }
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
