import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_app_latest/config/ad_unit_ids.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/services/ads_remote_config_service.dart';

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
        if (!mounted || _isPremiumNow()) return;
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

  bool _isPremiumNow() {
    if (AdUnitIds.kForceFreeUserForAdTesting) return false;
    final fromController = Get.isRegistered<PremiumController>()
        ? Get.find<PremiumController>().isPremium
        : false;
    return fromController;
  }

  void _ensureAdLoaded() {
    if (_ad != null) return;
    _ad = BannerAd(
      adUnitId: AdUnitIds.mrecAdUnitId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {},
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final premium = _isPremiumNow();
      if (premium) {
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

