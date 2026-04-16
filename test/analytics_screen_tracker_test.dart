import 'package:flutter_test/flutter_test.dart';
import 'package:share_app_latest/routes/app_routes.dart';
import 'package:share_app_latest/services/analytics_screen_tracker.dart';

void main() {
  group('AnalyticsScreenTracker.screenNameForRoute', () {
    test('maps only configured routes to requested screen ids', () {
      expect(
        AnalyticsScreenTracker.screenNameForRoute(AppRoutes.home),
        'Transfer_Menu',
      );
      expect(
        AnalyticsScreenTracker.screenNameForRoute(AppRoutes.choosemethodscan),
        'Sender_via_menu',
      );
      expect(
        AnalyticsScreenTracker.screenNameForRoute(AppRoutes.transferFile),
        'select_file_Button',
      );
    });

    test('excluded routes report as unknown_screen', () {
      expect(
        AnalyticsScreenTracker.screenNameForRoute(AppRoutes.transferRecovery),
        'unknown_screen',
      );
      expect(
        AnalyticsScreenTracker.screenNameForRoute(AppRoutes.login),
        'unknown_screen',
      );
      expect(
        AnalyticsScreenTracker.screenNameForRoute(AppRoutes.bluetoothReceiver),
        'unknown_screen',
      );
    });

    test('unmapped routes report as unknown_screen', () {
      expect(
        AnalyticsScreenTracker.screenNameForRoute(AppRoutes.howItWorks),
        'unknown_screen',
      );
      expect(
        AnalyticsScreenTracker.screenNameForRoute('/ChooseMethodScan'),
        'unknown_screen',
      );
    });

    test('returns unknown for empty input', () {
      expect(AnalyticsScreenTracker.screenNameForRoute(null), 'unknown_screen');
      expect(AnalyticsScreenTracker.screenNameForRoute(''), 'unknown_screen');
      expect(AnalyticsScreenTracker.screenNameForRoute('   '), 'unknown_screen');
    });
  });
}
