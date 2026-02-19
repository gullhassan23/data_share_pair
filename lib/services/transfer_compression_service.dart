import 'dart:io';
import 'package:path/path.dart' as p;

/// Adaptive compression for file transfer.
///
/// - Skips already-compressed formats (video, image, audio, archives)
/// - Optional size threshold (skip if file > maxSizeToCompress bytes)
/// - Returns original path if compression not beneficial
class TransferCompressionService {
  static const int defaultMaxSizeToCompressBytes = 50 * 1024 * 1024; // 50 MB

  static final _skipCompressExtensions = {
    // Video
    '.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v', '.wmv', '.flv',
    // Image
    '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic',
    // Audio
    '.mp3', '.aac', '.ogg', '.flac', '.m4a', '.wav', '.wma',
    // Archives
    '.zip', '.rar', '.7z', '.gz', '.xz', '.bz2', '.tar',
    // Documents (often compressed internally)
    '.pdf',
  };

  /// Returns true if this file type should NOT be compressed.
  static bool isAlreadyCompressed(String path) {
    final ext = p.extension(path).toLowerCase();
    return _skipCompressExtensions.contains(ext);
  }

  /// Returns true if compression would likely help (compressible + under size limit).
  static bool shouldCompress(
    String path, {
    int maxSizeBytes = defaultMaxSizeToCompressBytes,
  }) {
    if (isAlreadyCompressed(path)) return false;
    try {
      final f = File(path);
      return f.existsSync() && f.lengthSync() <= maxSizeBytes;
    } catch (_) {
      return false;
    }
  }

  /// Placeholder for future streaming compression.
  /// Currently returns false (no compression) — implement with isolate + gzip when needed.
  static Future<bool> compressToTemp(
    String sourcePath,
    String destPath, {
    void Function(double)? onProgress,
  }) async {
    // TODO: Implement with archive package or dart:io ZLib in isolate
    // For now, no compression — transfer raw file
    return false;
  }
}
