import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/config/ad_unit_ids.dart';
import 'package:share_app_latest/services/admob_service.dart';
import 'package:share_app_latest/services/ads_remote_config_service.dart';
import 'package:share_app_latest/services/subscription_iap_service.dart';
import 'package:share_app_latest/utils/ads_visibility.dart';

/// Debug-only helpers: startup report, diagnostic test loads, adapter snapshot.
class AdMobDebugService {
  AdMobDebugService._();

  static void log(String message) {
    debugPrint('[AdMob] $message');
  }

  /// Call once after SDK init to print a full snapshot (debug builds).
  static void logStartupReport() {
    if (!kDebugMode) return;
    for (final line in buildReportLines()) {
      log(line);
    }
  }

  static List<String> buildReportLines() {
    final lines = <String>[
      '════════ AdMob diagnostic ════════',
      AdsVisibility.blockReason,
      'ADMOB_TEST_MODE=${AdUnitIds.useTestAds}',
      'Platform=${defaultTargetPlatform.name}',
      '.env loaded=${dotenv.isInitialized}',
      '— Ad unit IDs (resolved) —',
      '  banner: ${AdUnitIds.describeAdUnitId(AdUnitIds.bannerAdUnitId)}',
      '  mrec: ${AdUnitIds.describeAdUnitId(AdUnitIds.mrecAdUnitId)}',
      '  interstitial: ${AdUnitIds.describeAdUnitId(AdUnitIds.interstitialAdUnitId)}',
      '  app_open: ${AdUnitIds.describeAdUnitId(AdUnitIds.appOpenAdUnitId)}',
      '  rewarded: ${AdUnitIds.describeAdUnitId(AdUnitIds.rewardedAdUnitId)}',
      '— In-memory ad state —',
      ...AdMobService.instance.debugStateLines(),
      '— Remote config (Android ad timing) —',
      '  adsControlTime=${AdsRemoteConfigService.instance.adsControlSeconds}s',
      '— Mediation adapters (last init) —',
    ];

    final adapters = AdMobService.lastInitAdapterStatuses;
    if (adapters == null || adapters.isEmpty) {
      lines.add('  (none — run app after MobileAds.initialize)');
    } else {
      adapters.forEach((name, status) {
        lines.add('  $name: ${status.description} (${status.state.name})');
      });
    }

    lines.add('══════════════════════════════════');
    return lines;
  }

  /// Loads Google’s sample banner to verify SDK + network (not your unit IDs).
  static Future<String> runGoogleTestBannerLoad() async {
    return _runBannerLoad(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      label: 'Google TEST banner',
    );
  }

  /// Loads your configured banner unit (production or test per .env).
  static Future<String> runConfiguredBannerLoad() async {
    final id = AdUnitIds.bannerAdUnitId;
    if (!AdUnitIds.isValidAdUnitId(id)) {
      return 'SKIP: banner unit ID invalid/empty → fix .env (ADMOB_BANNER_ID_*)';
    }
    return _runBannerLoad(adUnitId: id, label: 'Configured banner');
  }

  /// Loads your configured MREC unit.
  static Future<String> runConfiguredMrecLoad() async {
    final id = AdUnitIds.mrecAdUnitId;
    if (!AdUnitIds.isValidAdUnitId(id)) {
      return 'SKIP: MREC unit ID invalid/empty → fix .env (ADMOB_MREC_ID_*)';
    }
    return _runBannerLoad(
      adUnitId: id,
      label: 'Configured MREC',
      size: AdSize.mediumRectangle,
    );
  }

  static Future<String> runConfiguredInterstitialLoad() async {
    final id = AdUnitIds.interstitialAdUnitId;
    if (!AdUnitIds.isValidAdUnitId(id)) {
      return 'SKIP: interstitial unit ID invalid/empty → fix .env';
    }
    if (AdsVisibility.shouldHideAds) {
      return 'SKIP: ${AdsVisibility.blockReason}';
    }

    final completer = Completer<String>();
    await InterstitialAd.load(
      adUnitId: id,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          final adapter = ad.responseInfo?.mediationAdapterClassName ?? 'AdMob';
          ad.dispose();
          completer.complete('OK: interstitial loaded (adapter: $adapter)');
        },
        onAdFailedToLoad: (e) {
          completer.complete(
            'FAIL: interstitial code=${e.code} domain=${e.domain} '
            '${e.message}',
          );
        },
      ),
    );
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => 'FAIL: interstitial load timed out (30s)',
    );
  }

  static Future<String> _runBannerLoad({
    required String adUnitId,
    required String label,
    AdSize size = AdSize.banner,
  }) async {
    if (AdsVisibility.shouldHideAds) {
      return 'SKIP: ${AdsVisibility.blockReason}';
    }

    final completer = Completer<String>();
    BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          final adapter = ad.responseInfo?.mediationAdapterClassName ?? 'AdMob';
          ad.dispose();
          if (!completer.isCompleted) {
            completer.complete('OK: $label loaded (adapter: $adapter)');
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!completer.isCompleted) {
            completer.complete(
              'FAIL: $label code=${error.code} domain=${error.domain} '
              '${error.message}',
            );
          }
        },
      ),
    ).load();

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => 'FAIL: $label timed out (30s)',
    );
  }

  /// Clears cached premium so ads can show during QA (debug only).
  static Future<void> clearPremiumCacheForTesting() async {
    SubscriptionIAPService().setCachedPremium(false);
    if (Get.isRegistered<PremiumController>()) {
      Get.find<PremiumController>().subscriptionStatus.value =
          const SubscriptionStatus(isPremium: false);
    }
    log('Premium cache cleared for ad testing (Firestore may override on sync)');
  }
}
