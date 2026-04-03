import 'package:shared_preferences/shared_preferences.dart';
import '../config/storage_keys.dart';

class PremiumService {
  static const String monthlyPlan = 'monthly';
  static const String yearlyPlan = 'yearly';
  static const int freeDailyLookupLimit = 4;

  SharedPreferences? _prefs;

  bool get _isReady => _prefs != null;

  bool get isPremium =>
      (_isReady ? _prefs!.getBool(StorageKeys.isPremium) : null) ?? false;
  String? get premiumPlan =>
      _isReady ? _prefs!.getString(StorageKeys.premiumPlan) : null;

  // All features are available to everyone — subscription unlocks unlimited AI lookups.
  bool get isManualEntryEnabled => true;
  bool get isHealthSyncEnabled => true;
  bool get isCloudSyncEnabled => true;
  bool get isMacrosEnabled => true;

  int get dailyLookupCount =>
      (_isReady ? _prefs!.getInt(StorageKeys.dailyLookupCount) : null) ?? 0;

  bool get hasReachedDailyLimit =>
      !isPremium && dailyLookupCount >= freeDailyLookupLimit;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await resetLookupCountIfNewDay();
  }

  /// Resets the daily lookup count if the stored date is not today.
  Future<void> resetLookupCountIfNewDay() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString(StorageKeys.dailyLookupDate);
    if (storedDate != today) {
      await prefs.setInt(StorageKeys.dailyLookupCount, 0);
      await prefs.setString(StorageKeys.dailyLookupDate, today);
    }
  }

  Future<void> incrementLookupCount() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final count = (prefs.getInt(StorageKeys.dailyLookupCount) ?? 0) + 1;
    await prefs.setInt(StorageKeys.dailyLookupCount, count);
  }

  Future<void> setPremiumPlan(String? plan) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    if (plan == null || plan.isEmpty) {
      await prefs.remove(StorageKeys.premiumPlan);
      return;
    }
    await prefs.setString(StorageKeys.premiumPlan, plan);
  }

  Future<void> setPremiumEnabled(bool value, {String? plan}) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(StorageKeys.isPremium, value);
    if (value && plan != null && plan.isNotEmpty) {
      await prefs.setString(StorageKeys.premiumPlan, plan);
    }
    if (!value) {
      await prefs.remove(StorageKeys.premiumPlan);
    }
  }
}
