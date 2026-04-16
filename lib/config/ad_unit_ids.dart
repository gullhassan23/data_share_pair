import 'package:flutter/foundation.dart';

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

  // --- Production AdMob unit IDs (live) ---
  // Values are taken from dart-defines/.env when present.
  // Legacy single-key vars are still supported as fallback.
  static const String _prodBannerLegacy = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: '',
  );
  static const String _prodBannerIos = String.fromEnvironment(
    'ADMOB_BANNER_ID_IOS',
    defaultValue: 'ca-app-pub-3605518487927639/7994484868',
  );
  static const String _prodBannerAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ID_ANDROID',
    defaultValue: 'ca-app-pub-3605518487927639/1635198254',
  );

  static const String _prodMrecLegacy = String.fromEnvironment(
    'ADMOB_MREC_ID',
    defaultValue: '',
  );
  static const String _prodMrecIos = String.fromEnvironment(
    'ADMOB_MREC_ID_IOS',
    defaultValue: 'ca-app-pub-3605518487927639/8844532105',
  );
  static const String _prodMrecAndroid = String.fromEnvironment(
    'ADMOB_MREC_ID_ANDROID',
    defaultValue: 'ca-app-pub-3605518487927639/7930203356',
  );

  static const String _prodInterstitialLegacy = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
    defaultValue: '',
  );
  static const String _prodInterstitialIos = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID_IOS',
    defaultValue: 'ca-app-pub-3605518487927639/3905866931',
  );
  static const String _prodInterstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID_ANDROID',
    defaultValue: 'ca-app-pub-3605518487927639/9322116582',
  );

  static const String _prodAppOpenLegacy = String.fromEnvironment(
    'ADMOB_APPOPEN_ID',
    defaultValue: '',
  );
  static const String _prodAppOpenIos = String.fromEnvironment(
    'ADMOB_APPOPEN_ID_IOS',
    defaultValue: 'ca-app-pub-3605518487927639/1279703593',
  );
  static const String _prodAppOpenAndroid = String.fromEnvironment(
    'ADMOB_APPOPEN_ID_ANDROID',
    defaultValue: 'ca-app-pub-3605518487927639/1691038571',
  );

  static String _platformValue({
    required String ios,
    required String android,
    required String legacy,
  }) {
    if (legacy.isNotEmpty) return legacy;
    if (kIsWeb) return ios;
    return defaultTargetPlatform == TargetPlatform.android ? android : ios;
  }

  static String get bannerAdUnitId => _useTestAds
      ? _testBanner
      : _platformValue(
          ios: _prodBannerIos,
          android: _prodBannerAndroid,
          legacy: _prodBannerLegacy,
        );

  static String get mrecAdUnitId => _useTestAds
      ? _testBanner
      : _platformValue(
          ios: _prodMrecIos,
          android: _prodMrecAndroid,
          legacy: _prodMrecLegacy,
        );

  static String get interstitialAdUnitId => _useTestAds
      ? _testInterstitial
      : _platformValue(
          ios: _prodInterstitialIos,
          android: _prodInterstitialAndroid,
          legacy: _prodInterstitialLegacy,
        );

  static String get appOpenAdUnitId => _useTestAds
      ? _testAppOpen
      : _platformValue(
          ios: _prodAppOpenIos,
          android: _prodAppOpenAndroid,
          legacy: _prodAppOpenLegacy,
        );
}
