import 'package:shared_preferences/shared_preferences.dart';

/// Stores how many temporary WiFi transfers the user has unlocked
/// by watching rewarded ads. Each rewarded view adds one credit; each
/// WiFi transfer consumes one credit.
class RewardedAccessStore {
  static const _keyWifiCredits = 'wifi_transfer_credits';

  static Future<int> getCredits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyWifiCredits) ?? 0;
  }

  static Future<void> addCredit() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyWifiCredits) ?? 0;
    await prefs.setInt(_keyWifiCredits, current + 1);
  }

  /// Returns true if a credit was consumed and saved.
  static Future<bool> consumeCreditIfAvailable() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyWifiCredits) ?? 0;
    if (current <= 0) return false;
    await prefs.setInt(_keyWifiCredits, current - 1);
    return true;
  }
}

