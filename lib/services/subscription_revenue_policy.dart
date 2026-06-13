import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:share_app_latest/utils/release_safe_log.dart';

/// Decision for whether a verified purchase should log Firebase revenue.
class PurchaseRevenueDecision {
  const PurchaseRevenueDecision({
    required this.shouldReport,
    required this.skipReason,
  });

  final bool shouldReport;
  final String skipReason;
}

/// When true, sandbox / TestFlight subscriptions also call [logPurchase].
///
/// Set `IAP_REPORT_SANDBOX_REVENUE=false` in `.env` before a production App Store
/// release if you want to exclude sandbox revenue from GA4 Monetization.
bool reportSandboxRevenueToFirebase() {
  if (!dotenv.isInitialized) return true;
  final raw = dotenv.env['IAP_REPORT_SANDBOX_REVENUE']?.trim().toLowerCase();
  if (raw == 'false' || raw == '0' || raw == 'no') return false;
  return true;
}

/// Whether a verified subscription should be logged as Firebase purchase revenue.
///
/// iOS production: blocks only when [environment] is `"sandbox"` unless
/// [reportSandboxRevenue] is enabled for QA / TestFlight testing.
///
/// Android: release builds report revenue regardless of environment string.
bool shouldReportSubscriptionRevenue(
  String? environment, {
  bool isAndroid = false,
  bool isReleaseBuild = kReleaseMode,
  bool reportSandboxRevenue = true,
}) {
  if (isAndroid) {
    final result = isReleaseBuild;
    iapDebugLog(
      '[RevenueFix] shouldReportSubscriptionRevenue: platform=android '
      'environment=$environment isReleaseBuild=$isReleaseBuild → $result',
    );
    return result;
  }

  if (environment == 'sandbox') {
    final result = reportSandboxRevenue;
    iapDebugLog(
      '[RevenueFix] shouldReportSubscriptionRevenue: platform=ios '
      'environment=sandbox reportSandboxRevenue=$reportSandboxRevenue → $result',
    );
    return result;
  }

  iapDebugLog(
    '[RevenueFix] shouldReportSubscriptionRevenue: platform=ios '
    'environment=$environment → true',
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
  bool reportSandboxRevenue = true,
}) {
  final isSandboxEnv = environment == 'sandbox';

  if (isRestore && !(reportSandboxRevenue && isSandboxEnv)) {
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
    reportSandboxRevenue: reportSandboxRevenue,
  )) {
    return PurchaseRevenueDecision(
      shouldReport: false,
      skipReason:
          environment == 'sandbox' ? 'environment_sandbox' : 'revenue_policy_blocked',
    );
  }

  return const PurchaseRevenueDecision(shouldReport: true, skipReason: '');
}
