import 'package:flutter_test/flutter_test.dart';
import 'package:share_app_latest/services/subscription_revenue_policy.dart';

void main() {
  group('shouldReportSubscriptionRevenue', () {
    test('allows production environment on iOS', () {
      expect(shouldReportSubscriptionRevenue('production'), isTrue);
    });

    test('allows null or missing environment on iOS', () {
      expect(shouldReportSubscriptionRevenue(null), isTrue);
      expect(shouldReportSubscriptionRevenue(''), isTrue);
    });

    test('blocks sandbox on iOS when sandbox reporting disabled', () {
      expect(
        shouldReportSubscriptionRevenue(
          'sandbox',
          reportSandboxRevenue: false,
        ),
        isFalse,
      );
    });

    test('allows sandbox on iOS when sandbox reporting enabled', () {
      expect(
        shouldReportSubscriptionRevenue(
          'sandbox',
          reportSandboxRevenue: true,
        ),
        isTrue,
      );
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

  group('evaluatePurchaseRevenue', () {
    test('allows verified production purchase on iOS', () {
      final decision = evaluatePurchaseRevenue(
        isValid: true,
        isRestore: false,
        environment: 'production',
        productId: 'com.app.monthly',
        transactionId: 'tx_1',
        verifiedByApple: true,
      );
      expect(decision.shouldReport, isTrue);
      expect(decision.skipReason, isEmpty);
    });

    test('allows sandbox purchase when sandbox reporting enabled', () {
      final decision = evaluatePurchaseRevenue(
        isValid: true,
        isRestore: false,
        environment: 'sandbox',
        productId: 'com.app.monthly',
        transactionId: 'tx_1',
        verifiedByApple: true,
        reportSandboxRevenue: true,
      );
      expect(decision.shouldReport, isTrue);
    });

    test('allows sandbox restored StoreKit2 flow when sandbox reporting enabled',
        () {
      final decision = evaluatePurchaseRevenue(
        isValid: true,
        isRestore: true,
        environment: 'sandbox',
        productId: 'com.app.monthly',
        transactionId: 'tx_1',
        verifiedByApple: true,
        reportSandboxRevenue: true,
      );
      expect(decision.shouldReport, isTrue);
    });

    test('blocks sandbox when sandbox reporting disabled', () {
      final decision = evaluatePurchaseRevenue(
        isValid: true,
        isRestore: false,
        environment: 'sandbox',
        productId: 'com.app.monthly',
        transactionId: 'tx_1',
        verifiedByApple: true,
        reportSandboxRevenue: false,
      );
      expect(decision.shouldReport, isFalse);
      expect(decision.skipReason, 'environment_sandbox');
    });

    test('blocks production restore when sandbox reporting disabled', () {
      final decision = evaluatePurchaseRevenue(
        isValid: true,
        isRestore: true,
        environment: 'production',
        productId: 'com.app.monthly',
        transactionId: 'tx_1',
        verifiedByApple: true,
        reportSandboxRevenue: false,
      );
      expect(decision.shouldReport, isFalse);
      expect(decision.skipReason, 'restore_flow');
    });

    test('blocks missing transaction id', () {
      final decision = evaluatePurchaseRevenue(
        isValid: true,
        isRestore: false,
        environment: 'production',
        productId: 'com.app.monthly',
        transactionId: null,
        verifiedByApple: true,
      );
      expect(decision.shouldReport, isFalse);
      expect(decision.skipReason, 'missing_transaction_id');
    });
  });
}
