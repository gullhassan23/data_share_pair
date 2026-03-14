import 'package:shared_preferences/shared_preferences.dart';

const _kUserIdKey = 'device_user_id';

/// Returns a stable, device-based user id stored in SharedPreferences.
/// Used as Firestore doc id and sent to backend for subscription verification.
Future<String> getOrCreateUserId() async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString(_kUserIdKey);
  if (id != null && id.isNotEmpty) {
    return id;
  }

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  id = 'device_$timestamp';
  await prefs.setString(_kUserIdKey, id);
  return id;
}
