import 'package:get/get_utils/src/platform/platform.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests the necessary Bluetooth permissions per-platform.
/// - Android: uses the new bluetooth* + location permissions.
/// - iOS: uses the unified Bluetooth permission only.
Future<bool> askPermissions() async {
  // Android: request the granular Bluetooth + location permissions.
  if (GetPlatform.isAndroid) {
    final status = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location, // required for scanning on Android
    ].request();

    // Log individual permission results for easier debugging
    status.forEach((perm, s) {
      // ignore: avoid_print
      print(
        '[perm] ANDROID $perm -> granted=${s.isGranted} denied=${s.isDenied} '
        'permanentlyDenied=${s.isPermanentlyDenied}',
      );
    });

    final bluetoothGranted =
        status[Permission.bluetoothScan]?.isGranted == true &&
            status[Permission.bluetoothConnect]?.isGranted == true &&
            status[Permission.location]?.isGranted == true;

    return bluetoothGranted;
  }

  // iOS: only Permission.bluetooth is relevant; the bluetoothScan/connect/advertise
  // flags are Android-only and will never be granted on iOS.
  if (GetPlatform.isIOS) {
    final status = await Permission.bluetooth.request();

    // ignore: avoid_print
    print(
      '[perm] IOS bluetooth -> granted=${status.isGranted} '
      'denied=${status.isDenied} permanentlyDenied=${status.isPermanentlyDenied}',
    );

    // On iOS, CoreBluetooth itself will handle showing the system dialog the
    // first time BLE is used. We do not block the flow here even if the user
    // denies, because flutter_blue_plus will surface connection/scan failures.
    return true;
  }

  // Other platforms (web, desktop, etc.) – treat as granted for now.
  return true;
}
