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
  };

  static Future<void> trackCurrentRoute(
    String? routeName, {
    String? previousRouteName,
  }) async {
    if (routeName == null || routeName.isEmpty) return;
    final screenName = _resolveScreenNameFromRoute(routeName);
    final previousScreenName = _resolveScreenNameFromRoute(previousRouteName);
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
    final mapped = _routeToScreenName[routeName];
    if (mapped != null) return mapped;

    var normalized = routeName.trim().toLowerCase();
    if (normalized.startsWith('/')) normalized = normalized.substring(1);
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    normalized = normalized.replaceAll(RegExp(r'_+'), '_');
    normalized = normalized.replaceAll(RegExp(r'^_|_$'), '');
    if (normalized.isEmpty) return 'unknown_screen';
    if (!normalized.endsWith('_screen')) normalized = '${normalized}_screen';
    return normalized;
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
