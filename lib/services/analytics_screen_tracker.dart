import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsScreenTracker {
  AnalyticsScreenTracker._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static String? _currentScreen;
  static DateTime? _screenEnterTime;

  static const Map<String, String> _routeToScreenName = <String, String>{
    '/splash': 'splash_screen',
    '/onboaring': 'onboarding_screen',
    '/home': 'home_screen',
    '/connection-method': 'connection_method_screen',
    '/choose-method-scan': 'choose_method_scan_screen',
    '/pairing': 'pairing_screen',
    '/transfer-file': 'transfer_file_screen',
    '/transfer-progress': 'transfer_progress_screen',
    '/received-files': 'received_files_screen',
    '/receive-show-qr': 'qr_receiver_screen',
    '/send-scan-qr': 'qr_sender_screen',
    '/premium': 'premium_screen',
    '/configuration': 'configuration_screen',
    '/choose-method': 'choose_method_screen',
    '/select-device': 'select_device_screen',
    '/transfer-complete': 'transfer_complete_screen',
    '/contacts-selection': 'contacts_selection_screen',
    '/how-it-works': 'how_it_works_screen',
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

    final screenName = _resolveScreenNameFromRoute(trimmed);
    if (_excludedScreenIds.contains(screenName)) {
      await _flushCurrentScreenDuration(nextScreen: 'analytics_excluded');
      _currentScreen = null;
      _screenEnterTime = null;
      return;
    }

    String? previousScreenName = _resolveScreenNameFromRoute(previousRouteName);
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

    final fromScreen = previousScreen ?? _currentScreen;
    await _flushCurrentScreenDuration(nextScreen: screenName);

    _currentScreen = screenName;
    _screenEnterTime = DateTime.now();

    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenName,
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
    } catch (_) {}
  }

  static Future<void> onAppBackground() async {
    await _flushCurrentScreenDuration(nextScreen: 'app_background');
  }

  static String _resolveScreenNameFromRoute(String? routeName) {
    if (routeName == null || routeName.isEmpty) return 'unknown_screen';
    var key = routeName.trim();
    if (key.isEmpty) return 'unknown_screen';

    final mapped = _routeToScreenName[key];
    if (mapped != null) return mapped;

    final lowerKey = key.toLowerCase();
    final mappedLower = _routeToScreenName[lowerKey];
    if (mappedLower != null) return mappedLower;

    var normalized = key;
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    if (normalized.isEmpty) return 'unknown_screen';

    if (RegExp(r'[A-Z]').hasMatch(normalized)) {
      normalized = _pascalCaseToSnake(normalized);
    } else {
      normalized = normalized
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
    }

    if (normalized.isEmpty) return 'unknown_screen';
    if (!normalized.endsWith('_screen')) normalized = '${normalized}_screen';
    return normalized;
  }

  /// Converts `ChooseMethodScan` / `TransferCompleteScreen` → `choose_method_scan` / `transfer_complete_screen`.
  static String _pascalCaseToSnake(String input) {
    final buf = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      if (i > 0 &&
          c == c.toUpperCase() &&
          c != c.toLowerCase() &&
          input[i - 1] != '_') {
        buf.write('_');
      }
      buf.write(c.toLowerCase());
    }
    return buf
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
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
    } catch (_) {}
  }
}
