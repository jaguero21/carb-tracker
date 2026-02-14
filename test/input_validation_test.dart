import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Input Validation Tests', () {
    // Helper function to simulate validation logic
    String? validateFoodInput(String input) {
      final trimmed = input.trim();

      if (trimmed.isEmpty) {
        return 'Please enter a food item';
      }

      if (trimmed.length < 2) {
        return 'Food name must be at least 2 characters';
      }

      if (trimmed.length > 100) {
        return 'Food name is too long (max 100 characters)';
      }

      final validPattern = RegExp(r"^[a-zA-Z0-9\s\-,.()'/&%]+$");
      if (!validPattern.hasMatch(trimmed)) {
        return 'Please use only letters, numbers, and common punctuation';
      }

      if (RegExp(r'^[\d\s\-,.()]+$').hasMatch(trimmed)) {
        return 'Please enter a valid food name';
      }

      return null;
    }

    test('accepts valid food names', () {
      expect(validateFoodInput('Apple'), null);
      expect(validateFoodInput('Banana Bread'), null);
      expect(validateFoodInput('Chicken & Rice'), null);
      expect(validateFoodInput("McDonald's Fries"), null);
      expect(validateFoodInput('Brown Rice (cooked)'), null);
      expect(validateFoodInput('Coca-Cola'), null);
      expect(validateFoodInput('Soup, Tomato'), null);
      expect(validateFoodInput('Mac & Cheese'), null);
    });

    test('rejects empty input', () {
      expect(validateFoodInput(''), 'Please enter a food item');
      expect(validateFoodInput('   '), 'Please enter a food item');
    });

    test('rejects too short input', () {
      expect(validateFoodInput('A'), 'Food name must be at least 2 characters');
    });

    test('rejects too long input', () {
      final longString = 'A' * 101;
      expect(validateFoodInput(longString),
        'Food name is too long (max 100 characters)');
    });

    test('rejects invalid special characters', () {
      expect(validateFoodInput('Apple@Home'),
        'Please use only letters, numbers, and common punctuation');
      expect(validateFoodInput('Food#1'),
        'Please use only letters, numbers, and common punctuation');
      expect(validateFoodInput('Test\$Food'),
        'Please use only letters, numbers, and common punctuation');
    });

    test('rejects only numbers', () {
      expect(validateFoodInput('123'), 'Please enter a valid food name');
      expect(validateFoodInput('12.5'), 'Please enter a valid food name');
    });

    test('trims whitespace correctly', () {
      expect(validateFoodInput('  Apple  '), null);
      expect(validateFoodInput('\nBanana\n'), null);
    });

    test('accepts numbers in food names', () {
      expect(validateFoodInput('Vitamin B12'), null);
      expect(validateFoodInput('7-Eleven Pizza'), null);
      expect(validateFoodInput('2% Milk'), null);
    });

    test('accepts common punctuation', () {
      expect(validateFoodInput('Mrs. Dash Seasoning'), null);
      expect(validateFoodInput('Salt & Pepper'), null);
      expect(validateFoodInput('Bread, Wheat'), null);
      expect(validateFoodInput('Pasta (whole wheat)'), null);
    });
  });
}
