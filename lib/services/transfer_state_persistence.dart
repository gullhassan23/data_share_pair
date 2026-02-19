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

  /// Save that transfer started
  static Future<void> saveTransferStarted({
    required bool isSender,
    required String fileName,
    required int totalBytes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyInProgress, true);
    await prefs.setString(_keyRole, isSender ? 'sender' : 'receiver');
    await prefs.setString(_keyFileName, fileName);
    await prefs.setDouble(_keyProgress, 0.0);
    await prefs.setInt(_keyTotalBytes, totalBytes);
    await prefs.setString(_keyStartedAt, DateTime.now().toIso8601String());
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
  }

  /// Check if we had a transfer in progress (for splash / recovery)
  static Future<bool> hadTransferInProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyInProgress) ?? false;
  }

  /// Get persisted state for recovery screen
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
    );
  }
}

class PersistedTransferState {
  final bool isSender;
  final String fileName;
  final double progress;
  final int totalBytes;
  final DateTime startedAt;

  PersistedTransferState({
    required this.isSender,
    required this.fileName,
    required this.progress,
    required this.totalBytes,
    required this.startedAt,
  });
}
