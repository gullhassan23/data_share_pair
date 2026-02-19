# Phase 1: Project-Level Analysis — Navigation & Bluetooth

**Scope:** Full navigation flow, Bluetooth plugins, permissions, receiver mode, Android config, and crash-risk patterns. No fixes applied.

---

## 1. Navigation Flow (Traced End-to-End)

### 1.1 Entry and Mode Selection

| Step | Screen / Action | Route / Method | File |
|------|----------------|-----------------|------|
| 1 | **App entry** | `main()` → `runApp(MyApp())` | `lib/main.dart` |
| 2 | **Initial route** | `initialRoute: AppRoutes.splash` | `lib/main.dart` → `GetMaterialApp` |
| 3 | **Splash** | `SplashScreen` | `lib/app/views/splash/splash_screen.dart` |
| 4 | After progress | `AppNavigator.toOnboarding()` | `_goNext()` in splash |
| 5 | **Onboarding** | `OnboardingScreen` | `lib/app/views/onboarding/onboarding_screen.dart` |
| 6 | "Start Transferring" | `AppNavigator.toHome()` | onboarding_screen.dart:110 |
| 7 | **Home (mode selection)** | `HomeScreen` | `lib/app/views/home/home_screen.dart` |
| 8 | "Send Files" | `AppNavigator.toConnectionMethod(isReceiver: false)` | home_screen.dart:104 |
| 9 | "Receive Files" | `AppNavigator.toConnectionMethod(isReceiver: true)` | home_screen.dart:110 |

**Note:** Splash always goes to Onboarding; Onboarding goes to Home (no login in the main path). Login/Signup exist and can navigate to Home but are not in the default flow.

### 1.2 Bluetooth Selection and Receiver Screen

| Step | Screen / Action | How reached | File |
|------|----------------|-------------|------|
| 10 | **Connection method** | Named route `AppRoutes.connectionMethod` with args `isReceiver` | `lib/app/views/home/connection/connection_method_screen.dart` |
| 11 | User taps **"Bluetooth"** | `Get.to(() => const BluetoothReceiverScreen())` or `BluetoothSenderScreen()` | connection_method_screen.dart:119–123 |
| 12 | **Bluetooth receiver** | **Not a named route** — pushed with `Get.to()` | `lib/app/views/home/bluetooth/reciever_bluetooth.dart` |
| 13 | **Bluetooth sender** | Same — `Get.to(() => const BluetoothSenderScreen())` | `lib/app/views/home/bluetooth/sender_bluetooth.dart` |

So: **BluetoothReceiverScreen** and **BluetoothSenderScreen** are **not** in `AppPages`; they are pushed on top of `ConnectionMethodScreen`. Back pops to Connection Method.

---

## 2. Bluetooth Stack — What Is Used and Where

### 2.1 Plugins (from `pubspec.yaml`)

- **flutter_blue_plus: ^1.20.5** — BLE central: scan, connect, GATT client (sender side).
- **ble_peripheral: ^2.4.0** — BLE peripheral: advertise, GATT server (receiver side).

### 2.2 Where Bluetooth Is “Initialized”

- **main.dart**  
  - `Get.put(BluetoothController(), permanent: true);`  
  - One **global** controller (no tag). It is never used for the Bluetooth UI flows below.

- **BluetoothReceiverScreen** (`reciever_bluetooth.dart`)  
  - `initState()`: `bluetooth = Get.put(BluetoothController(), tag: "receiver");`  
  - So a **second** controller instance, tag `"receiver"`, is created when the receiver screen opens.  
  - This instance runs receiver mode.

- **BluetoothSenderScreen** (`sender_bluetooth.dart`)  
  - `initState()`: `bluetooth = Get.put(BluetoothController(), tag: "sender");`  
  - A **third** instance, tag `"sender"`, used for scan/connect.

So: **No single “global Bluetooth service”** in the sense of one controller driving both flows. The UI creates **tagged** controllers per screen; the global one in `main()` is unused for Bluetooth and can be confusing or lead to duplicate state if code ever references the wrong instance.

### 2.3 Where Permissions Are Requested

- **Function:** `askPermissions()` in `lib/utils/permissions.dart`.
- **Requested:**  
  - `Permission.bluetoothScan`  
  - `Permission.bluetoothConnect`  
  - `Permission.bluetoothAdvertise`  
  - `Permission.location`  
  - Conditionally `Permission.storage` or `Permission.photos` (Android version heuristic).
- **Used from:**
  - **BluetoothReceiverScreen:** inside `addPostFrameCallback`: `await askPermissions()` then `bluetooth.startReceiverMode()`.
  - **BluetoothSenderScreen:** inside `addPostFrameCallback`: `await askPermissions()` then `bluetooth.startScan()`.

So permissions are requested **in the UI**, in a post-frame callback, right before starting receiver or scan — not in a shared app startup step.

### 2.4 Where Receiver Mode / “Server” (BLE Peripheral) Is Started

- **BluetoothController.startReceiverMode()** (`lib/app/controllers/bluetooth_controller.dart`, ~305–343).
  - Sets `isReceiver = true`, clears error/devices.
  - Ensures BT is on via `FlutterBluePlus.turnOn()`.
  - Calls **`_peripheralService.start()`** (no `await` at call site — method is `void startReceiverMode() async`).

- **BluetoothPeripheralService.start()** (`lib/services/bluetooth_peripheral_service.dart`, ~25–139).
  - `BlePeripheral.initialize()`.
  - Builds a GATT service/characteristic (same UUIDs as central: `SERVICE_UUID`, `CHARACTERISTIC_UUID`).
  - `BlePeripheral.addService(service)`.
  - `BlePeripheral.startAdvertising(services: [SERVICE_UUID], localName: localName)`.
  - Registers callbacks: connection state change, characteristic subscription change, **write request** (incoming BLE data → `_dataStreamController`).

So the **“receiver / server”** is the **ble_peripheral** advertising + GATT server. The “server socket” for the actual file transfer is **not** Bluetooth; it’s the **TransferController** TCP server (started on Accept in the receiver flow).

### 2.5 Who Controls Bluetooth (Global vs UI)

- **UI directly controls Bluetooth:**  
  - Receiver screen: creates controller with tag `"receiver"`, calls `startReceiverMode()` in post-frame callback, and `stopReceiverMode()` in `dispose()`.  
  - Sender screen: creates controller with tag `"sender"`, calls `startScan()` in post-frame callback; scan is not stopped in `dispose()` (comment says intentional).
- **No dedicated global Bluetooth service** that outlives these screens; the only “global” controller is the unused one in `main()`.

---

## 3. Android Manifest and SDK

### 3.1 Permissions (`android/app/src/main/AndroidManifest.xml`)

**Declared:**

- INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE  
- READ_EXTERNAL_STORAGE (maxSdkVersion 32), READ_MEDIA_IMAGES, READ_MEDIA_VIDEO  
- WRITE_EXTERNAL_STORAGE (maxSdkVersion 28)  
- **BLUETOOTH, BLUETOOTH_ADMIN**  
- **BLUETOOTH_SCAN, BLUETOOTH_CONNECT**  
- **ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION**

**Not declared:**

- **BLUETOOTH_ADVERTISE**  
  - Required for BLE advertising on **Android 12 (API 31)+**.  
  - The app **does** request `Permission.bluetoothAdvertise` at runtime in `permissions.dart`, but if the permission is not in the manifest, the system will not grant it and native BLE advertising can fail or crash.  
  - **This is a strong candidate for receiver-mode crashes on Android 12+.**

### 3.2 minSdkVersion and targetSdkVersion

- **Location:** `android/app/build.gradle.kts`  
  - `minSdk = flutter.minSdkVersion`  
  - `targetSdk = flutter.targetSdkVersion`  
- So **not** overridden in the app; they come from the Flutter Gradle plugin (Flutter SDK). You need to confirm actual values from your Flutter version (e.g. `flutter doctor -v` or Gradle output).  
- If `minSdk` &lt; 31, Android 12+ devices still need BLUETOOTH_ADVERTISE in the manifest for advertising to work at runtime.

### 3.3 Foreground Service

- **Usage:** `lib/services/transfer_foreground_service.dart` uses **flutter_foreground_task** to keep transfers alive in the background.
- **App manifest:** No explicit `<service>` or `FOREGROUND_SERVICE_*` permission in `android/app/src/main/AndroidManifest.xml`. The plugin usually merges its own manifest (e.g. service and permission). So foreground service is **plugin-managed**; if the plugin’s merge is incomplete for your target SDK, that could cause issues when starting the notification/service.
- **Initialization:** The service’s docstring says to call `TransferForegroundService.init()` from `main()` before `runApp()`. **This is never done in `main.dart`.** So the foreground task plugin may not be initialized when the first transfer starts — possible failure or crash when `startTransferNotification` is called.

---

## 4. Platform Channels

- **MainActivity** (`android/app/.../MainActivity.kt`):
  - **HOTSPOT_CHANNEL** — `openHotspotSettings`, `openLocationSettings`.
  - **P2P_CHANNEL** — `startP2P`, `stopP2P`, `connectToPeer`, `removeGroup`.
  - **P2P_EVENT_CHANNEL** — event stream for P2P (e.g. peer found, connection info).
- **Bluetooth** is not implemented via platform channels; it uses **flutter_blue_plus** and **ble_peripheral** only.
- **QR_controller** and **hotspot_service** use MethodChannels for P2P/hotspot; no Bluetooth there.

---

## 5. Null-Safety and Crash Risks

### 5.1 Incoming offer dialog (receiver) — likely crash

**File:** `lib/app/views/home/bluetooth/reciever_bluetooth.dart`  
**Method:** `_showIncomingOfferDialog(Map<String, dynamic> offer)`  

```dart
final meta = offer['meta'];
final fileName = meta['name'];
```

- If `offer['meta']` is null or not a map, or if `meta['name']` is missing, this will throw (e.g. null cast or NoSuchMethodError).
- **Exact origin:** Any malformed or partial BLE “offer” payload (e.g. sender sends `{"type":"offer"}` without `meta` or `meta.name`) will crash here.

### 5.2 Guid.parse force unwrap

**File:** `lib/app/controllers/bluetooth_controller.dart`  

```dart
withServices: [Guid.parse(SERVICE_UUID)!],
```

- `SERVICE_UUID` is a constant; parse is unlikely to fail, but the `!` is a potential throw if the format ever changes.

### 5.3 Permissions helper logic

**File:** `lib/utils/permissions.dart`  

- `_isAndroid13OrAbove()` uses “is bluetoothScan denied OR is photos denied” — not a real API-level check.  
- `_isAndroidBelow13()` uses “is storage denied” — also not SDK version.  
- So the storage/photos branching is heuristic and could be wrong on some devices; usually this affects storage only, not the Bluetooth crash.

---

## 6. Async in initState

- **BluetoothReceiverScreen** and **BluetoothSenderScreen** do **not** run async work directly in `initState()`.  
- They use `WidgetsBinding.instance.addPostFrameCallback((_) async { ... })` and inside that callback they `await askPermissions()` and then call `bluetooth.startReceiverMode()` or `bluetooth.startScan()`.  
- So **no async in initState** in the sense of unguarded awaits; the pattern is correct.  
- **Caveat:** `startReceiverMode()` is declared `void startReceiverMode() async` and is not awaited. So if `_peripheralService.start()` throws, the exception is only caught inside that async method and surfaced via `error.value`. No unhandled async from initState, but any failure is easy to miss if the UI doesn’t show `error` clearly.

---

## 7. Stream Subscriptions and Cleanup

- **BluetoothController.startReceiverMode()** subscribes to:
  - `_peripheralService.connectionStream.listen(...)`
  - `_peripheralService.dataStream.listen(...)`
- These **subscriptions are never stored or cancelled** in the controller.  
- **stopReceiverMode()** only calls `_peripheralService.stop()` and clears state; it does **not** cancel these listeners.  
- So after leaving the receiver screen, those stream listeners can still fire (e.g. if the peripheral is torn down asynchronously), leading to updates on a possibly disposed controller or wrong GetX context — **possible leak and/or late callback crash**.  
- **FlutterBluePlus.scanResults.listen(...)** in `startScan()` is also not cancelled in the controller (only scan is stopped when leaving sender; the subscription is not tracked).

---

## 8. Summary: Most Likely Crash Origins

1. **Android 12+ BLE advertising without BLUETOOTH_ADVERTISE in manifest**  
   - Receiver mode calls `BlePeripheral.startAdvertising(...)`. On API 31+, this requires BLUETOOTH_ADVERTISE. If the permission is not declared, runtime request fails and native code can throw or crash when starting advertising.

2. **Malformed BLE offer in receiver**  
   - `_showIncomingOfferDialog` uses `offer['meta']` and `meta['name']` without null/type checks. A malformed or partial offer from the sender will throw in this dialog.

3. **Foreground task not initialized**  
   - `TransferForegroundService.init()` is never called from `main()`. When a transfer starts and the foreground notification is used, the plugin may not be initialized — can cause failure or crash on first use.

4. **Peripheral stream listeners never cancelled**  
   - `connectionStream` and `dataStream` listeners in `startReceiverMode()` are not cancelled in `stopReceiverMode()`. After leaving the receiver screen, callbacks can still run and touch disposed/wrong state — can cause subtle crashes or assertion failures.

---

## 9. Quick Reference

| Item | Location / value |
|------|-------------------|
| Entry screen | `SplashScreen` (AppRoutes.splash) |
| Mode selection | `HomeScreen` → Send / Receive |
| Connection method | `ConnectionMethodScreen` (Bluetooth / WiFi) |
| Bluetooth receiver screen | `BluetoothReceiverScreen` via `Get.to()`, not in AppPages |
| Bluetooth plugins | flutter_blue_plus (central), ble_peripheral (peripheral) |
| Bluetooth “init” | main: one unused controller; receiver/sender screens: Get.put with tag |
| Permissions | `utils/permissions.dart` → `askPermissions()`; called from receiver/sender in post-frame callback |
| Receiver “server” | `BluetoothPeripheralService.start()` → BlePeripheral.initialize + addService + startAdvertising |
| Android 12+ BT permission gap | **BLUETOOTH_ADVERTISE** not in AndroidManifest.xml |
| minSdk/targetSdk | From Flutter (flutter.minSdkVersion / flutter.targetSdkVersion) in app/build.gradle.kts |
| Foreground service | flutter_foreground_task; **TransferForegroundService.init() not called in main()** |
| Platform channels | Hotspot + P2P only in MainActivity; no Bluetooth channels |
| Null-safety risk | `reciever_bluetooth.dart` `_showIncomingOfferDialog`: `meta` / `meta['name']` |
| Async in initState | Correct: only post-frame callback used for async permission + start |

No changes were applied; this document is analysis only. Fixes should target the items in Section 8 and the manifest/permissions in Section 3.1.
