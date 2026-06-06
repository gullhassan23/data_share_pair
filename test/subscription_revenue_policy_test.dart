import 'package:flutter_test/flutter_test.dart';
import 'package:share_app_latest/services/subscription_revenue_policy.dart';

void main() {
  group('shouldReportSubscriptionRevenue', () {
    test('reports revenue only for production environment on iOS', () {
      expect(shouldReportSubscriptionRevenue('production'), isTrue);
      expect(
        shouldReportSubscriptionRevenue('production', isAndroid: false),
        isTrue,
      );
    });

    test('does not report revenue for sandbox on iOS', () {
      expect(shouldReportSubscriptionRevenue('sandbox'), isFalse);
    });

    test('does not report revenue when environment is missing on iOS', () {
      expect(shouldReportSubscriptionRevenue(null), isFalse);
      expect(shouldReportSubscriptionRevenue(''), isFalse);
    });

    test('does not report revenue for unknown values on iOS', () {
      expect(shouldReportSubscriptionRevenue('staging'), isFalse);
      expect(shouldReportSubscriptionRevenue('Production'), isFalse);
    });

    test('reports Android revenue in release builds regardless of environment',
        () {
      expect(
        shouldReportSubscriptionRevenue(
          'sandbox',
          isAndroid: true,
          isReleaseBuild: true,
        ),
        isTrue,
      );
      expect(
        shouldReportSubscriptionRevenue(
          null,
          isAndroid: true,
          isReleaseBuild: true,
        ),
        isTrue,
      );
    });

    test('does not report Android revenue in debug builds', () {
      expect(
        shouldReportSubscriptionRevenue(
          'sandbox',
          isAndroid: true,
          isReleaseBuild: false,
        ),
        isFalse,
      );
    });
  });
}
