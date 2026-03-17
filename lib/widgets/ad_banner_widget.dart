import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_app_latest/config/ad_unit_ids.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/services/admob_service.dart';
import 'package:share_app_latest/services/subscription_iap_service.dart';

/// Banner ad at bottom of main screens. Hidden for premium users (widget kept to avoid
/// platform view recreate issues on iOS). Uses stable key for platform view.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  bool _isPremiumNow() {
    if (AdUnitIds.kForceFreeUserForAdTesting) return false;
    final fromIap = SubscriptionIAPService().isPremium;
    final fromController = Get.isRegistered<PremiumController>()
        ? Get.find<PremiumController>().isPremium
        : false;
    return fromIap || fromController;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final premium = _isPremiumNow();
      if (premium) {
        _bannerAd?.dispose();
        _bannerAd = null;
        return const SizedBox.shrink();
      }

      _bannerAd ??= AdMobService.instance.createBannerAd();
      final ad = _bannerAd;
      if (ad == null || ad.size.height <= 0) return const SizedBox.shrink();

      return Container(
        key: const ValueKey<String>('admob_banner'),
        alignment: Alignment.center,
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      );
    });
  }
}
