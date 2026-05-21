import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Firebase Remote Config for ad timing on Android free tier ([keyAdsControlTime]).
/// iOS ignores these values at call sites even after fetch.
///
/// Firebase Console → Remote Config: add Number parameter **adsControlTime**
/// (seconds between ad cycles / interstitial period). Typical range clamped **15–600**.
class AdsRemoteConfigService {
  AdsRemoteConfigService._();

  static final AdsRemoteConfigService instance = AdsRemoteConfigService._();

  static const String keyAdsControlTime = 'adsControlTime';
  static const int defaultAdsControlSeconds = 30;
  static const int minAdsControlSeconds = 15;
  static const int maxAdsControlSeconds = 600;

  /// Fires when [adsControlSeconds] changes after fetch/activate (Android widgets
  /// restart refresh timers).
  static final ValueNotifier<int> adsControlSecondsNotifier =
      ValueNotifier<int>(defaultAdsControlSeconds);

  FirebaseRemoteConfig? _rc;
  int _adsControlSeconds = defaultAdsControlSeconds;

  int get adsControlSeconds => _adsControlSeconds;

  Duration get adsControlDuration => Duration(seconds: _adsControlSeconds);

  static const Duration _networkFetchTimeout = Duration(seconds: 15);

  bool _localConfigReady = false;

  /// Applies defaults / last-activated values immediately (no network).
  /// Network fetch runs in the background via [refresh].
  Future<void> init() async {
    if (_localConfigReady) return;
    try {
      _rc = FirebaseRemoteConfig.instance;
      await _rc!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: _networkFetchTimeout,
          minimumFetchInterval: kDebugMode
              ? const Duration(minutes: 1)
              : const Duration(minutes: 15),
        ),
      );
      await _rc!.setDefaults(<String, dynamic>{
        keyAdsControlTime: defaultAdsControlSeconds,
      });
      _applyLoadedValues();
      _localConfigReady = true;
    } catch (e, st) {
      debugPrint('[AdsRemoteConfig] init failed: $e\n$st');
      _adsControlSeconds = defaultAdsControlSeconds;
      adsControlSecondsNotifier.value = _adsControlSeconds;
    }
  }

  void _applyLoadedValues() {
    if (_rc == null) return;
    var v = _rc!.getInt(keyAdsControlTime);
    if (v <= 0) v = defaultAdsControlSeconds;
    if (v < minAdsControlSeconds) v = minAdsControlSeconds;
    if (v > maxAdsControlSeconds) v = maxAdsControlSeconds;
    final previous = _adsControlSeconds;
    _adsControlSeconds = v;
    if (previous != _adsControlSeconds) {
      adsControlSecondsNotifier.value = _adsControlSeconds;
    }
    debugPrint('[AdsRemoteConfig] $keyAdsControlTime=$_adsControlSeconds');
  }

  /// Fetches latest template from Firebase and activates it. Call on app resume
  /// so changes to **adsControlTime** take effect without reinstalling the app.
  /// Returns whether the resolved seconds value changed.
  Future<bool> refresh() async {
    if (_rc == null) return false;
    try {
      final before = _adsControlSeconds;
      await _rc!.fetchAndActivate();
      _applyLoadedValues();
      return before != _adsControlSeconds;
    } catch (e) {
      debugPrint('[AdsRemoteConfig] refresh failed: $e');
      return false;
    }
  }
}
