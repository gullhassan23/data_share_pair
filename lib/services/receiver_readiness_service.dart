import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

/// Device-agnostic network readiness for QR receiver.
/// Handles OEM differences: Xiaomi, Oppo, Vivo, Samsung, etc.
/// - getWifiIP() returns null on many devices
/// - NetworkInterface.list() interface order varies by OEM (wlan0 vs rmnet, etc.)
/// - Network stack may not be ready immediately on screen open
class ReceiverReadinessService {
  static const int _maxRetries = 5;
  static const Duration _retryDelay = Duration(milliseconds: 400);

  /// Discover routable IPv4 with retries. Prefers Wi-Fi (wlan*) over cellular (rmnet).
  static Future<String?> discoverLocalIp({int maxRetries = _maxRetries}) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      final ip = await _tryDiscoverIp();
      if (ip != null && ip.isNotEmpty) return ip;
      if (attempt < maxRetries - 1) {
        await Future.delayed(_retryDelay);
      }
    }
    return null;
  }

  static Future<String?> _tryDiscoverIp() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty) return wifiIp;

      final fromInterfaces = await _getIpFromNetworkInterfaces();
      return fromInterfaces;
    } catch (e) {
      return null;
    }
  }

  /// Get IP from NetworkInterface, preferring wlan* (Wi‑Fi) over rmnet (cellular).
  /// Some OEMs expose rmnet first; Wi‑Fi is required for local file transfer.
  static Future<String?> _getIpFromNetworkInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      String? wlanIp;
      String? fallbackIp;

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final a = addr.address;
          if (a.isEmpty) continue;

          final name = iface.name.toLowerCase();
          if (name.startsWith('wlan') || name.startsWith('wifi')) {
            wlanIp ??= a;
          } else if (fallbackIp == null) {
            fallbackIp = a;
          }
        }
      }

      return wlanIp ?? fallbackIp;
    } catch (_) {
      try {
        final interfaces = await NetworkInterface.list();
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              return addr.address;
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Wait until a valid IP is available or timeout. For slow network stack init.
  static Future<String?> waitForNetworkReady({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final ip = await discoverLocalIp(maxRetries: 1);
      if (ip != null) return ip;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return null;
  }
}
