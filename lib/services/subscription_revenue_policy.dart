import 'package:flutter/foundation.dart';

/// Decision for whether a verified purchase should log Firebase revenue.
class PurchaseRevenueDecision {
  const PurchaseRevenueDecision({
    required this.shouldReport,
    required this.skipReason,
  });

  final bool shouldReport;
  final String skipReason;
}

/// Whether a verified subscription should be logged as Firebase purchase revenue.
///
/// iOS: blocks only when [environment] is explicitly `"sandbox"`.
/// Null/empty/missing environment does NOT block (verified purchases still count).
///
/// Android: release builds report revenue regardless of environment string.
bool shouldReportSubscriptionRevenue(
  String? environment, {
  bool isAndroid = false,
  bool isReleaseBuild = kReleaseMode,
}) {
  if (isAndroid) {
    final result = isReleaseBuild;
    debugPrint(
      '[RevenueFix] shouldReportSubscriptionRevenue: platform=android '
      'environment=$environment isReleaseBuild=$isReleaseBuild → $result',
    );
    return result;
  }

  if (environment == 'sandbox') {
    debugPrint(
      '[RevenueFix] shouldReportSubscriptionRevenue: platform=ios '
      'environment=sandbox → false',
    );
    return false;
  }

  debugPrint(
    '[RevenueFix] shouldReportSubscriptionRevenue: platform=ios '
    'environment=$environment → true (not explicitly sandbox)',
  );
  return true;
}

/// Full revenue gate for a single purchase after backend verification.
PurchaseRevenueDecision evaluatePurchaseRevenue({
  required bool isValid,
  required bool isRestore,
  required String? environment,
  required String productId,
  required String? transactionId,
  bool? verifiedByApple,
  bool isAndroid = false,
  bool isReleaseBuild = kReleaseMode,
}) {
  if (isRestore) {
    return const PurchaseRevenueDecision(
      shouldReport: false,
      skipReason: 'restore_flow',
    );
  }
  if (!isValid) {
    return const PurchaseRevenueDecision(
      shouldReport: false,
      skipReason: 'invalid_receipt',
    );
  }
  if (verifiedByApple == false) {
    return const PurchaseRevenueDecision(
      shouldReport: false,
      skipReason: 'unverified_receipt',
    );
  }
  if (productId.isEmpty) {
    return const PurchaseRevenueDecision(
      shouldReport: false,
      skipReason: 'missing_product_id',
    );
  }
  if (transactionId == null || transactionId.isEmpty) {
    return const PurchaseRevenueDecision(
      shouldReport: false,
      skipReason: 'missing_transaction_id',
    );
  }
  if (!shouldReportSubscriptionRevenue(
    environment,
    isAndroid: isAndroid,
    isReleaseBuild: isReleaseBuild,
  )) {
    return PurchaseRevenueDecision(
      shouldReport: false,
      skipReason:
          environment == 'sandbox' ? 'environment_sandbox' : 'revenue_policy_blocked',
    );
  }

  return const PurchaseRevenueDecision(shouldReport: true, skipReason: '');
}
