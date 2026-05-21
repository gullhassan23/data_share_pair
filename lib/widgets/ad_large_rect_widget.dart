import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_app_latest/config/ad_unit_ids.dart';
import 'package:share_app_latest/services/admob_debug_service.dart';
import 'package:share_app_latest/services/ads_remote_config_service.dart';
import 'package:share_app_latest/utils/ads_visibility.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';

/// Larger display ad (medium rectangle 300x250) for big empty areas, e.g. home screen.
/// Hidden for premium users; uses the same banner ad unit ID.
class AdLargeRectWidget extends StatefulWidget {
  const AdLargeRectWidget({super.key});

  @override
  State<AdLargeRectWidget> createState() => _AdLargeRectWidgetState();
}

class _AdLargeRectWidgetState extends State<AdLargeRectWidget> {
  BannerAd? _ad;
  Timer? _androidRefreshTimer;

  @override
  void initState() {
    super.initState();
    AdsRemoteConfigService.adsControlSecondsNotifier
        .addListener(_restartAndroidMrecRefreshTimer);
    _restartAndroidMrecRefreshTimer();
  }

  void _restartAndroidMrecRefreshTimer() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _androidRefreshTimer?.cancel();
      _androidRefreshTimer = null;
      return;
    }
    if (!mounted) return;
    _androidRefreshTimer?.cancel();
    _androidRefreshTimer = Timer.periodic(
      AdsRemoteConfigService.instance.adsControlDuration,
      (_) {
        if (!mounted || AdsVisibility.shouldHideAds) return;
        setState(() {
          _ad?.dispose();
          _ad = null;
        });
      },
    );
  }

  @override
  void dispose() {
    AdsRemoteConfigService.adsControlSecondsNotifier
        .removeListener(_restartAndroidMrecRefreshTimer);
    _androidRefreshTimer?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  void _ensureAdLoaded() {
    if (_ad != null) return;
    final unitId = AdUnitIds.mrecAdUnitId;
    if (!AdUnitIds.isValidAdUnitId(unitId)) {
      AdMobDebugService.log(
        'AdLargeRectWidget: invalid MREC unit id "$unitId" — check .env ADMOB_MREC_ID_*',
      );
      return;
    }
    AdMobDebugService.log(
      'AdLargeRectWidget loading MREC (${AdUnitIds.describeAdUnitId(unitId)})',
    );
    _ad = BannerAd(
      adUnitId: unitId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          final adapter = ad.responseInfo?.mediationAdapterClassName;
          AdMobDebugService.log(
            'MREC loaded${adapter != null ? " adapter=$adapter" : ""}',
          );
          if (mounted) setState(() {});
        },
        onAdFailedToLoad: (ad, error) {
          AdMobDebugService.log(
            'MREC failed code=${error.code} domain=${error.domain} ${error.message}',
          );
          ad.dispose();
          if (mounted) {
            setState(() => _ad = null);
          }
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (Get.isRegistered<PremiumController>()) {
        Get.find<PremiumController>().subscriptionStatus.value;
      }
      if (AdsVisibility.shouldHideAds) {
        if (kDebugMode) {
          AdMobDebugService.log(
            'AdLargeRectWidget hidden: ${AdsVisibility.blockReason}',
          );
        }
        _ad?.dispose();
        _ad = null;
        return const SizedBox.shrink();
      }

      _ensureAdLoaded();
      final ad = _ad;
      if (ad == null) return const SizedBox.shrink();

      return Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      );
    });
  }
}

