/// AdMob ad unit IDs and test/production switch.
/// Set _useTestAds = false and replace production IDs before release.
/// Set kForceFreeUserForAdTesting = false before production.
class AdUnitIds {
  AdUnitIds._();

  static const bool _useTestAds = true;

  /// TEST ONLY: when true, ads show even if user is premium. Set false for production.
  static const bool kForceFreeUserForAdTesting = false;

  // --- Test ad unit IDs (Google sample IDs, safe for development) ---
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testAppOpen = 'ca-app-pub-3940256099942544/9257395921';
  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  // --- Production placeholders (replace with your real AdMob unit IDs) ---
  static const String _prodBanner = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodInterstitial = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodAppOpen = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodRewarded = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  static String get bannerAdUnitId => _useTestAds ? _testBanner : _prodBanner;
  static String get interstitialAdUnitId => _useTestAds ? _testInterstitial : _prodInterstitial;
  static String get appOpenAdUnitId => _useTestAds ? _testAppOpen : _prodAppOpen;
  static String get rewardedAdUnitId => _useTestAds ? _testRewarded : _prodRewarded;
}
