import 'package:flutter_test/flutter_test.dart';
import 'package:share_app_latest/services/subscription_revenue_policy.dart';

void main() {
  group('shouldReportSubscriptionRevenue', () {
    test('reports revenue only for production environment', () {
      expect(shouldReportSubscriptionRevenue('production'), isTrue);
    });

    test('does not report revenue for sandbox', () {
      expect(shouldReportSubscriptionRevenue('sandbox'), isFalse);
    });

    test('does not report revenue when environment is missing', () {
      expect(shouldReportSubscriptionRevenue(null), isFalse);
      expect(shouldReportSubscriptionRevenue(''), isFalse);
    });

    test('does not report revenue for unknown values', () {
      expect(shouldReportSubscriptionRevenue('staging'), isFalse);
      expect(shouldReportSubscriptionRevenue('Production'), isFalse);
    });
  });
}
