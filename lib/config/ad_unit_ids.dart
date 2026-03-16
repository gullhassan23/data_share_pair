/// AdMob ad unit IDs and test/production switch.
/// Set _useTestAds = false and replace production IDs before release.
/// Set kForceFreeUserForAdTesting = false before production.
class AdUnitIds {
  AdUnitIds._();

  static const bool _useTestAds = false;

  /// TEST ONLY: when true, ads show even if user is premium. Set false for production.
  static const bool kForceFreeUserForAdTesting = false;

  // --- Test ad unit IDs (Google sample IDs, safe for development) ---
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testAppOpen = 'ca-app-pub-3940256099942544/9257395921';
  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  // --- Production AdMob unit IDs (live) ---
  // Values are taken from .env when present, otherwise fall back to the
  // hardcoded IDs below.
  static const String _prodBanner = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-3605518487927639/7994484868',
  );
  static const String _prodMrec = String.fromEnvironment(
    'ADMOB_MREC_ID',
    defaultValue: 'ca-app-pub-3605518487927639/8844532105',
  );
  static const String _prodInterstitial = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
    defaultValue: 'ca-app-pub-3605518487927639/3905866931',
  );
  static const String _prodAppOpen = String.fromEnvironment(
    'ADMOB_APPOPEN_ID',
    defaultValue: 'ca-app-pub-3605518487927639/1279703593',
  );
  static const String _prodRewarded = String.fromEnvironment(
    'ADMOB_REWARDED_ID',
    defaultValue: 'ca-app-pub-3605518487927639/9251726211',
  );

  static String get bannerAdUnitId => _useTestAds ? _testBanner : _prodBanner;
  static String get mrecAdUnitId => _useTestAds ? _testBanner : _prodMrec;
  static String get interstitialAdUnitId => _useTestAds ? _testInterstitial : _prodInterstitial;
  static String get appOpenAdUnitId => _useTestAds ? _testAppOpen : _prodAppOpen;
  static String get rewardedAdUnitId => _useTestAds ? _testRewarded : _prodRewarded;
}
