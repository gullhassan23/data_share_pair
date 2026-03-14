# Subscription Integration – Kon Sa Kahan Add Karna Hai

Ye short checklist hai: **kon si cheez kis file / kis jagah add karni hai** taake aap same ya dusri app mein integration jaldi copy-paste kar sako.

---

## 1. Project root

| Kya add karna hai | Kahan | Kaise |
|-------------------|--------|--------|
| `.env` file | Project root (Flutter app ke sath) | Nayi file banao. Andar: `CLOUD_FUNCTION_URL`, `IAP_PRODUCT_MONTHLY`, `IAP_PRODUCT_YEARLY`, `PRIVACY_POLICY_URL` (optional). |

`.env` example:
```env
CLOUD_FUNCTION_URL=https://REGION-PROJECT_ID.cloudfunctions.net/verifyAppleSubscription
IAP_PRODUCT_MONTHLY=com.yourapp.premium.monthly
IAP_PRODUCT_YEARLY=com.yourapp.premium.yearly
PRIVACY_POLICY_URL=https://yoursite.com/privacy
```

---

## 2. pubspec.yaml

| Kya add karna hai | Kahan |
|-------------------|--------|
| Dependencies | `dependencies:` ke andar add karo: `in_app_purchase`, `http`, `cloud_firestore`, `firebase_messaging`, `flutter_dotenv`. Agar pehle se `firebase_core`, `shared_preferences`, `flutter_riverpod` hain to skip. |
| Asset `.env` | `flutter:` → `assets:` list mein add: `- .env` |

---

## 3. Flutter – Naye files (copy whole file)

In files ko **bilkul waisa** copy karo (package name sirf replace karo agar dusri app hai, e.g. `feelio` → `yourapp`):

| File path | Kya karna hai |
|-----------|----------------|
| `lib/utils/user_id.dart` | Poori file copy karo – device userId SharedPreferences se. |
| `lib/services/fcm_token_service.dart` | Poori file copy karo – FCM token Firestore pe save. Package import `feelio` → apna package. |
| `lib/services/in_app_purchase_service.dart` | Poori file copy karo – IAP + backend verification. Package `feelio` → apna. |
| `lib/providers/premium_provider.dart` | Poori file copy karo – Riverpod providers. Package `feelio` → apna. |
| `lib/views/premium/premium_page.dart` | Poori file copy karo – Premium UI. Package `feelio` → apna. |

---

## 4. Routes – kahan add karna hai

### 4.1 Route name

**File:** `lib/routes/route_name.dart`  
**Jahan:** class ke andar, baaki static constants ke sath.

**Add karo:**
```dart
static const String premiumScreen = 'premium-screen';
```

### 4.2 Route definition

**File:** `lib/routes/route.dart`  
**Jahan 1:** Top par imports ke sath.

**Add karo:**
```dart
import 'package:feelio/views/premium/premium_page.dart';  // feelio → apna package
```

**Jahan 2:** `generateRoute` ke `switch (settings.name)` ke andar, baaki cases ke sath.

**Add karo:**
```dart
case RouteName.premiumScreen:
  return MaterialPageRoute(builder: (_) => const PremiumPage());
```

---

## 5. main.dart – kahan add karna hai

**File:** `lib/main.dart`

| Step | Kahan | Kya add karna hai |
|------|--------|-------------------|
| 1 | Top imports | `import 'package:flutter_dotenv/flutter_dotenv.dart';`<br>`import 'package:feelio/services/fcm_token_service.dart';` (package name apna) |
| 2 | `main()` – binding ke baad, `runApp` se pehle | `await dotenv.load(fileName: '.env');` (try/catch optional) |
| 3 | `main()` – Firebase init ke baad, `runApp` se pehle | `await initializeFcmAndUploadToken();` |

Order: `WidgetsFlutterBinding.ensureInitialized()` → dotenv load → Firebase init → FCM init → runApp.

---

## 6. Profile (ya koi screen) – Premium button

**File:** Jahan premium/subscribe button chahiye (e.g. `lib/views/profile/profile_screen.dart`).

**Add karo:**
- Import: `import 'package:feelio/routes/route_name.dart';` (package apna)
- Button pe tap:
```dart
Navigator.of(context).pushNamed(RouteName.premiumScreen);
```

Example button:
```dart
TextButton.icon(
  onPressed: () {
    Navigator.of(context).pushNamed(RouteName.premiumScreen);
  },
  icon: const Icon(Icons.star, size: 20),
  label: const Text('Premium / Subscribe'),
)
```

---

## 7. Kisi screen pe premium check (optional)

**Jahan:** Jis widget mein premium feature lock karni ho (e.g. koi screen).

**Kya add karna hai:**
- `ConsumerWidget` / `ConsumerStatefulWidget` use karo (Riverpod).
- `ref.watch(isPremiumProvider)` se check:
```dart
final isPremium = ref.watch(isPremiumProvider);
if (!isPremium) {
  // Navigate to premium or show paywall
  return ...;
}
// Premium content
```

---

## 8. Firebase backend – kahan kya add karna hai

| Kya | Kahan |
|-----|--------|
| Functions code | `functions/lib/index.js` – poori file Feelio repo se copy karo ya `verifyAppleSubscription` + `checkSubscriptions` wala logic. |
| Secret | Terminal: `printf "SHARED_SECRET" | firebase functions:secrets:set APPSTORE_SHARED_SECRET --data-file=-` |
| firebase.json | Root `firebase.json` mein `functions` block ho: `"source": "functions"` |

Deploy: `firebase deploy --only functions`.  
Deploy ke baad **verifyAppleSubscription** ka URL copy karke `.env` mein `CLOUD_FUNCTION_URL` mein daalo.

---

## 9. Checklist – ek nazar mein

- [ ] `.env` root pe (CLOUD_FUNCTION_URL, IAP product IDs)
- [ ] `pubspec.yaml`: dependencies + `assets: - .env`
- [ ] `lib/utils/user_id.dart` (copy)
- [ ] `lib/services/fcm_token_service.dart` (copy)
- [ ] `lib/services/in_app_purchase_service.dart` (copy)
- [ ] `lib/providers/premium_provider.dart` (copy)
- [ ] `lib/views/premium/premium_page.dart` (copy)
- [ ] `lib/routes/route_name.dart`: `premiumScreen`
- [ ] `lib/routes/route.dart`: import + case `premiumScreen` → `PremiumPage`
- [ ] `lib/main.dart`: dotenv load, FCM init
- [ ] Profile (ya koi screen): button → `pushNamed(RouteName.premiumScreen)`
- [ ] Firebase: `functions/lib/index.js`, secret, deploy; `.env` mein URL
- [ ] iOS: Capabilities (IAP + Push), APNs key Firebase pe

Iske baad app run karo, Premium screen open karo, product IDs aur backend URL sahi hon to purchase flow + Firestore + notifications kaam karenge. Full detail ke liye **SUBSCRIPTION_INTEGRATION_GUIDE.md** dekho.
