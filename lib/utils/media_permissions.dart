import 'package:get/get_utils/src/platform/platform.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests storage/media permissions required for gallery scan and duplicate removal.
/// Uses permission_handler only (avoids photo_manager channel before native plugin is ready).
/// Returns true if access is granted, false otherwise.
Future<bool> requestMediaPermissions() async {
  if (GetPlatform.isAndroid) {
    // READ_MEDIA_IMAGES / READ_MEDIA_VIDEO (Android 13+); permission_handler maps these
    final permissions = <Permission>[Permission.photos, Permission.videos];
    final statuses = await permissions.request();
    return statuses[Permission.photos]?.isGranted == true ||
        statuses[Permission.videos]?.isGranted == true;
  }
  // iOS
  final status = await Permission.photos.request();
  return status.isGranted;
}
