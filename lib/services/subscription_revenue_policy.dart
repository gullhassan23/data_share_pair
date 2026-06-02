/// Whether a verified subscription should be logged as Firebase purchase revenue.
///
/// Only [production] subscriptions count toward revenue. Sandbox / StoreKit test
/// purchases still grant premium in the app but must not inflate Analytics revenue.
bool shouldReportSubscriptionRevenue(String? environment) {
  return environment == 'production';
}
