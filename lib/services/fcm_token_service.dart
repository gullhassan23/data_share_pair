import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:share_app_latest/utils/user_id.dart';

/// Retries getToken() so APNS can become ready on iOS (e.g. after permission).
Future<String?> _getFcmTokenWithRetry({int maxAttempts = 5, Duration delay = const Duration(seconds: 2)}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      debugPrint('[FCM] getToken attempt $attempt failed: $e');
      if (attempt < maxAttempts) await Future<void>.delayed(delay);
    }
  }
  return null;
}

Future<void> updateFcmTokenInFirestore() async {
  try {
    final userId = await getOrCreateUserId();
    final token = await _getFcmTokenWithRetry();
    if (token == null || token.isEmpty) {
      debugPrint('[FCM] No token available after retries (e.g. APNS not set or permission denied)');
      return;
    }
    await FirebaseFirestore.instance.collection('UsersFileTransfer').doc(userId).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
    debugPrint('[FCM] Token saved for user $userId');
  } catch (e) {
    debugPrint('[FCM] Failed to update token: $e');
  }
}

Future<void> initializeFcmAndUploadToken() async {
  try {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Notification permission denied');
      return;
    }
    await updateFcmTokenInFirestore();
  } catch (e) {
    debugPrint('[FCM] initializeFcmAndUploadToken error: $e');
  }
}
