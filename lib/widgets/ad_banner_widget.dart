import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_app_latest/config/ad_unit_ids.dart';
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
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _isPremium = AdUnitIds.kForceFreeUserForAdTesting
        ? false
        : SubscriptionIAPService().isPremium;
    if (!_isPremium) {
      _bannerAd = AdMobService.instance.createBannerAd();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPremium || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    if (_bannerAd!.size.height <= 0) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const ValueKey<String>('admob_banner'),
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
