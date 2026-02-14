/// Example: How to integrate Firebase Functions with your Flutter app
///
/// This replaces the current PerplexityService with calls to Firebase Functions

import 'package:cloud_functions/cloud_functions.dart';

class PerplexityServiceFirebase {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Get carb count using Firebase Function (more secure than direct API call)
  Future<double> getCarbCount(String foodItem) async {
    try {
      // Call the Firebase Function
      final callable = _functions.httpsCallable('getCarbCount');
      final result = await callable.call({
        'foodItem': foodItem,
      });

      // Extract carb count from response
      final data = result.data as Map<String, dynamic>;
      final carbs = (data['carbs'] as num).toDouble();

      return carbs;
    } on FirebaseFunctionsException catch (e) {
      // Handle specific Firebase errors
      switch (e.code) {
        case 'unauthenticated':
          throw Exception('Please sign in to use this feature');
        case 'invalid-argument':
          throw Exception('Invalid food item');
        case 'resource-exhausted':
          throw Exception('API rate limit exceeded. Please try again later.');
        default:
          throw Exception('Failed to get carb count: ${e.message}');
      }
    } catch (e) {
      throw Exception('Network error. Please check your connection.');
    }
  }
}

/// Setup Instructions:
///
/// 1. Add Firebase to your Flutter app:
///    flutter pub add firebase_core cloud_functions
///
/// 2. Configure Firebase (iOS and Android) following:
///    https://firebase.google.com/docs/flutter/setup
///
/// 3. Initialize Firebase in main.dart:
///    ```dart
///    import 'package:firebase_core/firebase_core.dart';
///
///    Future<void> main() async {
///      WidgetsFlutterBinding.ensureInitialized();
///      await Firebase.initializeApp();
///      runApp(MyApp());
///    }
///    ```
///
/// 4. Replace PerplexityService with PerplexityServiceFirebase
///
/// 5. Deploy Firebase Functions (see README.md in this folder)
