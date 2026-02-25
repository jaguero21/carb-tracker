// ignore_for_file: invalid_use_of_protected_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carb_tracker/main.dart';
import 'package:carb_tracker/models/food_item.dart';

void main() {
  // Setup SharedPreferences mock before tests
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Carb Tracker Total Calculation Tests', () {
    testWidgets('Initial total should be 0.0', (WidgetTester tester) async {
      await tester.pumpWidget(const CarbTrackerApp());
      await tester.pumpAndSettle();

      // Verify initial total is 0.0
      expect(find.text('0.0g'), findsOneWidget);
      expect(find.text('No foods added yet'), findsOneWidget);
    });

    testWidgets('Total updates when adding items manually',
        (WidgetTester tester) async {
      await tester.pumpWidget(const CarbTrackerApp());
      await tester.pumpAndSettle();

      // Get the state to manually add items (simulating successful API calls)
      final state = tester.state<CarbTrackerHomeState>(
        find.byType(CarbTrackerHome),
      );

      // Manually add food items to simulate API responses
      state.setState(() {
        state.foodItems.add(FoodItem(name: 'Apple', carbs: 25.0));
        state.totalCarbs += 25.0;
        state.showingDailyTotal = true;
      });
      await tester.pumpAndSettle();

      // Verify total shows 25.0g (appears in both total display and item list)
      expect(find.text('25.0g'), findsWidgets);
      expect(find.text('Apple'), findsOneWidget);

      // Add second item — must also notify AnimatedList
      state.setState(() {
        state.foodItems.add(FoodItem(name: 'Banana', carbs: 27.0));
        state.totalCarbs += 27.0;
        state.showingDailyTotal = true;
      });
      await tester.pumpAndSettle();

      // Verify total is now 52.0g
      expect(find.text('52.0g'), findsAtLeastNWidgets(1));
      // Banana is in foodItems but AnimatedList only knows about 1 item
      // (initialItemCount is only used on first build), so verify via state
      expect(state.foodItems.any((item) => item.name == 'Banana'), isTrue);
    });

    testWidgets('Total updates when removing items',
        (WidgetTester tester) async {
      await tester.pumpWidget(const CarbTrackerApp());
      await tester.pumpAndSettle();

      final state = tester.state<CarbTrackerHomeState>(
        find.byType(CarbTrackerHome),
      );

      // Add multiple items
      state.setState(() {
        state.foodItems.add(FoodItem(name: 'Apple', carbs: 25.0));
        state.foodItems.add(FoodItem(name: 'Banana', carbs: 27.0));
        state.foodItems.add(FoodItem(name: 'Orange', carbs: 15.0));
        state.totalCarbs = 67.0; // 25 + 27 + 15
        state.showingDailyTotal = true;
      });
      await tester.pumpAndSettle();

      expect(find.text('67.0g'), findsAtLeastNWidgets(1));

      // Remove second item (Banana - 27g)
      state.removeItem(1);
      await tester.pumpAndSettle();

      // Total should be 40.0g (67 - 27)
      expect(find.text('40.0g'), findsAtLeastNWidgets(1));
      expect(find.text('Banana'), findsNothing);

      // Remove first item (Apple - 25g)
      state.removeItem(0);
      await tester.pumpAndSettle();

      // Total should be 15.0g (40 - 25)
      expect(find.text('15.0g'), findsAtLeastNWidgets(1));
      expect(find.text('Apple'), findsNothing);
    });

    testWidgets('Reset clears total and items', (WidgetTester tester) async {
      await tester.pumpWidget(const CarbTrackerApp());
      await tester.pumpAndSettle();

      final state = tester.state<CarbTrackerHomeState>(
        find.byType(CarbTrackerHome),
      );

      // Add items
      state.setState(() {
        state.foodItems.add(FoodItem(name: 'Apple', carbs: 25.0));
        state.foodItems.add(FoodItem(name: 'Banana', carbs: 27.0));
        state.totalCarbs = 52.0;
        state.showingDailyTotal = true;
      });
      await tester.pumpAndSettle();

      expect(find.text('52.0g'), findsAtLeastNWidgets(1));
      expect(find.text('Reset'), findsOneWidget);

      // Tap reset button
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      // Verify total is back to 0
      expect(find.text('0.0g'), findsOneWidget);
      expect(find.text('No foods added yet'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);
      expect(find.text('Banana'), findsNothing);
    });

    testWidgets('Total calculation with decimal values',
        (WidgetTester tester) async {
      await tester.pumpWidget(const CarbTrackerApp());
      await tester.pumpAndSettle();

      final state = tester.state<CarbTrackerHomeState>(
        find.byType(CarbTrackerHome),
      );

      // Add items with decimal carb counts
      state.setState(() {
        state.foodItems.add(FoodItem(name: 'Item1', carbs: 12.5));
        state.foodItems.add(FoodItem(name: 'Item2', carbs: 8.3));
        state.foodItems.add(FoodItem(name: 'Item3', carbs: 5.7));
        state.totalCarbs = 26.5; // 12.5 + 8.3 + 5.7
        state.showingDailyTotal = true;
      });
      await tester.pumpAndSettle();

      expect(find.text('26.5g'), findsAtLeastNWidgets(1));

      // Remove item with 8.3g
      state.removeItem(1);
      await tester.pumpAndSettle();

      // Should be 18.2g (26.5 - 8.3)
      expect(find.text('18.2g'), findsAtLeastNWidgets(1));
    });

    testWidgets('Swipe to delete updates total correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(const CarbTrackerApp());
      await tester.pumpAndSettle();

      final state = tester.state<CarbTrackerHomeState>(
        find.byType(CarbTrackerHome),
      );

      // Add items
      state.setState(() {
        state.foodItems.add(FoodItem(name: 'Apple', carbs: 25.0));
        state.foodItems.add(FoodItem(name: 'Banana', carbs: 27.0));
        state.totalCarbs = 52.0;
        state.showingDailyTotal = true;
      });
      await tester.pumpAndSettle();

      expect(find.text('52.0g'), findsAtLeastNWidgets(1));

      // Swipe to delete Apple
      await tester.drag(find.text('Apple'), const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();

      // Total should update to 27.0g
      expect(find.text('27.0g'), findsAtLeastNWidgets(1));
      expect(find.text('Apple'), findsNothing);
      expect(find.text('Banana'), findsOneWidget);
    });

    testWidgets('Total persists correctly', (WidgetTester tester) async {
      // Set up initial saved value
      SharedPreferences.setMockInitialValues({'total_carbs': 42.5});

      await tester.pumpWidget(const CarbTrackerApp());
      await tester.pumpAndSettle();

      // Wait for async load to complete
      await tester.pump(const Duration(milliseconds: 100));

      // Should load saved total
      expect(find.text('42.5g'), findsAtLeastNWidgets(1));
    });

    testWidgets('Full persistence cycle: add items, close, and reopen app',
        (WidgetTester tester) async {
      // Start with clean state
      SharedPreferences.setMockInitialValues({});

      // First app session - add items
      await tester.pumpWidget(const CarbTrackerApp());
      await tester.pumpAndSettle();

      final state = tester.state<CarbTrackerHomeState>(
        find.byType(CarbTrackerHome),
      );

      // Add multiple items
      state.setState(() {
        state.foodItems.add(FoodItem(name: 'Breakfast', carbs: 45.0));
        state.foodItems.add(FoodItem(name: 'Lunch', carbs: 60.0));
        state.totalCarbs = 105.0;
        state.showingDailyTotal = true;
      });
      await tester.pumpAndSettle();

      // Manually trigger save (simulating what happens in the real app)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('total_carbs', state.totalCarbs);

      // Verify data was saved
      expect(find.text('105.0g'), findsAtLeastNWidgets(1));
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);

      // Simulate closing the app by disposing the widget
      await tester.pumpWidget(Container());

      // Simulate reopening the app (new session)
      await tester.pumpWidget(const CarbTrackerApp());
      await tester.pumpAndSettle();

      // Wait for async load to complete
      await tester.pump(const Duration(milliseconds: 100));

      // Verify total was restored
      expect(find.text('105.0g'), findsAtLeastNWidgets(1));

      // Note: Food items list is not persisted, only the total
      // This is the current app behavior
      expect(find.text('Breakfast'), findsNothing);
      expect(find.text('Lunch'), findsNothing);
    });
  });

  group('Edge Cases', () {
    testWidgets('Adding zero carb item', (WidgetTester tester) async {
      await tester.pumpWidget(const CarbTrackerApp());
      await tester.pumpAndSettle();

      final state = tester.state<CarbTrackerHomeState>(
        find.byType(CarbTrackerHome),
      );

      state.setState(() {
        state.foodItems.add(FoodItem(name: 'Water', carbs: 0.0));
        state.totalCarbs += 0.0;
        state.showingDailyTotal = true;
      });
      await tester.pumpAndSettle();

      expect(find.text('0.0g'), findsAtLeastNWidgets(1));
      expect(find.text('Water'), findsOneWidget);
    });

    testWidgets('Large carb values', (WidgetTester tester) async {
      await tester.pumpWidget(const CarbTrackerApp());
      await tester.pumpAndSettle();

      final state = tester.state<CarbTrackerHomeState>(
        find.byType(CarbTrackerHome),
      );

      state.setState(() {
        state.foodItems.add(FoodItem(name: 'Large Meal', carbs: 150.5));
        state.totalCarbs += 150.5;
        state.showingDailyTotal = true;
      });
      await tester.pumpAndSettle();

      expect(find.text('150.5g'), findsAtLeastNWidgets(1));
    });

    testWidgets('Remove all items returns to zero',
        (WidgetTester tester) async {
      await tester.pumpWidget(const CarbTrackerApp());
      await tester.pumpAndSettle();

      final state = tester.state<CarbTrackerHomeState>(
        find.byType(CarbTrackerHome),
      );

      // Add items
      state.setState(() {
        state.foodItems.add(FoodItem(name: 'Apple', carbs: 25.0));
        state.foodItems.add(FoodItem(name: 'Banana', carbs: 27.0));
        state.totalCarbs = 52.0;
        state.showingDailyTotal = true;
      });
      await tester.pumpAndSettle();

      // Remove all items
      state.removeItem(1); // Remove Banana
      await tester.pumpAndSettle();
      state.removeItem(0); // Remove Apple
      await tester.pumpAndSettle();

      expect(find.text('0.0g'), findsOneWidget);
      expect(find.text('No foods added yet'), findsOneWidget);
    });
  });
}
