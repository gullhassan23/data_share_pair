import 'package:shared_preferences/shared_preferences.dart';

/// Simple persistent cache for premium status so ads can respect Pro
/// immediately on app start, before Firestore / IAP load completes.
class PremiumStatusStore {
  static const _keyIsPremium = 'is_premium';

  static Future<void> saveIsPremium(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsPremium, value);
  }

  /// Returns null if no value has been stored yet.
  static Future<bool?> loadIsPremium() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_keyIsPremium)) return null;
    return prefs.getBool(_keyIsPremium);
  }
}

