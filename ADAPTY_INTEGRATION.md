# Adapty Integration Guide (Feelio)

This document explains how Adapty is integrated into this project, and how to reuse the same pattern in other Flutter apps using:

- Flutter frontend
- Firestore (as the main source of truth for `isPremium`)
- Apple In‑App Purchases via `in_app_purchase`
- AdMob for ads on free users
- Adapty **only** for subscription analytics & validation

---

## 1. High‑level architecture

- **Source of truth for premium**: Firestore (`users/{userId}` with `isPremium`, etc.)  
- **Apple IAP flow**: `in_app_purchase` + backend Cloud Function that verifies receipts and updates Firestore.  
- **AdMob**: shows ads **only when `isPremium == false`** (already wired in the app).  
- **Adapty**: Flutter SDK used to:
  - Track subscription analytics (profiles, access levels) in Adapty dashboard
  - Double‑check subscription status (optional)  
  - Does **not** drive UI directly; UI remains based on Firestore.

Key idea: Adapty is a **secondary analytic/validation layer**, not the primary subscription authority.

---

## 2. Dependencies

### pubspec.yaml

```yaml
dependencies:
  adapty_flutter: ^3.15.4  # check latest version on pub.dev
```

Run:

```bash
flutter pub get
```

---

## 3. Adapty dashboard setup

In the Adapty dashboard:

1. **Create app + copy Public SDK Key**
   - `App settings → General` (or `API keys`)
   - Copy `public_live_...` key → used in Flutter.

2. **Connect App Store**
   - `Getting started → Connect app stores`
   - Connect iOS app (bundle id same as this project).

3. **Create products**
   - `Getting started → Create product`
   - For each App Store subscription product:
     - Product ID must match the real App Store ID (e.g. `com.relvr.stress.relief.asmr.app.auto.premium.monthly`).

4. **Create access level `premium`**
   - `App settings → Access levels`
   - Create access level key: `premium`
   - Attach monthly, yearly products to this access level.

5. **General settings**
   - Timezone: UTC or your preferred reporting timezone.
   - “Sharing paid access between user accounts”: **Enabled (default)**.
   - API keys:
     - Public key: for Flutter.
     - Secret key: for backend/server only (never put into Flutter code).

---

## 4. Adapty service in this project

File: `lib/services/adapty_service.dart`

Responsibilities:

- Activate Adapty SDK once at startup.
- Identify user using the same device‑based user id as Firestore/back‑end (`getOrCreateUserId()`).
- Fetch Adapty profile for analytics.
- Sync profile after successful purchase or restore.

### Code

```dart
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:feelio/utils/user_id.dart';
import 'package:flutter/foundation.dart';

/// Adapty integration used for subscription analytics & validation.
/// Firestore remains the main source of truth for isPremium; this service
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
          apiKey: 'YOUR_ADAPTY_PUBLIC_SDK_KEY',
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

    // Identify user with the same device-based id used for Firestore/backend.
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

  /// Call after a successful purchase or restore (after Firestore says isPremium=true).
  Future<void> syncAfterPurchaseOrRestore() async {
    final profile = await _getProfile();
    if (profile == null) return;

    final adaptyPremium = _hasActivePremium(profile);
    debugPrint('[Adapty] syncAfterPurchaseOrRestore premium=$adaptyPremium');
    // Here you can optionally compare with Firestore isPremium in a backend job.
  }
}
```

Replace `'YOUR_ADAPTY_PUBLIC_SDK_KEY'` with your own public key.

To reuse in another project, copy this file and change:

- `getOrCreateUserId()` to whatever your app uses for unique user id.
- The import path (e.g. remove `feelio/` prefixes).

---

## 5. Initializing Adapty at app startup

File: `lib/main.dart`

```dart
import 'package:feelio/services/adapty_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ... dotenv + Firebase initialize ...

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Google Mobile Ads
  await AdMobService.initialize();

  // FCM token upload
  await initializeFcmAndUploadToken();

  // NEW: Adapty init (analytics/validation)
  await AdaptyService.instance.init();

  runApp(ProviderScope(child: const MyApp()));
}
```

In a different project, simply import your own `AdaptyService` and call `init()` once during startup, after any core initialization (Firebase, etc.).

---

## 6. Hooking Adapty into the purchase flow

File: `lib/services/in_app_purchase_service.dart`

Adapty is integrated where purchases are **confirmed** by your backend. After a valid purchase/restore, we call:

```dart
unawaited(AdaptyService.instance.syncAfterPurchaseOrRestore());
```

Concrete snippets from this project (inside `_onPurchaseUpdated`):

```dart
case PurchaseStatus.purchased:
  final isValid = await _verifyPurchaseWithBackend(purchaseDetails);
  if (isValid) {
    _isPremium = true;
    debugPrint('[IAP] _onPurchaseUpdated: success — premium granted');
    // Sync Adapty analytics/profile after successful purchase.
    unawaited(AdaptyService.instance.syncAfterPurchaseOrRestore());
  }
  // ...
  break;

case PurchaseStatus.restored:
  final isValid = await _verifyPurchaseWithBackend(purchaseDetails);
  if (isValid) {
    _isPremium = true;
    debugPrint('[IAP] _onPurchaseUpdated: restore success — premium granted');
    // Sync Adapty analytics/profile after successful restore.
    unawaited(AdaptyService.instance.syncAfterPurchaseOrRestore());
  }
  // ...
  break;
```

In another project, add the same call in your purchase logic **after**:

- Store verifies the receipt, and
- Your app has marked the user as premium.

---

## 7. How to read “is premium” from Adapty (optional)

If needed (for validation/analytics), you can read Adapty’s idea of premium:

```dart
final profile = await Adapty().getProfile();
final access = profile.accessLevels['premium'];
final isPremium = access != null && access.isActive;
```

In this app we still **drive the UI and AdMob from Firestore**, but you can log differences:

```dart
final profile = await AdaptyService.instance._getProfile();
// Compare _hasActivePremium(profile) with Firestore.isPremium in a backend job.
```

---

## 8. Notes for reusing in other Flutter apps

When copying this integration into another project:

1. Add `adapty_flutter` dependency.
2. Create your own `AdaptyService` (or reuse this file, changing:
   - Import path for `getOrCreateUserId()` or swap in your own user id provider.
3. In the new project’s `main.dart`, call `AdaptyService.instance.init()` after main initialization.
4. In the new project’s purchase service:
   - Call `syncAfterPurchaseOrRestore()` when a subscription becomes active or is restored.
5. Configure Adapty dashboard:
   - Connect stores, create products matching App Store/Play IDs.
   - Create access levels (e.g. `premium`) and attach products.

This keeps your **purchase logic, backend, and AdMob code unchanged**, while Adapty receives accurate subscription analytics.

