/// Centralized storage keys shared between Dart and native iOS code.
/// If you change a key here, update the matching constant in
/// ios/CarbShared/Sources/CarbShared/CarbDataStore.swift
class StorageKeys {
  StorageKeys._();

  // App group identifier (must match Runner.entitlements)
  static const String appGroupId = 'group.com.jamesaguero.mycarbtracker';

  // SharedPreferences keys (local to Flutter)
  static const String totalCarbs = 'total_carbs';
  static const String foodItems = 'food_items';
  static const String lastSaveDate = 'last_save_date';
  static const String dailyCarbGoal = 'daily_carb_goal';
  static const String savedFoods = 'saved_foods';

  // HomeWidget / UserDefaults keys (shared with native iOS)
  static const String widgetTotalCarbs = 'totalCarbs';
  static const String widgetLastFoodName = 'lastFoodName';
  static const String widgetLastFoodCarbs = 'lastFoodCarbs';
  static const String widgetDailyCarbGoal = 'dailyCarbGoal';
  static const String widgetSiriLoggedItems = 'siriLoggedItems';
  static const String widgetFlutterTotalCarbs = 'flutter.total_carbs';

  // iOS widget name
  static const String widgetName = 'CarbWiseWidget';
}
