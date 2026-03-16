import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_app_latest/config/ad_unit_ids.dart';
import 'package:share_app_latest/services/subscription_iap_service.dart';

/// Central AdMob lifecycle: App Open, Banner, Interstitial, Rewarded.
/// Premium users (SubscriptionIAPService().isPremium) see no ads unless
/// [AdUnitIds.kForceFreeUserForAdTesting] is true.
class AdMobService {
  AdMobService._();

  static final AdMobService instance = AdMobService._();

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    debugPrint('[AdMob] SDK initialized');
  }

  bool _getIsPremium() {
    if (AdUnitIds.kForceFreeUserForAdTesting) return false;
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
          debugPrint('[AdMob] App Open ad loaded');
        },
        onAdFailedToLoad: (error) {
          _isLoadingAppOpen = false;
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
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _lastAppOpenShownAt = DateTime.now();
        loadAppOpenAd(isPremium: false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
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
          debugPrint('[AdMob] Interstitial loaded');
          if (_pendingShowInterstitial) {
            _pendingShowInterstitial = false;
            showInterstitial(isPremium: false);
          }
        },
        onAdFailedToLoad: (error) {
          _isLoadingInterstitial = false;
          _pendingShowInterstitial = false;
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
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          loadInterstitial(isPremium: false);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          loadInterstitial(isPremium: false);
        },
      );
      await _interstitialAd!.show();
      return;
    }
    _pendingShowInterstitial = true;
    loadInterstitial(isPremium: false);
  }

  // ---------- Rewarded ----------
  RewardedAd? _rewardedAd;
  bool _isLoadingRewarded = false;

  Future<void> loadRewarded({bool? isPremium}) async {
    final shouldShow = isPremium ?? _getIsPremium();
    if (shouldShow) return;
    if (_isLoadingRewarded || _rewardedAd != null) return;
    _isLoadingRewarded = true;
    await RewardedAd.load(
      adUnitId: AdUnitIds.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingRewarded = false;
          debugPrint('[AdMob] Rewarded ad loaded');
        },
        onAdFailedToLoad: (error) {
          _isLoadingRewarded = false;
          debugPrint('[AdMob] Rewarded failed to load: ${error.message}');
        },
      ),
    );
  }

  /// Shows rewarded ad. [onEarned] is called when user earns the reward.
  /// Returns true if ad was shown (or will be shown after load), false if premium or not available.
  Future<bool> showRewarded({
    bool? isPremium,
    required void Function(AdWithoutView ad, RewardItem item) onEarned,
    VoidCallback? onDismissed,
  }) async {
    final shouldShow = isPremium ?? _getIsPremium();
    if (shouldShow) return false;
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          loadRewarded(isPremium: false);
          onDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _rewardedAd = null;
          loadRewarded(isPremium: false);
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (ad, item) => onEarned(ad, item),
      );
      return true;
    }
    loadRewarded(isPremium: false);
    return false;
  }

  /// Call when entering a screen where you might show rewarded later (e.g. premium page).
  void maybePreloadRewarded([bool? isPremium]) {
    final shouldShow = isPremium ?? _getIsPremium();
    if (shouldShow) return;
    if (_rewardedAd == null && !_isLoadingRewarded) {
      loadRewarded(isPremium: false);
    }
  }

  // ---------- Banner ----------
  BannerAd? createBannerAd() {
    if (_getIsPremium()) return null;
    final ad = BannerAd(
      adUnitId: AdUnitIds.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => debugPrint('[AdMob] Banner loaded'),
        onAdFailedToLoad: (_, e) =>
            debugPrint('[AdMob] Banner failed: ${e.message}'),
      ),
    );
    ad.load();
    return ad;
  }
}
