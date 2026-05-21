import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_app_latest/config/ad_unit_ids.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/services/ads_remote_config_service.dart';
import 'package:share_app_latest/services/subscription_iap_service.dart';

/// Central AdMob lifecycle: App Open, Banner, Interstitial.
/// Premium users (SubscriptionIAPService().isPremium) see no ads unless
/// [AdUnitIds.kForceFreeUserForAdTesting] is true.
class AdMobService {
  AdMobService._();

  static final AdMobService instance = AdMobService._();
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> initialize() async {
    final initStatus = await MobileAds.instance.initialize();
    if (kDebugMode) {
      initStatus.adapterStatuses.forEach((adapter, status) {
        debugPrint(
          '[AdMob] Mediation adapter $adapter: ${status.description} '
          '(latency ${status.latency}ms)',
        );
      });
    }
    await _logAdEvent(name: 'admob_sdk_initialized', adType: 'sdk');
    debugPrint('[AdMob] SDK initialized with mediation adapters');
  }

  static void _logMediationAdapter(String adType, Ad ad) {
    final adapter = ad.responseInfo?.mediationAdapterClassName;
    if (adapter == null || adapter.isEmpty) return;
    debugPrint('[AdMob] $adType served by mediation adapter: $adapter');
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

  bool get _androidFreeAdThrottleEnabled =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Duration get _effectiveAppOpenMinInterval => _androidFreeAdThrottleEnabled
      ? AdsRemoteConfigService.instance.adsControlDuration
      : _appOpenMinInterval;

  // ---------- App Open ----------
  AppOpenAd? _appOpenAd;
  bool _isLoadingAppOpen = false;
  bool _pendingShowAppOpen = false;
  bool _hasShownAppOpenThisLaunch = false;
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
          _logMediationAdapter('app_open', ad);
          _logAdEvent(
            name: 'admob_app_open_loaded',
            adType: 'app_open',
            status: 'loaded',
          );
          debugPrint('[AdMob] App Open ad loaded');
          if (_pendingShowAppOpen) {
            _pendingShowAppOpen = false;
            showAppOpenIfAvailable(isPremium: false);
          }
        },
        onAdFailedToLoad: (error) {
          _isLoadingAppOpen = false;
          _pendingShowAppOpen = false;
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
    Duration? minInterval,
  }) async {
    final shouldShow = isPremium ?? _getIsPremium();
    if (shouldShow) return;
    if (_hasShownAppOpenThisLaunch) return;
    final resolvedInterval = minInterval ?? _effectiveAppOpenMinInterval;
    if (_appOpenAd == null) {
      _pendingShowAppOpen = true;
      loadAppOpenAd(isPremium: false);
      return;
    }
    if (_lastAppOpenShownAt != null &&
        DateTime.now().difference(_lastAppOpenShownAt!) < resolvedInterval) {
      return;
    }
    _logAdEvent(
      name: 'admob_app_open_show_requested',
      adType: 'app_open',
      status: 'show_requested',
    );
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _hasShownAppOpenThisLaunch = true;
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
      },
    );
    await _appOpenAd!.show();
  }

  // ---------- Interstitial ----------
  InterstitialAd? _interstitialAd;
  bool _isLoadingInterstitial = false;
  bool _pendingShowInterstitial = false;
  bool _pendingShowInterstitialSkipAndroidMinGap = false;
  bool _interstitialIsShowing = false;
  DateTime? _lastInterstitialClosedAt;
  Timer? _androidPeriodicInterstitialTimer;
  bool _isPremiumSyncBound = false;

  /// Android free tier: show an interstitial every [AdsRemoteConfigService.adsControlDuration]
  /// (default 30s) while the app is in the foreground. No-op on iOS / web / premium.
  void activateAndroidPeriodicInterstitialsWhileForeground() {
    if (!_androidFreeAdThrottleEnabled) return;
    if (_getIsPremium()) {
      deactivateAndroidPeriodicInterstitials();
      return;
    }
    _androidPeriodicInterstitialTimer?.cancel();
    final interval = AdsRemoteConfigService.instance.adsControlDuration;
    _androidPeriodicInterstitialTimer = Timer.periodic(interval, (_) {
      if (_getIsPremium()) {
        deactivateAndroidPeriodicInterstitials();
        return;
      }
      unawaited(
        showInterstitial(
          isPremium: false,
          skipAndroidMinGap: true,
        ),
      );
    });
  }

  void deactivateAndroidPeriodicInterstitials() {
    _androidPeriodicInterstitialTimer?.cancel();
    _androidPeriodicInterstitialTimer = null;
  }

  /// Keeps Android periodic interstitial timer in sync with runtime premium
  /// flips (e.g. cached true on launch, later Firestore says free).
  void bindPremiumSyncForAndroidInterstitials() {
    if (_isPremiumSyncBound) return;
    _isPremiumSyncBound = true;
    SubscriptionIAPService().premiumListenable.addListener(() {
      if (!_androidFreeAdThrottleEnabled) return;
      if (_getIsPremium()) {
        deactivateAndroidPeriodicInterstitials();
      } else {
        activateAndroidPeriodicInterstitialsWhileForeground();
      }
    });
  }

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
          _logMediationAdapter('interstitial', ad);
          _logAdEvent(
            name: 'admob_interstitial_loaded',
            adType: 'interstitial',
            status: 'loaded',
          );
          debugPrint('[AdMob] Interstitial loaded');
          if (_pendingShowInterstitial) {
            final skipGap = _pendingShowInterstitialSkipAndroidMinGap;
            _pendingShowInterstitial = false;
            _pendingShowInterstitialSkipAndroidMinGap = false;
            showInterstitial(isPremium: false, skipAndroidMinGap: skipGap);
          }
        },
        onAdFailedToLoad: (error) {
          _isLoadingInterstitial = false;
          _pendingShowInterstitial = false;
          _pendingShowInterstitialSkipAndroidMinGap = false;
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

  Future<void> showInterstitial({
    bool? isPremium,
    bool skipAndroidMinGap = false,
  }) async {
    final shouldShow = isPremium ?? _getIsPremium();
    if (shouldShow) return;
    if (_interstitialIsShowing) return;
    if (_androidFreeAdThrottleEnabled && !skipAndroidMinGap) {
      final last = _lastInterstitialClosedAt;
      if (last != null &&
          DateTime.now().difference(last) <
              AdsRemoteConfigService.instance.adsControlDuration) {
        return;
      }
    }
    _logAdEvent(
      name: 'admob_interstitial_show_requested',
      adType: 'interstitial',
      status: 'show_requested',
    );
    if (_interstitialAd != null) {
      _interstitialIsShowing = true;
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          _logAdEvent(
            name: 'admob_interstitial_shown',
            adType: 'interstitial',
            status: 'shown',
          );
        },
        onAdDismissedFullScreenContent: (ad) {
          _interstitialIsShowing = false;
          _lastInterstitialClosedAt = DateTime.now();
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
          _interstitialIsShowing = false;
          _lastInterstitialClosedAt = DateTime.now();
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
      try {
        await _interstitialAd!.show();
      } catch (_) {
        _interstitialIsShowing = false;
      }
      return;
    }
    _pendingShowInterstitial = true;
    _pendingShowInterstitialSkipAndroidMinGap = skipAndroidMinGap;
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
        onAdLoaded: (ad) {
          _logMediationAdapter('banner', ad);
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

  // ---------- Rewarded ----------
  Future<bool> showRewardedAdForSendUnlock({bool? isPremium}) async {
    final shouldShow = isPremium ?? _getIsPremium();
    if (shouldShow) return true;

    final ad = await _loadRewardedAd();
    if (ad == null) return false;

    bool earnedReward = false;
    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _logAdEvent(
          name: 'admob_rewarded_shown',
          adType: 'rewarded',
          status: 'shown',
        );
      },
      onAdDismissedFullScreenContent: (dismissedAd) {
        dismissedAd.dispose();
        if (!completer.isCompleted) {
          completer.complete(earnedReward);
        }
        _logAdEvent(
          name: 'admob_rewarded_dismissed',
          adType: 'rewarded',
          status: earnedReward ? 'reward_earned' : 'dismissed',
        );
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        failedAd.dispose();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        _logAdEvent(
          name: 'admob_rewarded_failed_show',
          adType: 'rewarded',
          status: 'show_failed',
          errorMessage: error.message,
        );
      },
    );

    ad.show(
      onUserEarnedReward: (_, __) {
        earnedReward = true;
        _logAdEvent(
          name: 'admob_rewarded_earned',
          adType: 'rewarded',
          status: 'earned',
        );
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => false,
    );
  }

  Future<RewardedAd?> _loadRewardedAd() async {
    final completer = Completer<RewardedAd?>();
    _logAdEvent(
      name: 'admob_rewarded_show_requested',
      adType: 'rewarded',
      status: 'show_requested',
    );
    await RewardedAd.load(
      adUnitId: AdUnitIds.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _logMediationAdapter('rewarded', ad);
          _logAdEvent(
            name: 'admob_rewarded_loaded',
            adType: 'rewarded',
            status: 'loaded',
          );
          completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          _logAdEvent(
            name: 'admob_rewarded_failed_load',
            adType: 'rewarded',
            status: 'load_failed',
            errorMessage: error.message,
          );
          completer.complete(null);
        },
      ),
    );
    return completer.future;
  }
}
