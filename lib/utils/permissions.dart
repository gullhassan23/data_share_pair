 import 'package:permission_handler/permission_handler.dart';

Future<void> askPermissions() async {
    await [
      Permission.storage,
      Permission.photos,
      Permission.videos,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }