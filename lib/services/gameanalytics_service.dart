import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gameanalytics_sdk/gameanalytics.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// GameAnalytics integration following the official Flutter SDK lifecycle:
/// 1. Configuration (before [GameAnalytics.initialize])
/// 2. Initialization
/// 3. Event tracking (after init)
///
/// https://docs.gameanalytics.com/event-tracking-and-integrations/sdks-and-collection-api/game-engine-sdks/flutter/
class GameAnalyticsService {
  GameAnalyticsService._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  /// Whitelisted custom dimension values (configured before init).
  static const List<String> customDimensions01 = ['free', 'premium'];
  static const List<String> customDimensions02 = ['android', 'ios', 'other'];
  static const List<String> customDimensions03 = [
    'wifi',
    'bluetooth',
    'qr',
    'unknown',
  ];

  static const List<String> resourceCurrencies = ['premium'];
  static const List<String> resourceItemTypes = ['subscription', 'unlock'];

  /// Call once at app startup, after `.env` is loaded.
  static Future<void> init({bool? isPremium}) async {
    if (_initialized) return;

    final gameKey = _resolveKey('GAMEANALYTICS_GAME_KEY');
    final secretKey = _resolveKey('GAMEANALYTICS_SECRET_KEY');
    if (gameKey == null || secretKey == null) {
      if (kDebugMode) {
        debugPrint(
          '[GameAnalytics] GAMEANALYTICS_GAME_KEY / GAMEANALYTICS_SECRET_KEY '
          'missing in .env — skipping SDK init',
        );
      }
      return;
    }

    try {
      await _configure(gameKey: gameKey, secretKey: secretKey);
      _initialized = true;
      await _applyRuntimeDimensions(isPremium: isPremium);
      if (kDebugMode) {
        debugPrint('[GameAnalytics] SDK initialized');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[GameAnalytics] init failed: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static String? _resolveKey(String baseKey) {
    if (!dotenv.isInitialized) return null;
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = dotenv.env['${baseKey}_ANDROID']?.trim();
        if (android != null && android.isNotEmpty) return android;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = dotenv.env['${baseKey}_IOS']?.trim();
        if (ios != null && ios.isNotEmpty) return ios;
      }
    }
    final value = dotenv.env[baseKey]?.trim();
    return (value != null && value.isNotEmpty) ? value : null;
  }

  /// Configuration phase — must run before [GameAnalytics.initialize].
  static Future<void> _configure({
    required String gameKey,
    required String secretKey,
  }) async {
    // 3.x / 4.x — debug logging (docs §4.2 complete example)
    if (kDebugMode) {
      await GameAnalytics.setEnabledInfoLog(true);
      await GameAnalytics.setEnabledVerboseLog(true);
    }

    // 3.3 — custom dimensions whitelist
    await GameAnalytics.configureAvailableCustomDimensions01(customDimensions01);
    await GameAnalytics.configureAvailableCustomDimensions02(customDimensions02);
    await GameAnalytics.configureAvailableCustomDimensions03(customDimensions03);

    // 3.4 — resource currencies / item types (required before resource events)
    await GameAnalytics.configureAvailableResourceCurrencies(resourceCurrencies);
    await GameAnalytics.configureAvailableResourceItemTypes(resourceItemTypes);

    // 3.1 — build version + auto-detect (docs §3.1)
    await GameAnalytics.configureAutoDetectAppVersion(true);
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      if (version.isNotEmpty) {
        await GameAnalytics.configureBuild(version);
      }
    } catch (_) {}

    // 4.1 — initialize SDK
    await GameAnalytics.initialize(gameKey, secretKey);
  }

  static Future<void> _applyRuntimeDimensions({bool? isPremium}) async {
    await setPlatformDimension();
    if (isPremium != null) {
      await setPremiumDimension(isPremium);
    }
  }

  static Future<void> setPlatformDimension() async {
    if (!_initialized) return;
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'other',
    };
    if (!customDimensions02.contains(platform)) return;
    try {
      await GameAnalytics.setCustomDimension02(platform);
    } catch (_) {}
  }

  static Future<void> setPremiumDimension(bool isPremium) async {
    if (!_initialized) return;
    final value = isPremium ? 'premium' : 'free';
    if (!customDimensions01.contains(value)) return;
    try {
      await GameAnalytics.setCustomDimension01(value);
    } catch (_) {}
  }

  /// Design event — docs Event Tracking § Design Events.
  static Future<void> trackDesignEvent(
    String eventId, {
    double? value,
  }) async {
    if (!_initialized || eventId.trim().isEmpty) return;
    try {
      if (value != null) {
        await GameAnalytics.addDesignEvent({
          'eventId': eventId,
          'value': value,
        });
      } else {
        await GameAnalytics.addDesignEvent({'eventId': eventId});
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[GameAnalytics] trackDesignEvent failed: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  /// Screen / navigation mirror for Firebase screen analytics.
  static Future<void> trackScreenOpened(
    String screenName, {
    String? fromScreen,
  }) async {
    final safe = _safeEventSegment(screenName);
    if (safe.isEmpty) return;
    final from = fromScreen == null ? null : _safeEventSegment(fromScreen);
    final eventId =
        from != null && from.isNotEmpty
            ? 'screen:opened:$safe:from:$from'
            : 'screen:opened:$safe';
    await trackDesignEvent(eventId);
  }

  static Future<void> trackUiEvent(
    String eventName, {
    String? screenName,
  }) async {
    final safeEvent = _safeEventSegment(eventName);
    if (safeEvent.isEmpty) return;
    final screen = screenName == null ? null : _safeEventSegment(screenName);
    final eventId =
        screen != null && screen.isNotEmpty
            ? 'ui:$safeEvent:screen:$screen'
            : 'ui:$safeEvent';
    await trackDesignEvent(eventId);
  }

  static Future<void> trackScreenTimeSpent({
    required String screenName,
    required String nextScreen,
    required int durationMs,
  }) async {
    final safeScreen = _safeEventSegment(screenName);
    final safeNext = _safeEventSegment(nextScreen);
    if (safeScreen.isEmpty) return;
    await trackDesignEvent(
      'screen:time:$safeScreen:next:$safeNext',
      value: durationMs.toDouble(),
    );
  }

  static Future<void> trackLifecycle(String state) async {
    await trackDesignEvent('app:lifecycle:$state');
  }

  static String _safeEventSegment(String input) {
    var value = input
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (value.length > 32) {
      value = value.substring(0, 32).replaceAll(RegExp(r'_+$'), '');
    }
    return value;
  }
}
