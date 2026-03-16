# AdMob Integration (Share-It / data_share_pair)

This document describes **where and how** AdMob is integrated in this Flutter app. Premium subscribers see **no ads**; free users see App Open, Banner, Interstitial, and Rewarded ads.

## Behavior

- **Premium users** (`SubscriptionIAPService().isPremium == true`): **no ads** (no banner, interstitial, app-open, rewarded).
- **Free users**: ads show in a natural way:
  - **App Open**: when the app opens or resumes (with a 45s cooldown).
  - **Banner**: bottom of the home (Start Transfer) screen.
  - **Interstitial**: on natural transitions (back from Connection Method, Premium, Transfer File “Done”, Transfer Progress “Try Again”).
  - **Rewarded**: optional “Watch a short ad” on the Premium screen; reward callback can be extended (e.g. temporary unlock).

All ad logic is gated by the premium flag (and optionally `kForceFreeUserForAdTesting` for testing).

---

## 1) Dependencies

**pubspec.yaml**

```yaml
dependencies:
  google_mobile_ads: ^5.2.0
```

---

## 2) Native setup (App IDs)

### Android  
**File:** `android/app/src/main/AndroidManifest.xml`

AdMob Application ID meta-data (currently **test** App ID):

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>
```

### iOS  
**File:** `ios/Runner/Info.plist`

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>
```

**Production:** Replace both App IDs with your real AdMob App IDs before release.

---

## 3) Ad unit IDs and test/production

**File:** `lib/config/ad_unit_ids.dart`

- **Test ad unit IDs** (Google sample IDs) for development.
- **Production placeholders** (replace before release).
- Switches:
  - `_useTestAds` (default `true`) → set `false` for production.
  - `kForceFreeUserForAdTesting` (TEST ONLY) → when `true`, ads show even for premium users. Set **false** for production.

Usage:

```dart
AdUnitIds.bannerAdUnitId
AdUnitIds.interstitialAdUnitId
AdUnitIds.appOpenAdUnitId
AdUnitIds.rewardedAdUnitId
```

---

## 4) Premium status

Premium is provided by **SubscriptionIAPService** (singleton):

- `SubscriptionIAPService().isPremium` → `true` if the user has an active premium subscription.

Ad code treats the user as “free” when:

- `AdUnitIds.kForceFreeUserForAdTesting` is `true`, or  
- `SubscriptionIAPService().isPremium` is `false`.

---

## 5) SDK initialization

**File:** `lib/main.dart`

- `await AdMobService.initialize();` after Firebase and subscription init.
- Preload: `loadAppOpenAd()`, `maybePreloadInterstitial()`, `maybePreloadRewarded()`.

---

## 6) Central ad service

**File:** `lib/services/admob_service.dart`

- **App Open**
  - `loadAppOpenAd(isPremium: ...)`
  - `showAppOpenIfAvailable(isPremium: ..., minInterval: 45s)`
  - Load → show → dispose on dismiss/fail → reload.

- **Interstitial**
  - `loadInterstitial(isPremium: ...)`
  - `showInterstitial(isPremium: ...)`
  - `maybePreloadInterstitial(isPremium)`
  - If shown when not ready, service loads and auto-shows when ready.

- **Rewarded**
  - `loadRewarded(isPremium: ...)`
  - `showRewarded(onEarned: ..., onDismissed: ...)`
  - `maybePreloadRewarded(isPremium)`

- **Banner**
  - `createBannerAd()` returns a `BannerAd` (or `null` if premium). Display via `AdBannerWidget`.

---

## 7) App Open (open / resume)

**File:** `lib/main.dart`

- `_TransferLifecycleWrapper` uses `WidgetsBindingObserver`.
- **First frame:** `addPostFrameCallback` → `showAppOpenIfAvailable()`.
- **Resume:** `didChangeAppLifecycleState(resumed)` → `showAppOpenIfAvailable(minInterval: 45s)`.
- Transfer-resume logic (navigate to transfer progress when a transfer is in progress) runs after the app-open logic.

---

## 8) Banner placement

**File:** `lib/widgets/ad_banner_widget.dart`

- `AdBannerWidget` creates/loads one `BannerAd`, hides when premium (does not dispose immediately to avoid iOS platform-view issues), uses stable key `ValueKey('admob_banner')`.

**Placement:**  
**File:** `lib/app/views/home/home_screen.dart`  
- Banner is at the bottom of the main column (Start Transfer screen), above the bottom of the layout.

---

## 9) Interstitial triggers

Interstitial is shown when leaving these screens (natural transitions):

| Screen | Trigger |
|--------|--------|
| **Connection Method** | Back button → `showInterstitial()` then `Get.back()` |
| **Premium** | Close/back → `showInterstitial()` then `AppNavigator.back()` |
| **Transfer File** | “Done” button and after successful send (delay 2s) → `showInterstitial()` then `AppNavigator.toHome()` |
| **Transfer Progress** | “Try Again” → `showInterstitial()` then `AppNavigator.toSendReceive()` |

Files: `connection_method_screen.dart`, `premium_page.dart`, `transfer_file_screen.dart`, `transfer_progress_screen.dart`.

---

## 10) Rewarded integration

- **Preload:** `main.dart` calls `AdMobService.instance.maybePreloadRewarded()` at startup.
- **Show:** Premium screen has a “Watch a short ad” button that calls `AdMobService.instance.showRewarded(onEarned: ...)`. On earn, a “Thanks for watching!” snackbar is shown; you can extend `onEarned` (e.g. temporary feature unlock).

---

## 11) Android and iOS

- **Android:** `AndroidManifest.xml` has AdMob `APPLICATION_ID`; no extra permissions needed for ads.
- **iOS:** `Info.plist` has `GADApplicationIdentifier`. For production, add your App ID and any required SKAdNetwork IDs if you use attribution.

---

## 12) Testing vs production

- **Development:** Keep `_useTestAds == true` and use the test App IDs in Android/iOS as above.
- **Force ads for testing:** Set `kForceFreeUserForAdTesting = true` in `ad_unit_ids.dart` (premium users will still see ads). Set to **false** for production.

---

## 13) Production checklist

- Set `kForceFreeUserForAdTesting = false`.
- Set `_useTestAds = false`.
- Replace production ad unit IDs in `lib/config/ad_unit_ids.dart`.
- Replace Android and iOS AdMob App IDs in:
  - `android/app/src/main/AndroidManifest.xml`
  - `ios/Runner/Info.plist`

---

## 14) Troubleshooting

**PlatformException(recreating_view, ...)**  
Usually from recreating a platform view (e.g. banner). This project avoids it by:

- Hiding the banner for premium instead of disposing immediately.
- Using a stable key for the banner: `ValueKey('admob_banner')`.

If you add more WebViews or ad views, use stable keys and avoid disposing/recreating in the same frame.
