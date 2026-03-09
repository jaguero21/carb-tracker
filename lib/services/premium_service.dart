import 'package:shared_preferences/shared_preferences.dart';
import '../config/storage_keys.dart';

class PremiumService {
  SharedPreferences? _prefs;

  bool get _isReady => _prefs != null;

  bool get isPremium =>
      (_isReady ? _prefs!.getBool(StorageKeys.isPremium) : null) ??
      true; // true for dev
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
}
