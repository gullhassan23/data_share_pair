import 'package:flutter/services.dart';

class HotspotService {
  static const MethodChannel _channel = MethodChannel(
    'com.share.transfer.file.all.data.app/hotspot',
  );

  /// Starts a Wi-Fi hotspot with the given SSID and password
  /// Returns a map containing hotspot details: {'ssid': String, 'password': String, 'ip': String}
  static Future<Map<String, dynamic>> startHotspot({
    String? ssid,
    String? password,
  }) async {
    try {
      final result = await _channel.invokeMethod('startHotspot', {
        'ssid': ssid,
        'password': password,
      });
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to start hotspot: ${e.message}');
    }
  }

  /// Stops the currently active hotspot
  static Future<bool> stopHotspot() async {
    try {
      final result = await _channel.invokeMethod('stopHotspot');
      return result as bool;
    } on PlatformException catch (e) {
      throw Exception('Failed to stop hotspot: ${e.message}');
    }
  }

  /// Gets information about the currently active hotspot
  /// Returns a map containing hotspot details: {'ssid': String, 'password': String, 'ip': String}
  static Future<Map<String, dynamic>> getHotspotInfo() async {
    try {
      final result = await _channel.invokeMethod('getHotspotInfo');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to get hotspot info: ${e.message}');
    }
  }

  /// Connects to a Wi-Fi hotspot with the given SSID and password
  static Future<bool> connectToHotspot(String ssid, String password) async {
    try {
      final result = await _channel.invokeMethod('connectToHotspot', {
        'ssid': ssid,
        'password': password,
      });
      return result as bool;
    } on PlatformException catch (e) {
      throw Exception('Failed to connect to hotspot: ${e.message}');
    }
  }

  /// Disconnects from the currently connected hotspot
  static Future<bool> disconnectFromHotspot() async {
    try {
      final result = await _channel.invokeMethod('disconnectFromHotspot');
      return result as bool;
    } on PlatformException catch (e) {
      throw Exception('Failed to disconnect from hotspot: ${e.message}');
    }
  }

  /// Open platform hotspot/wifi settings so user can enable hotspot manually.
  static Future<bool> openHotspotSettings() async {
    try {
      final result = await _channel.invokeMethod('openHotspotSettings');
      return result as bool;
    } on PlatformException catch (e) {
      throw Exception('Failed to open hotspot settings: ${e.message}');
    }
  }

  /// Open location settings so user can enable Location services.
  static Future<bool> openLocationSettings() async {
    try {
      final result = await _channel.invokeMethod('openLocationSettings');
      return result as bool;
    } on PlatformException catch (e) {
      throw Exception('Failed to open location settings: ${e.message}');
    }
  }
}

/// Model class for hotspot information
