import 'package:flutter_test/flutter_test.dart';
import '../food_item.dart';

void main() {
  group('FoodItem', () {
    test('constructor sets name and carbs', () {
      final item = FoodItem(name: 'Apple', carbs: 25.0);
      expect(item.name, 'Apple');
      expect(item.carbs, 25.0);
    });

    group('toJson', () {
      test('serializes correctly', () {
        final item = FoodItem(name: 'Banana', carbs: 27.5);
        final json = item.toJson();
        expect(json, {'name': 'Banana', 'carbs': 27.5});
      });

      test('handles zero carbs', () {
        final item = FoodItem(name: 'Water', carbs: 0.0);
        final json = item.toJson();
        expect(json, {'name': 'Water', 'carbs': 0.0});
      });
    });

    group('fromJson', () {
      test('deserializes correctly', () {
        final json = {'name': 'Rice', 'carbs': 45.0};
        final item = FoodItem.fromJson(json);
        expect(item.name, 'Rice');
        expect(item.carbs, 45.0);
      });

      test('handles int carbs value', () {
        final json = {'name': 'Bread', 'carbs': 30};
        final item = FoodItem.fromJson(json);
        expect(item.carbs, 30.0);
        expect(item.carbs, isA<double>());
      });

      test('handles zero carbs', () {
        final json = {'name': 'Water', 'carbs': 0};
        final item = FoodItem.fromJson(json);
        expect(item.carbs, 0.0);
      });
    });

    group('roundtrip', () {
      test('toJson -> fromJson preserves data', () {
        final original = FoodItem(name: 'Pasta', carbs: 43.2);
        final restored = FoodItem.fromJson(original.toJson());
        expect(restored.name, original.name);
        expect(restored.carbs, original.carbs);
      });

      test('works with special characters in name', () {
        final original = FoodItem(name: "McDonald's Fries", carbs: 44.0);
        final restored = FoodItem.fromJson(original.toJson());
        expect(restored.name, original.name);
        expect(restored.carbs, original.carbs);
      });
    });
  });
}
