import 'dart:convert' show jsonDecode;

class HotspotInfo {
  final String ssid;
  final String password;
  final String ip;
  final int port;
  /// Human-readable receiver device name (e.g. "Samsung", "iPhone") for UX.
  /// Exchanged via QR handshake so sender shows "Resolving receiver on Samsung" not IP.
  final String deviceName;

  HotspotInfo({
    required this.ssid,
    required this.password,
    required this.ip,
    this.port = 9090,
    this.deviceName = '',
  });

  /// Creates a HotspotInfo from a map (typically from platform channel)
  factory HotspotInfo.fromMap(Map<String, dynamic> map) {
    return HotspotInfo(
      ssid: map['ssid'] as String? ?? '',
      password: map['password'] as String? ?? '',
      ip: map['ip'] as String? ?? '',
      port: map['port'] is int ? map['port'] as int : (int.tryParse(map['port']?.toString() ?? '') ?? 9090),
      deviceName: (map['deviceName'] as String? ?? '').trim(),
    );
  }

  /// Converts to a map for JSON serialization/QR code generation
  Map<String, dynamic> toMap() {
    return {
      'ssid': ssid,
      'password': password,
      'ip': ip,
      'port': port,
      if (deviceName.isNotEmpty) 'deviceName': deviceName,
    };
  }

  /// Converts to JSON string for QR code
  String toJson() {
    final buf = StringBuffer('{"ssid":"${_escape(ssid)}","password":"${_escape(password)}","ip":"${_escape(ip)}","port":$port');
    if (deviceName.isNotEmpty) {
      buf.write(',"deviceName":"${_escape(deviceName)}"');
    }
    buf.write('}');
    return buf.toString();
  }

  static String _escape(String s) => s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

  /// Creates a HotspotInfo from JSON string (typically from QR code)
  factory HotspotInfo.fromJson(String json) {
    final map = _decodeQrJson(json);
    return HotspotInfo.fromMap(map);
  }

  @override
  String toString() {
    return 'HotspotInfo(ssid: $ssid, password: $password, ip: $ip, port: $port, deviceName: $deviceName)';
  }
}

Map<String, dynamic> _decodeQrJson(String json) {
  try {
    final decoded = jsonDecode(json);
    return Map<String, dynamic>.from(
      (decoded as Map).map((k, v) => MapEntry(k.toString(), v)),
    );
  } catch (_) {
    return _parseLegacyQrJson(json);
  }
}

Map<String, dynamic> _parseLegacyQrJson(String json) {
  json = json.trim();
  if (!json.startsWith('{') || !json.endsWith('}')) {
    throw FormatException('Invalid JSON format');
  }
  final result = <String, dynamic>{};
  final content = json.substring(1, json.length - 1);
  final pairs = content.split(',');
  for (final pair in pairs) {
    final parts = pair.split(':');
    if (parts.length == 2) {
      final key = parts[0].trim().replaceAll('"', '');
      final value = parts[1].trim().replaceAll('"', '');
      result[key] = key == 'port' ? (int.tryParse(value) ?? 9090) : value;
    }
  }
  return result;
}
