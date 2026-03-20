import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/food_item.dart';
import '../utils/input_validation.dart';
import '../utils/user_facing_exception.dart';

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
      throw UserFacingException(validationError);
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
        throw UserFacingException('No results returned. Please try again.');
      }

      final items = data['items'] as List<dynamic>;
      final citations = data['citations'] != null
          ? List<String>.from(data['citations'])
          : <String>[];

      if (items.isEmpty) {
        throw UserFacingException(
            'No food items found. Please try a different description.');
      }

      double? parseOptional(dynamic v) {
        if (v == null) return null;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString());
      }

      return items.map((item) {
        final carbsRaw = item['carbs'];
        final carbs = carbsRaw is num
            ? carbsRaw.toDouble()
            : double.tryParse(carbsRaw.toString()) ?? 0.0;

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
          throw UserFacingException('Invalid food item. Please try again.');
        case 'resource-exhausted':
          throw UserFacingException(
              'Rate limit exceeded. Please try again later.');
        case 'unauthenticated':
          throw UserFacingException(
              'Authentication error. Please restart the app.');
        case 'deadline-exceeded':
          throw UserFacingException('Request timed out. Please try again.');
        default:
          throw UserFacingException(
              'Failed to get carb count. Please try again.');
      }
    } on UserFacingException {
      rethrow;
    } catch (e) {
      debugPrint('PerplexityFirebaseService error: $e');
      throw UserFacingException('Network error. Please check your connection.');
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
