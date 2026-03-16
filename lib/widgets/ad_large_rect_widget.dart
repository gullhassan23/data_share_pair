import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_app_latest/config/ad_unit_ids.dart';
import 'package:share_app_latest/services/subscription_iap_service.dart';

/// Larger display ad (medium rectangle 300x250) for big empty areas, e.g. home screen.
/// Hidden for premium users; uses the same banner ad unit ID.
class AdLargeRectWidget extends StatefulWidget {
  const AdLargeRectWidget({super.key});

  @override
  State<AdLargeRectWidget> createState() => _AdLargeRectWidgetState();
}

class _AdLargeRectWidgetState extends State<AdLargeRectWidget> {
  BannerAd? _ad;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _isPremium = AdUnitIds.kForceFreeUserForAdTesting
        ? false
        : SubscriptionIAPService().isPremium;
    if (!_isPremium) {
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
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPremium || _ad == null) {
      return const SizedBox.shrink();
    }
    return Center(
      child: SizedBox(
        width: _ad!.size.width.toDouble(),
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}

