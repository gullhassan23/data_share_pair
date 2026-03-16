import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/foundation.dart';
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
      await Adapty().activate(
        configuration: AdaptyConfiguration(
          apiKey: 'public_live_1Oo1w6PC.4zM4jXq2XK5wZVFEaoba',
        )..withLogLevel(
            kReleaseMode ? AdaptyLogLevel.error : AdaptyLogLevel.verbose,
          ),
      );
      _initialized = true;
      debugPrint('[Adapty] SDK activated');
    } catch (e, st) {
      debugPrint('[Adapty] activate error: $e\n$st');
      return;
    }

    // Identify user with the same device-based id used for backend.
    try {
      final userId = await getOrCreateUserId();
      await identifyUser(userId);
    } catch (e, st) {
      debugPrint('[Adapty] identify on init error: $e\n$st');
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

  /// Call after a successful purchase or restore (after backend says premium=true).
  Future<void> syncAfterPurchaseOrRestore() async {
    final profile = await _getProfile();
    if (profile == null) return;

    final adaptyPremium = _hasActivePremium(profile);
    debugPrint('[Adapty] syncAfterPurchaseOrRestore premium=$adaptyPremium');
    // Optionally compare with backend premium in a separate job.
  }
}

