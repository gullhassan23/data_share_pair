# AdMob Mediation (Meta, Liftoff Monetize, Mintegral)

This app uses [AdMob Mediation](https://developers.google.com/admob/flutter/mediation) with three bidding partners. SDK adapters are wired in `pubspec.yaml`; demand is configured in the **AdMob console** and each partner dashboard.

## Flutter packages (installed)

| Partner | Package | Docs |
|--------|---------|------|
| Meta Audience Network (bidding) | `gma_mediation_meta` | [Meta Flutter mediation](https://developers.google.com/admob/flutter/mediation/meta) |
| Liftoff Monetize | `gma_mediation_liftoffmonetize` | [Liftoff Flutter mediation](https://developers.google.com/admob/flutter/mediation/liftoff-monetize) |
| Mintegral | `gma_mediation_mintegral` | [Mintegral Flutter mediation](https://developers.google.com/admob/flutter/mediation/mintegral) |

Compatible with `google_mobile_ads` 5.x (resolved via `flutter pub get`).

## Native setup (done in repo)

- **Android**: `android/settings.gradle.kts` includes Flutter `includeBuild` (required for mediation plugins). `android/build.gradle.kts` adds the [Mintegral Maven repository](https://developers.google.com/admob/android/mediation/mintegral). `AndroidManifest.xml` already has AdMob app ID and `usesCleartextTraffic` (Meta caching on API 28+). Release ProGuard rules in `android/app/proguard-rules.pro`.
- **iOS**: `ios/Runner/Info.plist` includes `GADApplicationIdentifier` and `SKAdNetworkItems` for Google, Meta, Liftoff, and Mintegral. Minimum iOS 15 in `Podfile`.

## AdMob console (required — you must complete)

For **each** ad unit (banner, interstitial, app open, rewarded):

1. Open [AdMob](https://apps.admob.com/) → **Mediation** → your mediation group (or create one).
2. Under **Bidding**, add ad sources:
   - **Meta Audience Network (Bidding)** — Placement ID from [Meta Business](https://business.facebook.com/pub/).
   - **Liftoff Monetize (Bidding)** — App ID + Placement Reference ID from [Liftoff Monetize](https://publisher.vungle.com/).
   - **Mintegral (Bidding)** — App ID, Placement ID, Ad Unit ID from [Mintegral](https://www.mintegral.com/).
3. **Privacy & messaging**: add **Meta**, **Liftoff**, and **Mobvista/Mintegral** to GDPR and US state regulation partner lists ([EU](https://support.google.com/admob/answer/10113004), [US states](https://support.google.com/admob/answer/14125907)).
4. **app-ads.txt**: publish seller entries for Meta, Liftoff, and Mintegral on your developer website (see each partner’s mediation doc).

## Partner dashboards (required)

| Partner | Create | Map in AdMob |
|--------|--------|----------------|
| Meta | Property → placement (Google AdMob mediation) | Placement ID |
| Liftoff | App → placement with **In-App Bidding** enabled | App ID + Reference ID |
| Mintegral | App → placement with **Header Bidding** | App ID, Placement ID, Ad Unit ID |

Enable **test mode** on each network and register test devices in AdMob before release.

## Verify in the app

1. Debug build: on startup, logcat/Xcode should show `[AdMob] Mediation adapter …` lines from `AdMobService.initialize()`.
2. When an ad loads, logs include `served by mediation adapter: <class>`.
3. Use **Ad Inspector** → single ad source testing for Meta / Liftoff / Mintegral.

## Code entry points

- `pubspec.yaml` — mediation plugin dependencies (native adapters register automatically)
- `lib/services/admob_service.dart` — init + adapter status / mediation class logging
- `lib/main.dart` — `AdMobService.initialize()` at startup
