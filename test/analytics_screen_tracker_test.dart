import 'package:flutter_test/flutter_test.dart';
import 'package:share_app_latest/routes/app_routes.dart';
import 'package:share_app_latest/services/analytics_screen_tracker.dart';

void main() {
  group('AnalyticsScreenTracker.screenNameForRoute', () {
    test('maps declared AppRoutes to stable screen ids', () {
      expect(AnalyticsScreenTracker.screenNameForRoute(AppRoutes.home), 'home_screen');
      expect(
        AnalyticsScreenTracker.screenNameForRoute(AppRoutes.choosemethodscan),
        'choose_method_scan_screen',
      );
      expect(
        AnalyticsScreenTracker.screenNameForRoute(AppRoutes.howItWorks),
        'how_it_works_screen',
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

    test('normalizes PascalCase paths from anonymous Get.to routes', () {
      expect(
        AnalyticsScreenTracker.screenNameForRoute('/ChooseMethodScan'),
        'choose_method_scan_screen',
      );
      expect(
        AnalyticsScreenTracker.screenNameForRoute('/TransferCompleteScreen'),
        'transfer_complete_screen',
      );
    });

    test('returns unknown for empty input', () {
      expect(AnalyticsScreenTracker.screenNameForRoute(null), 'unknown_screen');
      expect(AnalyticsScreenTracker.screenNameForRoute(''), 'unknown_screen');
      expect(AnalyticsScreenTracker.screenNameForRoute('   '), 'unknown_screen');
    });
  });
}
