import 'package:get/get_utils/src/platform/platform.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> askPermissions() async {
  Map<Permission, PermissionStatus> status =
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location, // required for scanning on Android
        if (!GetPlatform.isAndroid || (await _isAndroidBelow13()))
          Permission.storage,
        if (GetPlatform.isAndroid && (await _isAndroid13OrAbove()))
          Permission.photos,
      ].request();

  // check only bluetooth related permissions
  bool bluetoothGranted =
      status[Permission.bluetoothScan]?.isGranted == true &&
      status[Permission.bluetoothConnect]?.isGranted == true &&
      (status[Permission.bluetoothAdvertise]?.isGranted == true ||
          !GetPlatform.isAndroid);

  return bluetoothGranted;
}

Future<bool> _isAndroid13OrAbove() async {
  return (await Permission.bluetoothScan.status.isDenied) ||
      (await Permission.photos.status.isDenied);
}

Future<bool> _isAndroidBelow13() async {
  return (await Permission.storage.status.isDenied);
}
