# Apple IAP Subscription Integration – Full Guide

Ye guide **Apple In-App Purchase (subscription)** + **Firebase backend verification** + **Firestore** + **FCM notifications** ka complete flow describe karti hai. Isi setup ko aap **dusri app** mein ya **same app** mein copy karke use kar sakte ho.

---

## 1. Overview (Flow)

1. **Flutter app** – User monthly/yearly plan select karta hai → Apple IAP purchase → receipt backend ko bhejta hai.
2. **Firebase Cloud Function** – Receipt Apple se verify karta hai (ya dev fallback mein direct Firestore update), Firestore `users/{userId}` update karta hai, optional "Welcome to Premium" FCM bhejta hai.
3. **Firestore** – `users/{userId}` mein: `isPremium`, `expiryDate`, `productId`, `fcmToken`, etc.
4. **Flutter** – Firestore stream se premium status read karta hai → UI lock/unlock.
5. **Scheduled function** – Har 24 ghante: jo users 3 din ke andar expire honge unko "renewing soon", jo expire ho chuke unko "expired" notification + `isPremium: false`.

**Important:** Prices **dynamic** hain (Apple se), product IDs **.env** se aate hain. Backend pe **App-Specific Shared Secret** (Firebase Secrets) use hota hai.

---

## 2. Prerequisites

- **Apple Developer account** – App Store Connect pe app + In-App Purchases (auto-renewable subscriptions) create kiye hue.
- **Firebase project** – Blaze plan (Cloud Functions + Firestore + FCM ke liye). Same project Flutter app se linked (google-services.json / GoogleService-Info.plist).
- **App-Specific Shared Secret** – App Store Connect → Your App → App Information → App-Specific Shared Secret. Isko Firebase Secrets mein store karenge.
- **APNs key** (iOS push) – Firebase Console → Project Settings → Cloud Messaging → Apple app → APNs Authentication Key (.p8) upload.

---

## 3. Backend (Firebase Cloud Functions)

### 3.1 Project structure

```
your_project/
  functions/
    package.json
    lib/
      index.js   ← yahan saari logic
```

### 3.2 Dependencies (`functions/package.json`)

```json
{
  "main": "lib/index.js",
  "engines": { "node": "20" },
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^6.0.0"
  }
}
```

### 3.3 Root `firebase.json` (functions block)

Ensure project root `firebase.json` mein functions target ho:

```json
{
  "functions": [
    {
      "source": "functions",
      "codebase": "default"
    }
  ]
}
```

### 3.4 Secret set karna

Terminal se (project root se):

```bash
printf "YOUR_APP_SPECIFIC_SHARED_SECRET" | firebase functions:secrets:set APPSTORE_SHARED_SECRET --data-file=-
```

`YOUR_APP_SPECIFIC_SHARED_SECRET` = App Store Connect se copy kiya hua shared secret.

### 3.5 Functions (`functions/lib/index.js`)

- **verifyAppleSubscription** (HTTP POST):  
  Body: `receiptData`, `productId`, `userId`, optional `fcmToken`.  
  - Apple `verifyReceipt` (prod, phir sandbox) call karta hai.  
  - Success (status 0): Firestore `users/{userId}` update, optional "Welcome to Premium" FCM.  
  - Fail: DEV fallback (optional) – Firestore mein 30/365 din expiry ke sath save + welcome FCM, taake dev/test mein bhi data + notification mile.

- **checkSubscriptions** (scheduled, every 24 hours):  
  - `isPremium === true` + expiry within 3 days → "renewing soon" FCM.  
  - `isPremium === true` + expiry < now → "expired" FCM + `isPremium: false` update.

Full code ke liye repo ka `functions/lib/index.js` dekho – wahi copy karke nayi app ke `functions/lib/index.js` mein use karo.

### 3.6 Deploy

```bash
cd your_project
firebase deploy --only functions
```

Deploy ke baad **verifyAppleSubscription** ka URL Firebase Console → Functions se copy karo – isko Flutter `.env` mein `CLOUD_FUNCTION_URL` mein daalna hai.

---

## 4. Flutter App

### 4.1 Dependencies (`pubspec.yaml`)

Add/ensure ye packages:

```yaml
dependencies:
  flutter_riverpod: ^3.2.0
  shared_preferences: ^2.2.2
  firebase_core: ^4.5.0
  in_app_purchase: ^3.1.11
  http: ^1.2.2
  cloud_firestore: ^6.1.3
  firebase_messaging: ^16.1.2
  flutter_dotenv: ^5.1.0
```

Assets mein `.env` include karo:

```yaml
flutter:
  assets:
    - .env
```

### 4.2 Environment (`.env`)

Project root pe `.env` file (git ignore karo):

```env
CLOUD_FUNCTION_URL=https://REGION-PROJECT_ID.cloudfunctions.net/verifyAppleSubscription
IAP_PRODUCT_MONTHLY=com.yourapp.premium.monthly
IAP_PRODUCT_YEARLY=com.yourapp.premium.yearly
PRIVACY_POLICY_URL=https://yoursite.com/privacy
```

- `CLOUD_FUNCTION_URL` = deploy ke baad milne wala verifyAppleSubscription HTTP URL.  
- Product IDs = App Store Connect pe jo subscription product IDs create kiye hain.

### 4.3 Files to add / what they do

| File | Purpose |
|------|--------|
| `lib/utils/user_id.dart` | Device-based `userId` (SharedPreferences) – Firestore doc id & backend ko bhejne ke liye |
| `lib/services/fcm_token_service.dart` | FCM permission + token Firestore `users/{userId}.fcmToken` pe save |
| `lib/services/in_app_purchase_service.dart` | IAP init, product load, buy/restore, purchase stream, backend verification call |
| `lib/providers/premium_provider.dart` | Riverpod: IAP service, userId, Firestore subscription stream, `isPremiumProvider` |
| `lib/views/premium/premium_page.dart` | Premium screen: monthly/yearly plans, dynamic price, restore, premium success state |
| `lib/routes/route_name.dart` | Add `premiumScreen` route name |
| `lib/routes/route.dart` | Add `PremiumPage` route |

### 4.4 main.dart

- `WidgetsFlutterBinding.ensureInitialized()`  
- `await dotenv.load(fileName: '.env');`  
- `await Firebase.initializeApp(...);`  
- `await initializeFcmAndUploadToken();` (from fcm_token_service)  
- `runApp(ProviderScope(child: const MyApp()));`

### 4.5 Kahan se Premium screen open karni hai

Jahan "Premium / Subscribe" button chahiye (e.g. Profile), wahan:

```dart
Navigator.of(context).pushNamed(RouteName.premiumScreen);
```

Route name aur route definition `route_name.dart` / `route.dart` mein add karo (detail **SUBSCRIPTION_QUICK_PLACEMENT.md** mein).

### 4.6 Premium feature lock (optional)

Jahan premium check karni ho:

```dart
final isPremium = ref.watch(isPremiumProvider);
if (!isPremium) {
  // show paywall or navigate to PremiumPage
  return;
}
// show premium content
```

---

## 5. iOS-specific

- Xcode: **Signing & Capabilities** → **In-App Purchase** + **Push Notifications** enable karo.
- Firebase: **APNs Authentication Key** (.p8) upload (Cloud Messaging).
- Sandbox tester: App Store Connect → Users and Access → Sandbox → Testers. Device pe sandbox account se login karke test karo.

---

## 6. Firestore structure

Collection: `users`  
Document ID: `userId` (device-based, from `user_id.dart`)

Fields (backend + app set karte hain):

- `isPremium` (bool)
- `expiryDate` (Timestamp, optional)
- `productId` (string, optional)
- `fcmToken` (string, optional)
- `updatedAt` (Timestamp, optional)

---

## 7. Notifications summary

- **Welcome to Premium** – Backend tab bhejta hai jab `verifyAppleSubscription` Firestore update kare (success ya dev fallback).  
- **Renewing soon** – Scheduled function jab expiry 3 din ke andar ho.  
- **Expired** – Scheduled function jab expiry ho chuki ho + `isPremium` false kar deta hai.

---

## 8. Dusri app mein use karna

1. Backend: Naya Firebase project ya same project – `functions/` copy karo, secret set karo, deploy karo.  
2. Flutter: Ye files copy karo: `user_id.dart`, `fcm_token_service.dart`, `in_app_purchase_service.dart`, `premium_provider.dart`, `premium_page.dart`; route + route_name add karo; `main.dart` mein dotenv + Firebase + FCM init; `.env` nayi app ke product IDs & function URL ke sath.  
3. App Store Connect: Nayi app ke liye naye IAP products + same ya naya App-Specific Shared Secret (agar alag app hai to naya secret).  
4. **SUBSCRIPTION_QUICK_PLACEMENT.md** use karo – kon sa code kahan paste karna hai short list hai.

---

## 9. Reference – Feelio code paths

- Backend: `functions/lib/index.js`  
- Flutter: `lib/utils/user_id.dart`, `lib/services/fcm_token_service.dart`, `lib/services/in_app_purchase_service.dart`, `lib/providers/premium_provider.dart`, `lib/views/premium/premium_page.dart`, `lib/routes/route_name.dart`, `lib/routes/route.dart`, `lib/main.dart`  
- Config: `.env`, `pubspec.yaml` (dependencies + assets)
