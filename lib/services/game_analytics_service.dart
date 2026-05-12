import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gameanalytics_sdk/gameanalytics.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _QueuedDesignEvent {
  const _QueuedDesignEvent({required this.eventName, this.parameters});

  final String eventName;
  final Map<String, Object>? parameters;
}

class GameAnalyticsService {
  GameAnalyticsService._();

  static bool _isInitialized = false;
  static Future<void>? _initFuture;
  static final List<_QueuedDesignEvent> _pendingEvents =
      <_QueuedDesignEvent>[];

  static Future<void> initFromEnv() async {
    if (_initFuture != null) return _initFuture!;
    _initFuture = _initInternal();
    return _initFuture!;
  }

  static bool _isAndroidOrIos() {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static String _platformLabelForKeys() {
    return defaultTargetPlatform == TargetPlatform.android
        ? 'Android'
        : 'iOS';
  }

  /// Android / iOS keys from `.env` only.
  static ({String gameKey, String secretKey}) _resolveKeys() {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final gameKey = (isAndroid
            ? dotenv.env['GAME_ANALYTICS_GAME_KEY_ANDROID']
            : dotenv.env['GAME_ANALYTICS_GAME_KEY_IOS'])
        ?.trim() ??
        '';
    final secretKey = (isAndroid
            ? dotenv.env['GAME_ANALYTICS_SECRET_KEY_ANDROID']
            : dotenv.env['GAME_ANALYTICS_SECRET_KEY_IOS'])
        ?.trim() ??
        '';
    return (gameKey: gameKey, secretKey: secretKey);
  }

  static Future<void> _configureBuildVersion() async {
    try {
      await GameAnalytics.configureAutoDetectAppVersion(
        true,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      final info = await PackageInfo.fromPlatform();
      await GameAnalytics.configureBuild(
        '${info.version}+${info.buildNumber}',
      );
    }
  }

  static Future<void> _initInternal() async {
    if (_isInitialized) return;

    if (!_isAndroidOrIos()) {
      if (kDebugMode) {
        debugPrint(
          'GameAnalyticsService skipped: Android and iOS only.',
        );
      }
      return;
    }

    final (:gameKey, :secretKey) = _resolveKeys();

    if (gameKey.isEmpty || secretKey.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'GameAnalyticsService skipped: ${_platformLabelForKeys()} keys '
          'missing in .env',
        );
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('GA init started...');
        try {
          await GameAnalytics.setEnabledInfoLog(
            true,
          ).timeout(const Duration(seconds: 5));
          await GameAnalytics.setEnabledVerboseLog(
            true,
          ).timeout(const Duration(seconds: 5));
          debugPrint('GA debug logs enabled.');
        } catch (e) {
          debugPrint('GA debug-log setup warning: $e');
        }
      }

      await _configureBuildVersion();

      var completedNormally = false;
      if (kDebugMode) {
        debugPrint('GA initialize call started.');
      }
      try {
        await GameAnalytics.initialize(
          gameKey,
          secretKey,
        ).timeout(const Duration(seconds: 12));
        _isInitialized = true;
        completedNormally = true;
      } on TimeoutException {
        // Some Android devices/plugin versions never complete the future even
        // though native GA runtime is active. Use soft-init so event flow continues.
        _isInitialized = true;
        if (kDebugMode) {
          debugPrint(
            'GA initialize timed out; continuing with soft init.',
          );
        }
      }
      if (kDebugMode) {
        debugPrint(
          completedNormally
              ? 'GA init completed.'
              : 'GA init finished after timeout (soft).',
        );
      }
      await _flushPendingEvents();
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
    if (eventName.trim().isEmpty) return;
    if (!_isInitialized) {
      _pendingEvents.add(
        _QueuedDesignEvent(eventName: eventName, parameters: parameters),
      );
      return;
    }
    await _sendDesignEvent(eventName, parameters);
  }

  static String? _encodeCustomFields(Map<String, Object>? parameters) {
    if (parameters == null || parameters.isEmpty) return null;
    try {
      final map = <String, dynamic>{};
      for (final e in parameters.entries) {
        final key = e.key.trim();
        if (key.isEmpty) continue;
        final v = e.value;
        if (v is num || v is bool || v is String) {
          map[key] = v;
        } else {
          map[key] = v.toString();
        }
      }
      if (map.isEmpty) return null;
      return jsonEncode(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _sendDesignEvent(
    String eventName, [
    Map<String, Object>? parameters,
  ]) async {
    try {
      final safeEventId = _safeEventId(eventName);
      if (kDebugMode) {
        debugPrint('GA event dispatch requested: $safeEventId');
      }
      final customFields = _encodeCustomFields(parameters);
      final payload = <String, dynamic>{'eventId': safeEventId};
      if (customFields != null) {
        payload['customFields'] = customFields;
        payload['mergeFields'] = true;
      }
      final future = GameAnalytics.addDesignEvent(payload);
      if (kDebugMode) {
        future
            .then((_) {
              debugPrint('GA event sent: $safeEventId');
            })
            .catchError((Object error) {
              debugPrint('GA event callback warning ($safeEventId): $error');
            });
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('GameAnalyticsService.logDesignEvent failed: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static Future<void> _flushPendingEvents() async {
    if (_pendingEvents.isEmpty) return;
    final events = List<_QueuedDesignEvent>.from(_pendingEvents);
    _pendingEvents.clear();
    for (final q in events) {
      await _sendDesignEvent(q.eventName, q.parameters);
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
