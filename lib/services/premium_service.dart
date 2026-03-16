import 'package:shared_preferences/shared_preferences.dart';
import '../config/storage_keys.dart';

class PremiumService {
  static const String monthlyPlan = 'monthly';
  static const String yearlyPlan = 'yearly';

  SharedPreferences? _prefs;

  bool get _isReady => _prefs != null;

  bool get isPremium =>
      (_isReady ? _prefs!.getBool(StorageKeys.isPremium) : null) ?? false;
  String? get premiumPlan =>
      _isReady ? _prefs!.getString(StorageKeys.premiumPlan) : null;
  bool get isManualEntryEnabled =>
      isPremium &&
      ((_isReady ? _prefs!.getBool(StorageKeys.premiumManualEntry) : null) ??
          true);
  bool get isHealthSyncEnabled =>
      isPremium &&
      ((_isReady ? _prefs!.getBool(StorageKeys.premiumHealthSync) : null) ??
          true);
  bool get isCloudSyncEnabled =>
      isPremium &&
      ((_isReady ? _prefs!.getBool(StorageKeys.premiumCloudSync) : null) ??
          false);
  bool get isMacrosEnabled =>
      isPremium &&
      ((_isReady ? _prefs!.getBool(StorageKeys.premiumMacros) : null) ?? false);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> setFeatureEnabled(String key, bool value) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(key, value);
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

    // Premium is sold as a single bundle; keep feature flags in sync.
    await Future.wait([
      prefs.setBool(StorageKeys.premiumManualEntry, value),
      prefs.setBool(StorageKeys.premiumHealthSync, value),
      prefs.setBool(StorageKeys.premiumCloudSync, value),
      prefs.setBool(StorageKeys.premiumMacros, value),
    ]);
  }
}
