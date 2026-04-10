import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_app_latest/config/ad_unit_ids.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/services/subscription_iap_service.dart';

/// Central AdMob lifecycle: App Open, Banner, Interstitial.
/// Premium users (SubscriptionIAPService().isPremium) see no ads unless
/// [AdUnitIds.kForceFreeUserForAdTesting] is true.
class AdMobService {
  AdMobService._();

  static final AdMobService instance = AdMobService._();
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    await _logAdEvent(name: 'admob_sdk_initialized', adType: 'sdk');
    debugPrint('[AdMob] SDK initialized');
  }

  static Future<void> _logAdEvent({
    required String name,
    required String adType,
    String? status,
    String? errorMessage,
  }) async {
    try {
      final params = <String, Object>{
        'ad_platform': 'admob',
        'ad_type': adType,
      };
      if (status != null) params['status'] = status;
      if (errorMessage != null) params['error_message'] = errorMessage;
      await _analytics.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  bool _getIsPremium() {
    if (AdUnitIds.kForceFreeUserForAdTesting) return false;
    if (Get.isRegistered<PremiumController>()) {
      return Get.find<PremiumController>().isPremium;
    }
    return SubscriptionIAPService().isPremium;
  }

  // ---------- App Open ----------
  AppOpenAd? _appOpenAd;
  bool _isLoadingAppOpen = false;
  DateTime? _lastAppOpenShownAt;
  static const Duration _appOpenMinInterval = Duration(seconds: 45);

  Future<void> loadAppOpenAd({bool? isPremium}) async {
    final shouldShow = isPremium ?? _getIsPremium();
    if (shouldShow) return;
    if (_isLoadingAppOpen || _appOpenAd != null) return;
    _isLoadingAppOpen = true;
    await AppOpenAd.load(
      adUnitId: AdUnitIds.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isLoadingAppOpen = false;
          _logAdEvent(
            name: 'admob_app_open_loaded',
            adType: 'app_open',
            status: 'loaded',
          );
          debugPrint('[AdMob] App Open ad loaded');
        },
        onAdFailedToLoad: (error) {
          _isLoadingAppOpen = false;
          _logAdEvent(
            name: 'admob_app_open_failed_load',
            adType: 'app_open',
            status: 'load_failed',
            errorMessage: error.message,
          );
          debugPrint('[AdMob] App Open failed to load: ${error.message}');
        },
      ),
    );
  }

  Future<void> showAppOpenIfAvailable({
    bool? isPremium,
    Duration minInterval = _appOpenMinInterval,
  }) async {
    final shouldShow = isPremium ?? _getIsPremium();
    if (shouldShow) return;
    if (_appOpenAd == null) {
      loadAppOpenAd(isPremium: false);
      return;
    }
    if (_lastAppOpenShownAt != null &&
        DateTime.now().difference(_lastAppOpenShownAt!) < minInterval) {
      return;
    }
    _logAdEvent(
      name: 'admob_app_open_show_requested',
      adType: 'app_open',
      status: 'show_requested',
    );
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _logAdEvent(
          name: 'admob_app_open_shown',
          adType: 'app_open',
          status: 'shown',
        );
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _lastAppOpenShownAt = DateTime.now();
        _logAdEvent(
          name: 'admob_app_open_dismissed',
          adType: 'app_open',
          status: 'dismissed',
        );
        loadAppOpenAd(isPremium: false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
        _logAdEvent(
          name: 'admob_app_open_failed_show',
          adType: 'app_open',
          status: 'show_failed',
          errorMessage: error.message,
        );
        loadAppOpenAd(isPremium: false);
      },
    );
    await _appOpenAd!.show();
  }

  // ---------- Interstitial ----------
  InterstitialAd? _interstitialAd;
  bool _isLoadingInterstitial = false;
  bool _pendingShowInterstitial = false;

  Future<void> loadInterstitial({bool? isPremium}) async {
    final shouldShow = isPremium ?? _getIsPremium();
    if (shouldShow) return;
    if (_isLoadingInterstitial || _interstitialAd != null) return;
    _isLoadingInterstitial = true;
    await InterstitialAd.load(
      adUnitId: AdUnitIds.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
          _logAdEvent(
            name: 'admob_interstitial_loaded',
            adType: 'interstitial',
            status: 'loaded',
          );
          debugPrint('[AdMob] Interstitial loaded');
          if (_pendingShowInterstitial) {
            _pendingShowInterstitial = false;
            showInterstitial(isPremium: false);
          }
        },
        onAdFailedToLoad: (error) {
          _isLoadingInterstitial = false;
          _pendingShowInterstitial = false;
          _logAdEvent(
            name: 'admob_interstitial_failed_load',
            adType: 'interstitial',
            status: 'load_failed',
            errorMessage: error.message,
          );
          debugPrint('[AdMob] Interstitial failed to load: ${error.message}');
        },
      ),
    );
  }

  void maybePreloadInterstitial([bool? isPremium]) {
    final shouldShow = isPremium ?? _getIsPremium();
    if (shouldShow) return;
    if (_interstitialAd == null && !_isLoadingInterstitial) {
      loadInterstitial(isPremium: false);
    }
  }

  Future<void> showInterstitial({bool? isPremium}) async {
    final shouldShow = isPremium ?? _getIsPremium();
    if (shouldShow) return;
    _logAdEvent(
      name: 'admob_interstitial_show_requested',
      adType: 'interstitial',
      status: 'show_requested',
    );
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          _logAdEvent(
            name: 'admob_interstitial_shown',
            adType: 'interstitial',
            status: 'shown',
          );
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          _logAdEvent(
            name: 'admob_interstitial_dismissed',
            adType: 'interstitial',
            status: 'dismissed',
          );
          loadInterstitial(isPremium: false);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          _logAdEvent(
            name: 'admob_interstitial_failed_show',
            adType: 'interstitial',
            status: 'show_failed',
            errorMessage: error.message,
          );
          loadInterstitial(isPremium: false);
        },
      );
      await _interstitialAd!.show();
      return;
    }
    _pendingShowInterstitial = true;
    loadInterstitial(isPremium: false);
  }

  // ---------- Banner ----------
  BannerAd? createBannerAd() {
    if (_getIsPremium()) return null;
    _logAdEvent(
      name: 'admob_banner_requested',
      adType: 'banner',
      status: 'requested',
    );
    final ad = BannerAd(
      adUnitId: AdUnitIds.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _logAdEvent(
            name: 'admob_banner_loaded',
            adType: 'banner',
            status: 'loaded',
          );
          debugPrint('[AdMob] Banner loaded');
        },
        onAdFailedToLoad: (_, e) {
          _logAdEvent(
            name: 'admob_banner_failed_load',
            adType: 'banner',
            status: 'load_failed',
            errorMessage: e.message,
          );
          debugPrint('[AdMob] Banner failed: ${e.message}');
        },
      ),
    );
    ad.load();
    return ad;
  }
}
