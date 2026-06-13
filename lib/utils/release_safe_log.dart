import 'package:share_app_latest/services/subscription_analytics_report_store.dart';

/// IAP / Firebase revenue logs — always visible in debug and release builds.
///
/// Also feeds [SubscriptionAnalyticsReportStore] for the in-app QA report screen.
void iapDebugLog(String message) {
  // ignore: avoid_print
  print(message);
  SubscriptionAnalyticsReportStore.instance.addLog(message);
}
