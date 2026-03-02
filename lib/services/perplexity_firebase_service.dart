import 'package:cloud_functions/cloud_functions.dart';
import '../models/food_item.dart';
import '../utils/input_validation.dart';

class PerplexityFirebaseService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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
      final callable = _functions.httpsCallable(
        'getMultipleCarbCounts',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );

      final result = await callable.call<Map<String, dynamic>>(
        {'input': input},
      );

      final data = result.data;
      final items = data['items'] as List<dynamic>;
      final citations = data['citations'] != null
          ? List<String>.from(data['citations'])
          : <String>[];

      return items.map((item) {
        return FoodItem(
          name: item['name'] as String,
          carbs: (item['carbs'] as num).toDouble(),
          details: item['details'] as String?,
          citations: citations,
        );
      }).toList();
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'invalid-argument':
          throw Exception('Invalid food item. Please try again.');
        case 'resource-exhausted':
          throw Exception('API rate limit exceeded. Please try again later.');
        case 'unauthenticated':
          throw Exception('Authentication error. Please restart the app.');
        default:
          throw Exception('Failed to get carb count: ${e.message}');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('Network error. Please check your connection.');
    }
  }

  /// Enforces rate limiting between API requests
  Future<void> _enforceRateLimit() async {
    if (_lastRequestTime != null) {
      final timeSinceLastRequest =
          DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        final waitTime = _minRequestInterval - timeSinceLastRequest;
        await Future.delayed(waitTime);
      }
    }
    _lastRequestTime = DateTime.now();
  }
}
