import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsScreenTracker {
  AnalyticsScreenTracker._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static String? _currentScreen;
  static DateTime? _screenEnterTime;

  static const Map<String, String> _routeToScreenName = <String, String>{
    '/premium': 'Premium_splash',
    '/onboaring': 'Home_screen',
    '/home': 'Transfer_Menu',
    '/choose-method-scan': 'Sender_via_menu',
    '/pairing': 'Wifi_sender',
    '/select-device': 'Send_device_Menu',
    '/send-scan-qr': 'QR_sender',
    '/receive-show-qr': 'Recive_QR',
    '/transfer-file': 'Select_file_Button',
    '/transfer-complete': 'Complete_menu',
  };

  /// Routes that resolve to these screen ids are not logged to analytics.
  static const Set<String> _excludedScreenIds = <String>{
    'login_screen',
    'signup_screen',
    'remove_duplicates_screen',
    'duplicate_preview_screen',
    'bluetooth_receiver_screen',
    'bluetooth_sender_screen',
    'transfer_recovery_screen',
  };

  /// Stable screen id for a [Get] route path (for tests and debugging).
  /// Excluded routes report as [unknown_screen].
  static String screenNameForRoute(String? routeName) {
    final id = _resolveScreenNameFromRoute(routeName);
    if (_excludedScreenIds.contains(id)) return 'unknown_screen';
    return id;
  }

  static Future<void> trackCurrentRoute(
    String? routeName, {
    String? previousRouteName,
  }) async {
    if (routeName == null || routeName.isEmpty) return;
    final trimmed = routeName.trim();
    final upper = trimmed.toUpperCase();
    if (upper.startsWith('DIALOG')) return;
    if (upper.startsWith('BOTTOMSHEET')) return;

    final screenName = _analyticsSafeScreenName(
      _resolveScreenNameFromRoute(trimmed),
    );
    if (_excludedScreenIds.contains(screenName)) {
      await _flushCurrentScreenDuration(nextScreen: 'analytics_excluded');
      _currentScreen = null;
      _screenEnterTime = null;
      return;
    }

    String? previousScreenName = _analyticsSafeScreenName(
      _resolveScreenNameFromRoute(previousRouteName),
    );
    if (_excludedScreenIds.contains(previousScreenName)) {
      previousScreenName = null;
    }
    await trackScreen(screenName, previousScreen: previousScreenName);
  }

  static Future<void> trackScreen(
    String screenName, {
    String? previousScreen,
  }) async {
    if (screenName.isEmpty) return;
    if (_currentScreen == screenName) return;

    final fromScreen = _analyticsSafeScreenName(previousScreen ?? _currentScreen);
    await _flushCurrentScreenDuration(nextScreen: screenName);

    _currentScreen = screenName;
    _screenEnterTime = DateTime.now();

    try {
      final screenEventName = _analyticsSafeEventName(screenName);
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenName,
      );
      // Keep screen_view for standard reports, but also emit a dedicated
      // per-screen custom event so each screen appears in Events list.
      await _analytics.logEvent(
        name: screenEventName,
        parameters: <String, Object>{
          'screen_name': screenName,
          if (fromScreen != null && fromScreen.isNotEmpty)
            'from_screen': fromScreen,
        },
      );
      await _analytics.logEvent(
        name: 'screen_opened',
        parameters: <String, Object>{
          'screen_name': screenName,
          if (fromScreen != null && fromScreen.isNotEmpty)
            'from_screen': fromScreen,
        },
      );
      if (fromScreen != null && fromScreen.isNotEmpty) {
        await _analytics.logEvent(
          name: 'screen_transition',
          parameters: <String, Object>{
            'from_screen': fromScreen,
            'to_screen': screenName,
          },
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('AnalyticsScreenTracker.trackScreen failed: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  /// Track non-screen user actions (button taps, flow steps, etc.)
  /// so they appear as dedicated events instead of screen_view entries.
  static Future<void> trackUiEvent(
    String eventName, {
    Map<String, Object>? parameters,
  }) async {
    final safeEventName = _analyticsSafeEventName(eventName);
    if (safeEventName.isEmpty) return;
    try {
      final params = <String, Object>{
        if (_currentScreen != null && _currentScreen!.isNotEmpty)
          'screen_name': _currentScreen!,
        if (parameters != null) ...parameters,
      };
      await _analytics.logEvent(
        name: safeEventName,
        parameters: params.isEmpty ? null : params,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('AnalyticsScreenTracker.trackUiEvent failed: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static Future<void> onAppBackground() async {
    await _flushCurrentScreenDuration(nextScreen: 'app_background');
  }

  static String _resolveScreenNameFromRoute(String? routeName) {
    if (routeName == null || routeName.isEmpty) return 'unknown_screen';
    var key = routeName.trim();
    if (key.isEmpty) return 'unknown_screen';
    key = key.split('?').first.split('#').first.trim();
    if (key.isEmpty) return 'unknown_screen';

    final mapped = _routeToScreenName[key];
    if (mapped != null) return mapped;

    final lowerKey = key.toLowerCase();
    final mappedLower = _routeToScreenName[lowerKey];
    if (mappedLower != null) return mappedLower;

    return 'unknown_screen';
  }

  // Keep custom names while preventing obviously invalid characters.
  static String _analyticsSafeScreenName(String? input) {
    if (input == null || input.isEmpty) return 'unknown_screen';
    var value = input
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (value.isEmpty) return 'unknown_screen';
    return value;
  }

  static String _analyticsSafeEventName(String? input) {
    if (input == null || input.isEmpty) return '';
    var value = input
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (value.isEmpty) return '';
    if (RegExp(r'^[0-9]').hasMatch(value)) {
      value = 'event_$value';
    }
    if (value.length > 40) {
      value = value.substring(0, 40).replaceAll(RegExp(r'_+$'), '');
    }
    return value;
  }

  static Future<void> _flushCurrentScreenDuration({
    required String nextScreen,
  }) async {
    final screen = _currentScreen;
    final enteredAt = _screenEnterTime;
    if (screen == null || enteredAt == null) return;

    final millis = DateTime.now().difference(enteredAt).inMilliseconds;
    if (millis < 300) return;

    try {
      await _analytics.logEvent(
        name: 'screen_time_spent',
        parameters: <String, Object>{
          'screen_name': screen,
          'next_screen': nextScreen,
          'duration_ms': millis,
          'duration_sec': millis ~/ 1000,
        },
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('AnalyticsScreenTracker._flushCurrentScreenDuration failed: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }
}



