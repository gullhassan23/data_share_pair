import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Production-grade temp file lifecycle management for file transfers.
///
/// Ensures:
/// - No garbage/orphan files after success, cancel, or failure
/// - Cleanup on next app launch for crash recovery
class TransferTempManager {
  static const _pendingFileName = 'transfer_pending_cleanup.txt';

  final List<String> _currentSession = [];

  /// Register a temp path for cleanup at end of transfer.
  void registerTemp(String path) {
    if (path.isNotEmpty && !_currentSession.contains(path)) {
      _currentSession.add(path);
    }
  }

  /// Remove path from tracking and delete file. Call on success.
  Future<void> unregisterAndDelete(String path) async {
    _currentSession.remove(path);
    await _deleteSafe(path);
  }

  /// Delete all temp files from current transfer. Call on cancel or error.
  Future<void> cleanupCurrentSession() async {
    for (final path in _currentSession.toList()) {
      await _deleteSafe(path);
      _currentSession.remove(path);
    }
  }

  /// Schedule path for cleanup on next app launch (crash recovery).
  Future<void> scheduleCleanupOnNextLaunch(String path) async {
    if (path.isEmpty) return;
    try {
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/$_pendingFileName');
      final existing = await file.exists()
          ? (await file.readAsString()).split('\n').where((s) => s.isNotEmpty)
          : <String>[];
      if (!existing.contains(path)) {
        await file.writeAsString('${existing.join('\n')}\n$path', flush: true);
      }
    } catch (_) {}
  }

  /// Run at app startup to clean any orphaned temp files from previous crash.
  static Future<void> cleanupOnNextLaunch() async {
    try {
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/$_pendingFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        final paths = content.split('\n').where((s) => s.trim().isNotEmpty);
        for (final path in paths) {
          await _deleteSafe(path.trim());
        }
        await file.delete();
      }
    } catch (_) {}
  }

  /// Clear temp dirs used for transfer (transfer_out, transfer_in).
  static Future<void> cleanupTransferDirs() async {
    try {
      final tmp = await getTemporaryDirectory();
      final outDir = Directory('${tmp.path}/transfer_out');
      final inDir = Directory('${tmp.path}/transfer_in');
      if (await outDir.exists()) await outDir.delete(recursive: true);
      if (await inDir.exists()) await inDir.delete(recursive: true);
    } catch (_) {}
  }

  /// Delete a file (e.g. on error before transfer starts). Safe to call anytime.
  static Future<void> deleteFile(String path) => _deleteSafe(path);

  static Future<void> _deleteSafe(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }

  /// Get a temp path for sender staging (copy from picker cache).
  static Future<String> senderStagingPath(String baseName) async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/transfer_out');
    if (!await dir.exists()) await dir.create(recursive: true);
    return '${dir.path}/staging_${DateTime.now().millisecondsSinceEpoch}_$baseName';
  }

  /// Get a temp path for receiver (incoming .part file).
  static Future<String> receiverPartPath(String baseName) async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/transfer_in');
    if (!await dir.exists()) await dir.create(recursive: true);
    return '${dir.path}/recv_${DateTime.now().millisecondsSinceEpoch}_$baseName.part';
  }
}
