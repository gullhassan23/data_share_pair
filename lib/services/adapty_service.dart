import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:share_app_latest/utils/user_id.dart';

/// Adapty integration used for subscription analytics & validation.
/// Firestore remains the main source of truth for premium; this service
/// keeps Adapty in sync with successful purchases/restores.
class AdaptyService {
  AdaptyService._();
  static final AdaptyService instance = AdaptyService._();

  bool _initialized = false;

  /// Call once at app startup (after Firebase.initializeApp).
  Future<void> init() async {
    if (_initialized) return;

    try {
      final apiKey = dotenv.env['ADAPTY_PUBLIC_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('[Adapty] ADAPTY_PUBLIC_API_KEY missing in .env');
        return;
      }
      await Adapty().activate(
        configuration: AdaptyConfiguration(
          apiKey: apiKey,
        )
          ..withObserverMode(true)
          ..withLogLevel(
            kReleaseMode ? AdaptyLogLevel.error : AdaptyLogLevel.verbose,
          ),
      );
      debugPrint('[Adapty] SDK activated (observer mode)');
    } on AdaptyError catch (e, st) {
      // 3005 = "can only be activated once" – safe to ignore as success.
      if (e.code == 3005) {
        debugPrint(
          '[Adapty] activate called more than once, treating as already initialized.\n$st',
        );
      } else {
        debugPrint(
          '[Adapty] activate AdaptyError code=${e.code} message=${e.message}\n$st',
        );
        return;
      }
    } catch (e, st) {
      debugPrint('[Adapty] activate unexpected error: $e\n$st');
      return;
    }

    _initialized = true;

    await _linkFirebaseIntegration();

    // Identify user with the same device-based id used for backend.
    try {
      final userId = await getOrCreateUserId();
      await identifyUser(userId);
    } catch (e, st) {
      debugPrint('[Adapty] identify on init error: $e\n$st');
    }
  }

  /// Links Adapty profile to Firebase so subscription revenue can sync to GA4.
  Future<void> _linkFirebaseIntegration() async {
    if (!_initialized) return;
    try {
      final appInstanceId = await FirebaseAnalytics.instance.appInstanceId;
      if (appInstanceId == null || appInstanceId.isEmpty) {
        debugPrint('[Adapty] Firebase appInstanceId unavailable');
        return;
      }
      await Adapty().setIntegrationIdentifier(
        key: 'firebase_app_instance_id',
        value: appInstanceId,
      );
      debugPrint('[Adapty] linked firebase_app_instance_id');
    } on AdaptyError catch (e, st) {
      debugPrint(
        '[Adapty] setIntegrationIdentifier error code=${e.code} message=${e.message}\n$st',
      );
    } catch (e, st) {
      debugPrint('[Adapty] link Firebase integration error: $e\n$st');
    }
  }

  /// Identify current user by your internal user id.
  Future<void> identifyUser(String userId) async {
    if (!_initialized) return;
    try {
      await Adapty().identify(userId);
      debugPrint('[Adapty] identified user: $userId');
    } on AdaptyError catch (e, st) {
      debugPrint(
        '[Adapty] identify error code=${e.code} message=${e.message}\n$st',
      );
    } catch (e, st) {
      debugPrint('[Adapty] identify unexpected error: $e\n$st');
    }
  }

  /// Optional logout hook if you ever introduce explicit account switching.
  Future<void> logout() async {
    if (!_initialized) return;
    try {
      await Adapty().logout();
      debugPrint('[Adapty] logout ok');
    } on AdaptyError catch (e, st) {
      debugPrint(
        '[Adapty] logout error code=${e.code} message=${e.message}\n$st',
      );
    } catch (e, st) {
      debugPrint('[Adapty] logout unexpected error: $e\n$st');
    }
  }

  Future<AdaptyProfile?> _getProfile() async {
    if (!_initialized) return null;
    try {
      final profile = await Adapty().getProfile();
      debugPrint('[Adapty] profile fetched: $profile');
      return profile;
    } on AdaptyError catch (e, st) {
      debugPrint(
        '[Adapty] getProfile error code=${e.code} message=${e.message}\n$st',
      );
      return null;
    } catch (e, st) {
      debugPrint('[Adapty] getProfile unexpected error: $e\n$st');
      return null;
    }
  }

  bool _hasActivePremium(AdaptyProfile profile) {
    // Requires access level key "premium" configured in Adapty dashboard.
    final access = profile.accessLevels['premium'];
    return access != null && access.isActive;
  }

  /// Report a store transaction to Adapty (required in observer mode with
  /// [in_app_purchase]). Call after [InAppPurchase.completePurchase].
  Future<void> reportTransaction(PurchaseDetails purchaseDetails) async {
    if (!_initialized) return;

    final transactionId = purchaseDetails.purchaseID;
    if (transactionId == null || transactionId.isEmpty) {
      debugPrint(
        '[Adapty] reportTransaction skipped: missing transaction id '
        'for ${purchaseDetails.productID}',
      );
      return;
    }

    try {
      await Adapty().reportTransaction(transactionId: transactionId);
      debugPrint(
        '[Adapty] reportTransaction ok product=${purchaseDetails.productID} '
        'transactionId=$transactionId',
      );
    } on AdaptyError catch (e, st) {
      debugPrint(
        '[Adapty] reportTransaction error code=${e.code} message=${e.message}\n$st',
      );
    } catch (e, st) {
      debugPrint('[Adapty] reportTransaction unexpected error: $e\n$st');
    }
  }

  /// Call after a successful purchase or restore (after backend says premium=true).
  Future<void> syncAfterPurchaseOrRestore({
    PurchaseDetails? purchaseDetails,
  }) async {
    if (purchaseDetails != null) {
      await reportTransaction(purchaseDetails);
    }

    final profile = await _getProfile();
    if (profile == null) return;

    final adaptyPremium = _hasActivePremium(profile);
    debugPrint('[Adapty] syncAfterPurchaseOrRestore premium=$adaptyPremium');
  }
}

