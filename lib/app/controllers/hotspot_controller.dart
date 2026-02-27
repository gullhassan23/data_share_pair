import 'dart:math';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:get/get.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_app_latest/app/models/hotspot_info.dart';
import 'package:share_app_latest/utils/hotspot_service.dart';

class HotspotController extends GetxController {
  final isHotspotActive = false.obs;
  final hotspotInfo = Rxn<HotspotInfo>();
  final isLoading = false.obs;
  final error = ''.obs;
  final generatedPassword = ''.obs;

  /// Generates a random password for the hotspot
  String _generatePassword() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        8,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  /// Starts a Wi-Fi hotspot for file sharing
  Future<bool> startHotspot() async {
    try {
      print('🌐 HotspotController: Starting hotspot...');
      isLoading.value = true;
      error.value = '';

      // On modern Android versions (Android 10 / API 29+) apps cannot programmatically
      // enable tethering/hotspot. Detect and skip the programmatic start to avoid errors.
      if (Platform.isAndroid) {
        try {
          final deviceInfo = DeviceInfoPlugin();
          final androidInfo = await deviceInfo.androidInfo;
          final sdkInt = androidInfo.version.sdkInt;
          if (sdkInt >= 29) {
            error.value =
                'Hotspot not supported programmatically on Android SDK $sdkInt. Please enable hotspot manually.';
            print(
              '⚠️ HotspotController: Skipping programmatic hotspot start on SDK $sdkInt',
            );
            // Still generate SSID/password for QR/manual use even if we cannot start hotspot.
            final ssid =
                'ShareME-${DateTime.now().millisecondsSinceEpoch % 1000}';
            final password = _generatePassword();
            generatedPassword.value = password;

            // Attempt to get a display IP if available to include in QR; otherwise leave empty.
            String ip = '';
            try {
              final info = NetworkInfo();
              final wifiIp = await info.getWifiIP();
              if (wifiIp != null && wifiIp.isNotEmpty) ip = wifiIp;
            } catch (_) {}

            hotspotInfo.value = HotspotInfo(
              ssid: ssid,
              password: password,
              ip: ip,
              port: 9090,
            );
            isHotspotActive.value = false;
            return false;
          }
        } catch (e) {
          // If device info fails, proceed and let HotspotService handle failures.
          print('⚠️ HotspotController: Unable to read Android SDK version: $e');
        }
      }

      final ssid = 'ShareIt-${DateTime.now().millisecondsSinceEpoch % 1000}';
      final password = _generatePassword();
      generatedPassword.value = password;

      final result = await HotspotService.startHotspot(
        ssid: ssid,
        password: password,
      );

      final info = HotspotInfo.fromMap(result);
      hotspotInfo.value = info;
      isHotspotActive.value = true;

      print(
        '✅ Hotspot started: ${info.ssid} (IP: ${info.ip}, Port: ${info.port})',
      );
      return true;
    } catch (e) {
      error.value = e.toString();
      print('❌ HotspotController: Failed to start hotspot: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Stops the currently active hotspot
  Future<bool> stopHotspot() async {
    try {
      isLoading.value = true;
      error.value = '';

      await HotspotService.stopHotspot();
      isHotspotActive.value = false;
      hotspotInfo.value = null;

      print('✅ Hotspot stopped');
      return true;
    } catch (e) {
      error.value = e.toString();
      print('❌ Failed to stop hotspot: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Connects to a hotspot using the provided HotspotInfo
  Future<bool> connectToHotspot(HotspotInfo info) async {
    try {
      isLoading.value = true;
      error.value = '';

      final success = await HotspotService.connectToHotspot(
        info.ssid,
        info.password,
      );

      if (success) {
        print('✅ Connected to hotspot: ${info.ssid}');
        // Store the connected hotspot info
        hotspotInfo.value = info;
      }

      return success;
    } catch (e) {
      error.value = e.toString();
      print('❌ Failed to connect to hotspot: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Disconnects from the currently connected hotspot
  Future<bool> disconnectFromHotspot() async {
    try {
      isLoading.value = true;
      error.value = '';

      final success = await HotspotService.disconnectFromHotspot();
      if (success) {
        print('✅ Disconnected from hotspot');
        hotspotInfo.value = null;
      }

      return success;
    } catch (e) {
      error.value = e.toString();
      print('❌ Failed to disconnect from hotspot: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Gets the QR code data string for the current hotspot
  String? getQrCodeData() {
    if (hotspotInfo.value == null) return null;
    return hotspotInfo.value!.toJson();
  }

  /// Parses QR code data and returns HotspotInfo
  HotspotInfo? parseQrCodeData(String qrData) {
    try {
      String cleaned = qrData.trim();
      if (cleaned.startsWith('\uFEFF')) {
        cleaned = cleaned.substring(1);
      }
      return HotspotInfo.fromJson(cleaned);
    } catch (e) {
      print('❌ Failed to parse QR code data: $e');
      return null;
    }
  }

  /// Gets hotspot information for display
  Map<String, String> getHotspotDisplayInfo() {
    if (hotspotInfo.value == null) {
      return {};
    }

    return {
      'ssid': hotspotInfo.value!.ssid,
      'password': hotspotInfo.value!.password,
      'ip': hotspotInfo.value!.ip,
      'port': hotspotInfo.value!.port.toString(),
    };
  }

  @override
  void onClose() {
    // Stop hotspot when controller is disposed
    if (isHotspotActive.value) {
      stopHotspot();
    }
    super.onClose();
  }
}
