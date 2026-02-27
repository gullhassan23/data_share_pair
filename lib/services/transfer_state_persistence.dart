import 'package:shared_preferences/shared_preferences.dart';

/// Persists transfer state so we can restore UI on app relaunch.
/// Used when: app was killed during transfer (show "interrupted") or to decide
/// whether to skip splash and go directly to transfer screen.
class TransferStatePersistence {
  static const _keyInProgress = 'transfer_in_progress';
  static const _keyRole = 'transfer_role';
  static const _keyFileName = 'transfer_file_name';
  static const _keyProgress = 'transfer_progress';
  static const _keyTotalBytes = 'transfer_total_bytes';
  static const _keyStartedAt = 'transfer_started_at';
  // Sender-only: for resume so we can show progress screen with same context
  static const _keyDeviceName = 'transfer_device_name';
  static const _keyDeviceIp = 'transfer_device_ip';
  static const _keyDevicePort = 'transfer_device_port';
  static const _keyFilePath = 'transfer_file_path';

  /// Save that transfer started
  static Future<void> saveTransferStarted({
    required bool isSender,
    required String fileName,
    required int totalBytes,
    String? deviceName,
    String? deviceIp,
    int? devicePort,
    String? filePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyInProgress, true);
    await prefs.setString(_keyRole, isSender ? 'sender' : 'receiver');
    await prefs.setString(_keyFileName, fileName);
    await prefs.setDouble(_keyProgress, 0.0);
    await prefs.setInt(_keyTotalBytes, totalBytes);
    await prefs.setString(_keyStartedAt, DateTime.now().toIso8601String());
    if (isSender) {
      if (deviceName != null) await prefs.setString(_keyDeviceName, deviceName);
      if (deviceIp != null) await prefs.setString(_keyDeviceIp, deviceIp);
      if (devicePort != null) await prefs.setInt(_keyDevicePort, devicePort);
      if (filePath != null) await prefs.setString(_keyFilePath, filePath);
    }
  }

  /// Update progress during transfer
  static Future<void> updateProgress(double progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyProgress, progress);
  }

  /// Clear state when transfer completes, cancels, or errors
  static Future<void> clearTransferState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyInProgress);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyFileName);
    await prefs.remove(_keyProgress);
    await prefs.remove(_keyTotalBytes);
    await prefs.remove(_keyStartedAt);
    await prefs.remove(_keyDeviceName);
    await prefs.remove(_keyDeviceIp);
    await prefs.remove(_keyDevicePort);
    await prefs.remove(_keyFilePath);
  }

  /// Check if we had a transfer in progress (for splash / recovery)
  static Future<bool> hadTransferInProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyInProgress) ?? false;
  }

  /// Get persisted state for recovery screen and resume navigation
  static Future<PersistedTransferState?> getPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final inProgress = prefs.getBool(_keyInProgress) ?? false;
    if (!inProgress) return null;

    return PersistedTransferState(
      isSender: prefs.getString(_keyRole) == 'sender',
      fileName: prefs.getString(_keyFileName) ?? 'File',
      progress: prefs.getDouble(_keyProgress) ?? 0.0,
      totalBytes: prefs.getInt(_keyTotalBytes) ?? 0,
      startedAt: DateTime.tryParse(
            prefs.getString(_keyStartedAt) ?? '',
          ) ??
          DateTime.now(),
      deviceName: prefs.getString(_keyDeviceName),
      deviceIp: prefs.getString(_keyDeviceIp),
      devicePort: prefs.getInt(_keyDevicePort),
      filePath: prefs.getString(_keyFilePath),
    );
  }
}

class PersistedTransferState {
  final bool isSender;
  final String fileName;
  final double progress;
  final int totalBytes;
  final DateTime startedAt;
  final String? deviceName;
  final String? deviceIp;
  final int? devicePort;
  final String? filePath;

  PersistedTransferState({
    required this.isSender,
    required this.fileName,
    required this.progress,
    required this.totalBytes,
    required this.startedAt,
    this.deviceName,
    this.deviceIp,
    this.devicePort,
    this.filePath,
  });
}
