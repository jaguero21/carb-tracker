import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../config/storage_keys.dart';
import '../models/food_item.dart';
import '../utils/input_validation.dart';
import '../utils/user_facing_exception.dart';

class PerplexityFirebaseService {
  // Rate limiting to prevent UI-level spamming
  static DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 1500);

  static const String _functionUrl =
      'https://us-central1-carpecarb.cloudfunctions.net/getMultipleCarbCounts';

  /// Looks up one or more food items via the Firebase Cloud Function.
  /// Uses direct HTTPS REST call to avoid Firebase Functions SDK AOT crash
  /// (swift_task_switch in HTTPSCallable.call on iOS 12.9.x SDK).
  Future<List<FoodItem>> getMultipleCarbCounts(String input) async {
    await _enforceRateLimit();

    final validationError = InputValidation.validateFoodInput(input);
    if (validationError != null) {
      throw UserFacingException(validationError);
    }

    // Get the current user's ID token for authentication
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw UserFacingException('Authentication error. Please restart the app.');
    }

    String idToken;
    try {
      idToken = await user.getIdToken() ?? '';
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to get ID token: $e');
      throw UserFacingException('Authentication error. Please restart the app.');
    }

    if (idToken.isEmpty) {
      throw UserFacingException('Authentication error. Please restart the app.');
    }

    // Keep the shared token fresh so Siri/Watch extensions can auth.
    HomeWidget.saveWidgetData<String>(StorageKeys.firebaseIdToken, idToken);

    final body = jsonEncode({'data': {'input': input}});

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 60);

      final request = await client.postUrl(Uri.parse(_functionUrl));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $idToken');
      request.write(body);

      final response = await request.close().timeout(const Duration(seconds: 60));
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (kDebugMode) debugPrint('Cloud Function HTTP ${response.statusCode}');

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw UserFacingException('Authentication error. Please restart the app.');
      }

      if (response.statusCode == 429) {
        throw UserFacingException('Rate limit exceeded. Please try again later.');
      }

      if (response.statusCode != 200) {
        if (kDebugMode) debugPrint('Cloud Function error body: $responseBody');
        // Parse Firebase error if present
        try {
          final errJson = jsonDecode(responseBody) as Map<String, dynamic>;
          final errMsg = (errJson['error'] as Map<String, dynamic>?)?['message']
              as String?;
          if (errMsg != null && errMsg.isNotEmpty) {
            throw UserFacingException(errMsg);
          }
        } catch (e) {
          if (e is UserFacingException) rethrow;
        }
        throw UserFacingException('Failed to get carb count. Please try again.');
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      // Firebase callable functions wrap response in a `result` key
      final result = (json['result'] ?? json['data']) as Map<String, dynamic>?;

      if (result == null || result['items'] == null) {
        if (kDebugMode) debugPrint('Unexpected response shape: $responseBody');
        throw UserFacingException('No results returned. Please try again.');
      }

      final items = result['items'] as List<dynamic>;
      final citations = result['citations'] != null
          ? List<String>.from(result['citations'] as List)
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
    } on UserFacingException {
      rethrow;
    } on SocketException {
      throw UserFacingException('Network error. Please check your connection.');
    } catch (e) {
      if (kDebugMode) debugPrint('PerplexityFirebaseService error: $e');
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
