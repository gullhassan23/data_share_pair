import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gameanalytics_sdk/gameanalytics.dart';

class GameAnalyticsService {
  GameAnalyticsService._();

  static bool _isInitialized = false;
  static Future<void>? _initFuture;
  static final List<String> _pendingEventNames = <String>[];

  static Future<void> initFromEnv() async {
    if (_initFuture != null) return _initFuture!;
    _initFuture = _initInternal();
    return _initFuture!;
  }

  static Future<void> _initInternal() async {
    if (_isInitialized) return;

    final gameKey = dotenv.env['GAME_ANALYTICS_GAME_KEY']?.trim() ?? '';
    final secretKey = dotenv.env['GAME_ANALYTICS_SECRET_KEY']?.trim() ?? '';

    if (gameKey.isEmpty || secretKey.isEmpty) {
      if (kDebugMode) {
        print('GameAnalyticsService skipped: keys missing in .env');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('GA init started...');
        try {
          await GameAnalytics.setEnabledInfoLog(
            true,
          ).timeout(const Duration(seconds: 5));
          await GameAnalytics.setEnabledVerboseLog(
            true,
          ).timeout(const Duration(seconds: 5));
          print('GA debug logs enabled.');
        } catch (e) {
          print('GA debug-log setup warning: $e');
        }
      }
      print('GA initialize call started.');
      try {
        await GameAnalytics.initialize(
          gameKey,
          secretKey,
        ).timeout(const Duration(seconds: 12));
        _isInitialized = true;
      } on TimeoutException {
        // Some Android devices/plugin versions never complete the future even
        // though native GA runtime is active. Use soft-init so event flow continues.
        _isInitialized = true;
        print('GA initialize timed out; continuing with soft init.');
      }
      if (kDebugMode) {
        print('GA init success.');
      }
      await _flushPendingEvents();
      await _sendDesignEvent('ga_sdk_initialized');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('GameAnalyticsService.initFromEnv failed: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static Future<void> logDesignEvent(
    String eventName, {
    Map<String, Object>? parameters,
  }) async {
    if (eventName.trim().isEmpty) return;
    if (!_isInitialized) {
      // Queue events that happen before SDK initialization completes.
      _pendingEventNames.add(eventName);
      return;
    }
    await _sendDesignEvent(eventName);
  }

  static Future<void> _sendDesignEvent(String eventName) async {
    try {
      final safeEventId = _safeEventId(eventName);
      if (kDebugMode) {
        print('GA event dispatch requested: $safeEventId');
      }
      // Keep GA events flat/top-level in dashboard: send only eventId.
      final future = GameAnalytics.addDesignEvent(
        <String, dynamic>{'eventId': safeEventId},
      );
      if (kDebugMode) {
        future
            .then((_) {
              print('GA event sent: $safeEventId');
            })
            .catchError((error) {
              print('GA event callback warning ($safeEventId): $error');
            });
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('GameAnalyticsService.logDesignEvent failed: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static Future<void> _flushPendingEvents() async {
    if (_pendingEventNames.isEmpty) return;
    final events = List<String>.from(_pendingEventNames);
    _pendingEventNames.clear();
    for (final eventName in events) {
      await _sendDesignEvent(eventName);
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
