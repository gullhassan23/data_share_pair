import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothController extends GetxController {
  final isScanning = false.obs;
  final devices = <BluetoothDevice>[].obs;
  final error = ''.obs;

  Future<void> startScan() async {
    devices.clear();
    error.value = '';
    isScanning.value = true;
    try {
      final supported = await FlutterBluePlus.isSupported;
      if (!supported) {
        error.value = 'Bluetooth not supported';
        isScanning.value = false;
        return;
      }
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      FlutterBluePlus.scanResults.listen(
        (results) {
          for (final r in results) {
            final d = r.device;
            final id = d.remoteId.str;
            final exists = devices.any((e) => e.remoteId.str == id);
            if (!exists) devices.add(d);
          }
        },
        onDone: () => isScanning.value = false,
        onError: (_) {
          error.value = 'Bluetooth scan error';
          isScanning.value = false;
        },
      );
    } catch (e) {
      error.value = 'Bluetooth plugin unavailable';
      isScanning.value = false;
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    isScanning.value = false;
  }
}
