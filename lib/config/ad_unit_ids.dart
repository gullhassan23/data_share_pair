import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  // Values are read from .env at runtime.
  static String _env(String key, {String fallback = ''}) {
    final value = dotenv.env[key]?.trim();
    if (value != null && value.isNotEmpty) return value;
    return fallback;
  }

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
          ios: _env('ADMOB_BANNER_ID_IOS'),
          android: _env('ADMOB_BANNER_ID_ANDROID'),
          legacy: _env('ADMOB_BANNER_ID'),
        );

  static String get mrecAdUnitId => _useTestAds
      ? _testBanner
      : _platformValue(
          ios: _env('ADMOB_MREC_ID_IOS'),
          android: _env('ADMOB_MREC_ID_ANDROID'),
          legacy: _env('ADMOB_MREC_ID'),
        );

  static String get interstitialAdUnitId => _useTestAds
      ? _testInterstitial
      : _platformValue(
          ios: _env('ADMOB_INTERSTITIAL_ID_IOS'),
          android: _env('ADMOB_INTERSTITIAL_ID_ANDROID'),
          legacy: _env('ADMOB_INTERSTITIAL_ID'),
        );

  static String get appOpenAdUnitId => _useTestAds
      ? _testAppOpen
      : _platformValue(
          ios: _env('ADMOB_APPOPEN_ID_IOS'),
          android: _env('ADMOB_APPOPEN_ID_ANDROID'),
          legacy: _env('ADMOB_APPOPEN_ID'),
        );
}
