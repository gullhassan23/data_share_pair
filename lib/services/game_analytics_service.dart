import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gameanalytics_sdk/gameanalytics.dart';

class GameAnalyticsService {
  GameAnalyticsService._();

  static bool _isInitialized = false;

  static Future<void> initFromEnv() async {
    if (_isInitialized) return;

    final gameKey = dotenv.env['GAME_ANALYTICS_GAME_KEY']?.trim() ?? '';
    final secretKey = dotenv.env['GAME_ANALYTICS_SECRET_KEY']?.trim() ?? '';

    if (gameKey.isEmpty || secretKey.isEmpty) {
      if (kDebugMode) {
        debugPrint('GameAnalyticsService skipped: keys missing in .env');
      }
      return;
    }

    try {
      if (kDebugMode) {
        await GameAnalytics.setEnabledInfoLog(true);
        debugPrint('GA init started...');
      }
      await GameAnalytics.initialize(gameKey, secretKey);
      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('GA init success.');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('GameAnalyticsService.initFromEnv failed: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static Future<void> logDesignEvent(
    String eventName, {
    Map<String, Object>? parameters,
  }) async {
    if (!_isInitialized || eventName.trim().isEmpty) return;

    try {
      final safeEventId = _safeEventId(eventName);
      // Keep GA events flat/top-level in dashboard: send only eventId.
      await GameAnalytics.addDesignEvent(<String, dynamic>{
        'eventId': safeEventId,
      });
      if (kDebugMode) {
        debugPrint('GA event sent: $safeEventId');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('GameAnalyticsService.logDesignEvent failed: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static String _safeEventId(String eventName) {
    final value = eventName
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9_:.\-]+'), '_');
    if (value.isEmpty) return 'unknown_event';
    if (value.length <= 64) return value;
    return value.substring(0, 64);
  }
}
