import 'package:flutter/foundation.dart';
import 'package:share_app_latest/services/subscription_revenue_policy.dart';

enum SubscriptionReportLogLevel { info, success, warning, error }

class SubscriptionReportLogLine {
  SubscriptionReportLogLine({
    required this.timestamp,
    required this.message,
    required this.level,
  });

  final DateTime timestamp;
  final String message;
  final SubscriptionReportLogLevel level;
}

/// In-app tracker for Firebase IAP revenue + event reporting (QA / release testing).
class SubscriptionAnalyticsReportStore extends ChangeNotifier {
  SubscriptionAnalyticsReportStore._();

  static final SubscriptionAnalyticsReportStore instance =
      SubscriptionAnalyticsReportStore._();

  static const int _maxLogs = 120;

  bool sandboxReportingEnabled = reportSandboxRevenueToFirebase();

  bool? lastVerificationValid;
  bool? lastVerifiedByApple;
  String? lastEnvironment;
  String? lastProductId;
  String? lastTransactionId;
  String? lastPurchaseStatus;
  String? lastSkipReason;
  String? lastError;

  bool revenueReported = false;
  bool eventReported = false;
  bool reportingAttempted = false;
  String? lastRevenueValue;
  String? lastRevenueCurrency;

  DateTime? lastUpdatedAt;
  final List<SubscriptionReportLogLine> logs = <SubscriptionReportLogLine>[];

  bool get bothReported => revenueReported && eventReported;

  bool get wasSkipped =>
      reportingAttempted && !revenueReported && !eventReported && lastSkipReason != null;

  void refreshSandboxFlag() {
    sandboxReportingEnabled = reportSandboxRevenueToFirebase();
    notifyListeners();
  }

  void addLog(String message) {
    final level = _levelForMessage(message);
    logs.insert(
      0,
      SubscriptionReportLogLine(
        timestamp: DateTime.now(),
        message: message,
        level: level,
      ),
    );
    if (logs.length > _maxLogs) {
      logs.removeRange(_maxLogs, logs.length);
    }
    _applyMessageSideEffects(message);
    lastUpdatedAt = DateTime.now();
    notifyListeners();
  }

  void recordVerification({
    required bool isValid,
    required bool? verifiedByApple,
    required String? environment,
    required String productId,
    required String? transactionId,
    required bool willReportRevenue,
    String? skipReason,
    required bool isRestoreFlow,
  }) {
    sandboxReportingEnabled = reportSandboxRevenueToFirebase();
    lastVerificationValid = isValid;
    lastVerifiedByApple = verifiedByApple;
    lastEnvironment = environment;
    lastProductId = productId;
    lastTransactionId = transactionId;
    lastPurchaseStatus = isRestoreFlow ? 'restored' : 'purchased';
    lastSkipReason = willReportRevenue ? null : skipReason;
    lastError = null;
    reportingAttempted = willReportRevenue;
    if (!willReportRevenue) {
      revenueReported = false;
      eventReported = false;
    }
    lastUpdatedAt = DateTime.now();
    notifyListeners();
  }

  void recordRevenueSent({
    required String productId,
    required String transactionId,
    required double value,
    required String currency,
    required String environment,
  }) {
    lastProductId = productId;
    lastTransactionId = transactionId;
    lastRevenueValue = value.toString();
    lastRevenueCurrency = currency;
    lastEnvironment = environment;
    revenueReported = true;
    lastUpdatedAt = DateTime.now();
    notifyListeners();
  }

  void recordEventSent({
    required String productId,
    required String transactionId,
    required String environment,
  }) {
    lastProductId = productId;
    lastTransactionId = transactionId;
    lastEnvironment = environment;
    eventReported = true;
    lastUpdatedAt = DateTime.now();
    notifyListeners();
  }

  void recordSkipped({required String reason}) {
    lastSkipReason = reason;
    revenueReported = false;
    eventReported = false;
    reportingAttempted = true;
    lastUpdatedAt = DateTime.now();
    notifyListeners();
  }

  void recordFailed({required String error}) {
    lastError = error;
    revenueReported = false;
    eventReported = false;
    reportingAttempted = true;
    lastUpdatedAt = DateTime.now();
    notifyListeners();
  }

  void clear() {
    lastVerificationValid = null;
    lastVerifiedByApple = null;
    lastEnvironment = null;
    lastProductId = null;
    lastTransactionId = null;
    lastPurchaseStatus = null;
    lastSkipReason = null;
    lastError = null;
    revenueReported = false;
    eventReported = false;
    reportingAttempted = false;
    lastRevenueValue = null;
    lastRevenueCurrency = null;
    lastUpdatedAt = null;
    logs.clear();
    notifyListeners();
  }

  String buildShareText() {
    final buffer = StringBuffer()
      ..writeln('Firebase IAP Analytics Report')
      ..writeln('Updated: ${lastUpdatedAt ?? "—"}')
      ..writeln('Sandbox reporting: $sandboxReportingEnabled')
      ..writeln('Verification: ${lastVerificationValid ?? "—"}')
      ..writeln('Verified by Apple: ${lastVerifiedByApple ?? "—"}')
      ..writeln('Environment: ${lastEnvironment ?? "—"}')
      ..writeln('Product: ${lastProductId ?? "—"}')
      ..writeln('Transaction: ${lastTransactionId ?? "—"}')
      ..writeln('Revenue reported: $revenueReported')
      ..writeln('Event reported: $eventReported')
      ..writeln('Skip reason: ${lastSkipReason ?? "—"}')
      ..writeln('Error: ${lastError ?? "—"}')
      ..writeln('--- Recent logs ---');
    for (final line in logs.take(30)) {
      buffer.writeln('[${line.timestamp.toIso8601String()}] ${line.message}');
    }
    return buffer.toString();
  }

  SubscriptionReportLogLevel _levelForMessage(String message) {
    if (message.contains('✓✓ DONE') ||
        message.contains('✓ REVENUE SENT') ||
        message.contains('✓ EVENT SENT') ||
        message.contains('SUCCESS')) {
      return SubscriptionReportLogLevel.success;
    }
    if (message.contains('✗ SKIPPED') ||
        message.contains('✗ FAILED') ||
        message.contains('reason=')) {
      return SubscriptionReportLogLevel.warning;
    }
    if (message.contains('failed') || message.contains('exception')) {
      return SubscriptionReportLogLevel.error;
    }
    return SubscriptionReportLogLevel.info;
  }

  void _applyMessageSideEffects(String message) {
    if (message.contains('[FirebaseAnalytics] ✓ REVENUE SENT')) {
      revenueReported = true;
    }
    if (message.contains('[FirebaseAnalytics] ✓ EVENT SENT')) {
      eventReported = true;
    }
    if (message.contains('[FirebaseAnalytics] ✗ SKIPPED')) {
      final match = RegExp(r'reason=([^\s]+)').firstMatch(message);
      lastSkipReason = match?.group(1) ?? lastSkipReason;
      revenueReported = false;
      eventReported = false;
    }
    if (message.contains('[FirebaseAnalytics] ✗ FAILED')) {
      lastError = message;
      revenueReported = false;
      eventReported = false;
    }
  }
}
