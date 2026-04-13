import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_app_latest/utils/user_id.dart';

class OneTimeFreeSendStore {
  static const _fieldFreeSendUsed = 'oneTimeFreeSendUsed';
  static const _usersCollection = 'Users';
  static const _localKeyFreeSendUsed = 'one_time_free_send_used';

  static Future<bool> hasUsed() async {
    final prefs = await SharedPreferences.getInstance();
    final localUsed = prefs.getBool(_localKeyFreeSendUsed) ?? false;
    if (localUsed) return true;

    try {
      final userId = await getOrCreateUserId();
      final doc =
          await FirebaseFirestore.instance
              .collection(_usersCollection)
              .doc(userId)
              .get();
      final data = doc.data();
      final remoteUsed = data?[_fieldFreeSendUsed] == true;
      if (remoteUsed) {
        await prefs.setBool(_localKeyFreeSendUsed, true);
      }
      return remoteUsed;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markUsed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localKeyFreeSendUsed, true);
    try {
      final userId = await getOrCreateUserId();
      await FirebaseFirestore.instance.collection(_usersCollection).doc(userId).set({
        _fieldFreeSendUsed: true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Local write is already done; Firebase sync can retry later via hasUsed read.
    }
  }

  /// Local-first check with a best-effort remote sync pass.
  /// Returns true immediately when local says already used.
  static Future<bool> hasUsedLocalThenRemote() async {
    final prefs = await SharedPreferences.getInstance();
    final localUsed = prefs.getBool(_localKeyFreeSendUsed) ?? false;
    if (localUsed) return true;
    return hasUsed();
  }
}

