# Integrations Documentation (Flutter + Firebase + Notifications + AdMob + Adapty)

This document explains the **current, working integrations in this repo** and how to re-setup them from scratch (step-by-step) **with the exact code locations used here**.

> Notes:
> - **Never commit secrets** (API keys, shared secrets, function URLs). Keep them in `.env` and/or Firebase secrets.
> - This app uses **Firestore** as source-of-truth for premium status and uses **Adapty** mainly for subscription analytics/profile sync.

---

## 1) Flutter project & dependencies

### Packages already included
Check `pubspec.yaml`:

- **Firebase**: `firebase_core`, `cloud_firestore`, `firebase_messaging`
- **Ads**: `google_mobile_ads`
- **Subscriptions**: `in_app_purchase`
- **Paywall analytics**: `adapty_flutter`
- **Env**: `flutter_dotenv`

---

## 2) Environment variables (`.env`)

This project loads `.env` at startup:

```25:49:lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeFcmAndUploadToken();
  // ...
}
```

### Required keys (used by code)
Create/maintain `.env` with these keys (example values below are placeholders):

```bash
# Adapty
ADAPTY_PUBLIC_API_KEY=your_public_adapty_key

# IAP product ids (optional: code has defaults if missing)
IAP_PRODUCT_MONTHLY=com.share.transfer.file.all.data.app.premium.monthly
IAP_PRODUCT_YEARLY=com.share.transfer.file.all.data.app.premium.yearly

# Cloud Function HTTPS endpoint (receipt verification)
CLOUD_FUNCTION_URL=https://<region>-<project>.cloudfunctions.net/verifyAppleSubscription

# Links shown on Premium screen (optional, defaults exist)
PRIVACY_POLICY_URL=https://example.com/privacy
TERMS_OF_USE_URL=https://example.com/terms
```

Where each one is used:

- **Adapty key**:

```15:31:lib/services/adapty_service.dart
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
        )..withLogLevel(
            kReleaseMode ? AdaptyLogLevel.error : AdaptyLogLevel.verbose,
          ),
      );
```

- **Cloud function URL for receipt verification**:

```287:323:lib/services/subscription_iap_service.dart
  Future<bool> _verifyPurchaseWithBackend(
    PurchaseDetails purchaseDetails, {
    bool isRestore = false,
  }) async {
    // ...
    final functionUrl = dotenv.env['CLOUD_FUNCTION_URL'];
    if (functionUrl == null || functionUrl.isEmpty) {
      debugPrint(
        '[SubscriptionIAP] _verifyPurchaseWithBackend: CLOUD_FUNCTION_URL missing in .env',
      );
      return false;
    }
    final uri = Uri.parse(functionUrl);
    // ...
    final response = await http.post(
      uri,
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode(body),
    );
```

---

## 3) Firebase (Core + Firestore + Messaging)

### 3.1 Firebase files in this repo

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`
- FlutterFire options: `lib/firebase_options.dart`

The app initializes Firebase using FlutterFire-generated options:

```32:36:lib/main.dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeFcmAndUploadToken();
```

### 3.2 Android Firebase setup (Gradle)

`android/app/build.gradle.kts` applies Google Services plugin:

```1:9:android/app/build.gradle.kts
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
```

### 3.3 Firestore usage

This app stores per-device user doc in `Users/{userId}`.
- FCM token is stored in `Users/{userId}.fcmToken`
- Premium status is stored in `Users/{userId}.isPremium`, `productId`, `expiryDate`

Premium controller listens to Firestore in real-time:

```50:75:lib/app/controllers/premium_controller.dart
  void _listenToFirestore(String uid) {
    _firestoreSub?.cancel();
    _firestoreSub = FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) {
        subscriptionStatus.value = const SubscriptionStatus(isPremium: false);
      } else {
        final data = doc.data()!;
        subscriptionStatus.value = SubscriptionStatus(
          isPremium: data['isPremium'] == true,
          productId: data['productId'] as String?,
          expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
        );
      }
      // Persist and sync premium status for use by ad logic.
      final current = subscriptionStatus.value;
      final isPro = current?.isPremium == true;
      SubscriptionIAPService().setCachedPremium(isPro);
      PremiumStatusStore.saveIsPremium(isPro);
      isLoading.value = false;
    });
  }
```

---

## 4) Notifications

This repo has **two notification-related systems**:

- **FCM push notifications** (Firebase Messaging)
- **Transfer foreground notification** (Android foreground service) for background file transfers

### 4.1 FCM (Firebase Cloud Messaging)

Startup calls `initializeFcmAndUploadToken()`:

```32:36:lib/main.dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeFcmAndUploadToken();
```

What it does (high level):
- Enables FCM auto-init
- Requests notification permission
- Sets iOS foreground presentation options
- Registers background handler
- Logs messages in foreground and when opened
- Uploads `fcmToken` to Firestore `Users/{userId}`
- Listens for token refresh and keeps Firestore updated

Key implementation:

```44:97:lib/services/fcm_token_service.dart
Future<void> initializeFcmAndUploadToken() async {
  try {
    // Ensure FCM auto-init is enabled.
    await FirebaseMessaging.instance.setAutoInitEnabled(true);

    // iOS: allow notification display while app is in foreground.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Register background handler early.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Log all incoming messages (foreground).
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        '[FCM][FG] messageId=${message.messageId} '
        'title=${message.notification?.title} body=${message.notification?.body} data=${message.data}',
      );
    });

    // App opened from notification tap.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM][OPEN] messageId=${message.messageId} data=${message.data}');
    });

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Notification permission denied');
      return;
    }
    await updateFcmTokenInFirestore();

    // Keep Firestore token in sync if it rotates.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      // ...
    });
  } catch (e) {
    debugPrint('[FCM] initializeFcmAndUploadToken error: $e');
  }
}
```

Background handler must be **top-level**:

```6:10:lib/services/fcm_token_service.dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM][BG] messageId=${message.messageId} data=${message.data}');
}
```

### 4.2 Transfer foreground notification (Android) + iOS background task

This is used to keep transfers alive in background:

```7:13:lib/services/transfer_foreground_service.dart
/// Wraps flutter_foreground_task (Android) and ui_background_task (iOS) to keep transfers alive when app is backgrounded.
/// - Android: Foreground service with notification prevents process kill
/// - iOS: beginBackgroundTask gives ~30s to finish; long transfers should stay in foreground
class TransferForegroundService {
```

It initializes before `runApp()`:

```51:54:lib/main.dart
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Initialize foreground task plugin before runApp (required for transfer notifications)
  TransferForegroundService.init();
```

Android foreground service declaration exists in `AndroidManifest.xml`:

```60:65:android/app/src/main/AndroidManifest.xml
        <!-- Foreground service for file transfer (flutter_foreground_task). Android 14+ requires foregroundServiceType. -->
        <service
            android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
            android:foregroundServiceType="dataSync"
            android:exported="false" />
```

Starting/updating/stopping notification:

```23:66:lib/services/transfer_foreground_service.dart
  static Future<bool> startTransferNotification({
    required bool isSender,
    required String fileName,
  }) async {
    if (Platform.isIOS) {
      // ...
      await Permission.notification.request();
      _iosBackgroundTaskId = await UiBackgroundTask.instance.beginBackgroundTask();
      return true;
    }
    // Android:
    await Permission.notification.request();
    // ...
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: title,
      notificationText: text,
      notificationButtons: [
        const NotificationButton(id: 'open', text: 'Open'),
      ],
      notificationInitialRoute: '/transfer-progress',
      callback: transferTaskCallback,
    );
    return true;
  }
```

---

## 5) AdMob (Google Mobile Ads)

### 5.1 App IDs (Android + iOS)

Android `AndroidManifest.xml` includes the AdMob App ID:

```56:60:android/app/src/main/AndroidManifest.xml
        <!-- AdMob App ID (production) -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-3605518487927639~7524679177"/>
```

iOS `Info.plist` includes `GADApplicationIdentifier`:

```31:33:ios/Runner/Info.plist
	<key>GADApplicationIdentifier</key>
	<string>ca-app-pub-3605518487927639~7524679177</string>
```

### 5.2 SDK initialization + preload

At startup the app initializes Mobile Ads and preloads ads:

```43:49:lib/main.dart
  await SubscriptionIAPService().init();
  await AdaptyService.instance.init();
  await AdMobService.initialize();
  AdMobService.instance.loadAppOpenAd();
  AdMobService.instance.maybePreloadInterstitial();
  AdMobService.instance.maybePreloadRewarded();
```

### 5.3 Ad unit IDs (test vs production)

Ad unit IDs are centralized in `lib/config/ad_unit_ids.dart`:

```1:47:lib/config/ad_unit_ids.dart
class AdUnitIds {
  // ...
  static const bool _useTestAds = false;
  static const bool kForceFreeUserForAdTesting = false;
  // ...
  static String get bannerAdUnitId => _useTestAds ? _testBanner : _prodBanner;
  static String get mrecAdUnitId => _useTestAds ? _testBanner : _prodMrec;
  static String get interstitialAdUnitId => _useTestAds ? _testInterstitial : _prodInterstitial;
  static String get appOpenAdUnitId => _useTestAds ? _testAppOpen : _prodAppOpen;
  static String get rewardedAdUnitId => _useTestAds ? _testRewarded : _prodRewarded;
}
```

### 5.4 Premium users: ads disabled (gating)

Ads are disabled when user is premium (based on `PremiumController` / cached flag):

```21:27:lib/services/admob_service.dart
  bool _getIsPremium() {
    if (AdUnitIds.kForceFreeUserForAdTesting) return false;
    if (Get.isRegistered<PremiumController>()) {
      return Get.find<PremiumController>().isPremium;
    }
    return SubscriptionIAPService().isPremium;
  }
```

Banner widget hides itself for premium:

```39:47:lib/widgets/ad_banner_widget.dart
  Widget build(BuildContext context) {
    return Obx(() {
      final premium = _isPremiumNow();
      if (premium) {
        _bannerAd?.dispose();
        _bannerAd = null;
        return const SizedBox.shrink();
      }
      _bannerAd ??= AdMobService.instance.createBannerAd();
```

### 5.5 App Open ad (shown on first frame + on resume)

Shown after first frame:

```104:113:lib/main.dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_firstFrameDone && mounted) {
        _firstFrameDone = true;
        AdMobService.instance.showAppOpenIfAvailable();
      }
    });
```

Also shown on app resume (with min interval):

```125:134:lib/main.dart
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  Future<void> _onResumed() async {
    AdMobService.instance.showAppOpenIfAvailable(minInterval: const Duration(seconds: 45));
    // ...
  }
```

---

## 6) Adapty

### 6.1 Activation

Adapty is activated once during startup:

```43:46:lib/main.dart
  await SubscriptionIAPService().init();
  await AdaptyService.instance.init();
  await AdMobService.initialize();
```

Activation reads API key from `.env` and sets log level:

```19:33:lib/services/adapty_service.dart
      await Adapty().activate(
        configuration: AdaptyConfiguration(
          apiKey: apiKey,
        )..withLogLevel(
            kReleaseMode ? AdaptyLogLevel.error : AdaptyLogLevel.verbose,
          ),
      );
```

### 6.2 Identify user

This project uses a device-based internal userId and identifies it in Adapty:

```52:66:lib/services/adapty_service.dart
    // Identify user with the same device-based id used for backend.
    try {
      final userId = await getOrCreateUserId();
      await identifyUser(userId);
    } catch (e, st) {
      debugPrint('[Adapty] identify on init error: $e\n$st');
    }
```

### 6.3 Sync after purchase/restore

After a successful purchase/restore, Adapty profile is refreshed:

```208:214:lib/services/subscription_iap_service.dart
            // Sync Adapty analytics/profile after successful purchase.
            unawaited(AdaptyService.instance.syncAfterPurchaseOrRestore());
            // Real-time UI update: refresh Firestore status so premium page updates immediately.
            if (Get.isRegistered<PremiumController>()) {
              await Get.find<PremiumController>().refreshSubscriptionStatus();
            }
```

---

## 7) Subscriptions (In-App Purchase) + Firestore premium

### 7.1 Products

Product IDs come from `.env` if present, otherwise default IDs are used:

```14:29:lib/services/subscription_iap_service.dart
Set<String> get kPremiumProductIds {
  final monthly = dotenv.env['IAP_PRODUCT_MONTHLY'];
  final yearly = dotenv.env['IAP_PRODUCT_YEARLY'];
  // ...
  if (ids.isEmpty) {
    ids.addAll({
      'com.share.transfer.file.all.data.app.premium.monthly',
      'com.share.transfer.file.all.data.app.premium.yearly',
    });
  }
  return ids;
}
```

### 7.2 Verification flow (important)

This app verifies purchases on a backend (Firebase Cloud Function). Client sends:
- `receiptData`
- `productId`
- `userId`
- optionally `fcmToken`
- optional `isRestore`

```309:315:lib/services/subscription_iap_service.dart
      final body = <String, dynamic>{
        'receiptData': receiptData,
        'productId': purchaseDetails.productID,
        'userId': userId,
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
        if (isRestore) 'isRestore': true,
      };
```

Firestore is updated by the backend. The UI listens to Firestore in `PremiumController` (section 3.3).

### 7.3 Cached premium for instant ad gating

On app launch, cached premium is loaded so ads respect Pro immediately:

```37:42:lib/main.dart
  // Load cached premium status (if any) so ads respect Pro immediately.
  final cachedPremium = await PremiumStatusStore.loadIsPremium();
  if (cachedPremium != null) {
    SubscriptionIAPService().setCachedPremium(cachedPremium);
  }
```

Persistence implementation:

```1:19:lib/services/premium_status_store.dart
class PremiumStatusStore {
  static const _keyIsPremium = 'is_premium';

  static Future<void> saveIsPremium(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsPremium, value);
  }

  static Future<bool?> loadIsPremium() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_keyIsPremium)) return null;
    return prefs.getBool(_keyIsPremium);
  }
}
```

---

## 8) Firebase Cloud Functions (receipt verification + notifications)

Backend lives in `functions/index.js`.

### 8.1 verifyAppleSubscription (HTTPS)

Function: `exports.verifyAppleSubscription` verifies Apple receipt and writes to Firestore `Users/{userId}`.

Key points:
- Requires secret: `APPSTORE_SHARED_SECRET` (Firebase Functions secret)
- Writes: `isPremium`, `productId`, `expiryDate`, `autoRenewStatus`, `latestReceipt`, `fcmToken`
- Sends FCM notifications on events (first subscribe / renewal / restore / cancel)

Entry point:

```34:41:functions/index.js
exports.verifyAppleSubscription = onRequest(
  { secrets: [APPSTORE_SHARED_SECRET] },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        return res.status(405).send("Method not allowed");
      }
```

It sends FCM like:

```12:31:functions/index.js
async function sendFcmNotification({
  fcmToken,
  title,
  body,
  data,
}) {
  if (!fcmToken || typeof fcmToken !== "string") return;
  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data: data && typeof data === "object" ? data : undefined,
    });
  } catch (e) {
    console.error("FCM send failed:", e);
  }
}
```

### 8.2 checkSubscriptions (scheduled job)

Runs daily and:
- Notifies users expiring soon
- Notifies expired users
- Marks expired users `isPremium=false` in batch

```402:462:functions/index.js
exports.checkSubscriptions = onSchedule("every 24 hours", async () => {
  const now = new Date();
  const soon = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
  // ...
  await Promise.allSettled(sendPromises);
  await batch.commit();
  return null;
});
```

### 8.3 Deploy steps (backend)

From repo root:

```bash
cd functions
npm install
```

Set the required secret in Firebase:

```bash
firebase functions:secrets:set APPSTORE_SHARED_SECRET
```

Deploy:

```bash
firebase deploy --only functions
```

Then copy your deployed function URL into `.env` as `CLOUD_FUNCTION_URL` (see section 2).

---

## 9) Platform configuration checklist (quick)

### Android
- `android/app/google-services.json` exists
- Google Services plugin applied:
  - `android/app/build.gradle.kts` has `id("com.google.gms.google-services")`
- AdMob App ID present:
  - `android/app/src/main/AndroidManifest.xml` has `com.google.android.gms.ads.APPLICATION_ID`
- Notification permission present (Android 13+):
  - `android.permission.POST_NOTIFICATIONS` in manifest
- Foreground service present for transfers:
  - `com.pravera.flutter_foreground_task.service.ForegroundService`

### iOS
- `ios/Runner/GoogleService-Info.plist` exists
- `ios/Runner/Info.plist` contains:
  - `GADApplicationIdentifier`
  - `UIBackgroundModes` includes `remote-notification`

---

## 10) Common issues / sanity checks

### FCM token is null / not saving
- iOS: token may be null until permission is granted; code already retries:

```12:24:lib/services/fcm_token_service.dart
Future<String?> _getFcmTokenWithRetry({int maxAttempts = 5, Duration delay = const Duration(seconds: 2)}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      debugPrint('[FCM] getToken attempt $attempt failed: $e');
      if (attempt < maxAttempts) await Future<void>.delayed(delay);
    }
  }
  return null;
}
```

### Ads still show for premium users
- Ensure Firestore doc `Users/{userId}.isPremium == true`
- Ensure `kForceFreeUserForAdTesting` is `false`:

```7:11:lib/config/ad_unit_ids.dart
  static const bool _useTestAds = false;
  static const bool kForceFreeUserForAdTesting = false;
```

### Purchases succeed but premium not granted
- Check `CLOUD_FUNCTION_URL` in `.env`
- Check Cloud Function logs for `verifyAppleSubscription`
- Ensure `APPSTORE_SHARED_SECRET` is set in Firebase secrets

---

## 11) Integration entry points (where to look in code)

- **App startup**: `lib/main.dart`
- **Firebase options**: `lib/firebase_options.dart`
- **FCM**: `lib/services/fcm_token_service.dart`
- **Transfer foreground notification**: `lib/services/transfer_foreground_service.dart`
- **AdMob**: `lib/services/admob_service.dart`, `lib/config/ad_unit_ids.dart`, `lib/widgets/ad_banner_widget.dart`
- **Adapty**: `lib/services/adapty_service.dart`
- **IAP + backend verify**: `lib/services/subscription_iap_service.dart`, `functions/index.js`
- **Premium status (Firestore)**: `lib/app/controllers/premium_controller.dart`, `lib/services/premium_status_store.dart`

