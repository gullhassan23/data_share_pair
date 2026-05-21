import 'package:get/get.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/config/ad_unit_ids.dart';
import 'package:share_app_latest/services/subscription_iap_service.dart';

/// Single source of truth for whether ads should be hidden (premium / test override).
class AdsVisibility {
  AdsVisibility._();

  /// When true, ad widgets and [AdMobService] must not load or show ads.
  static bool get shouldHideAds {
    if (AdUnitIds.kForceFreeUserForAdTesting) return false;
    if (SubscriptionIAPService().isPremium) return true;
    if (Get.isRegistered<PremiumController>() &&
        Get.find<PremiumController>().isPremium) {
      return true;
    }
    return false;
  }

  /// Human-readable explanation for debug UI and logs.
  static String get blockReason {
    if (AdUnitIds.kForceFreeUserForAdTesting) {
      return 'kForceFreeUserForAdTesting=true → ads forced ON for QA';
    }
    final parts = <String>[];
    parts.add('IAP cache isPremium=${SubscriptionIAPService().isPremium}');
    if (Get.isRegistered<PremiumController>()) {
      final c = Get.find<PremiumController>();
      final status = c.subscriptionStatus.value;
      parts.add(
        'Firestore isPremium=${c.isPremium} '
        '(loading=${c.isLoading.value}, '
        'productId=${status?.productId ?? "—"})',
      );
    } else {
      parts.add('PremiumController not registered yet');
    }
    if (shouldHideAds) {
      return 'Ads BLOCKED: ${parts.join("; ")}';
    }
    return 'Ads allowed (free user): ${parts.join("; ")}';
  }
}
