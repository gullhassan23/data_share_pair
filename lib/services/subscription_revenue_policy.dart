import 'package:flutter/foundation.dart';

/// Whether a verified subscription should be logged as Firebase purchase revenue.
///
/// iOS: only [production] subscriptions count (sandbox / TestFlight must not
/// inflate Analytics revenue).
///
/// Android: backend uses Apple verify and always returns sandbox for Play tokens,
/// so release-build purchases are reported to match Adapty / Play production revenue.
bool shouldReportSubscriptionRevenue(
  String? environment, {
  bool isAndroid = false,
  bool isReleaseBuild = kReleaseMode,
}) {
  if (isAndroid) {
    return isReleaseBuild;
  }
  return environment == 'production';
}
