import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:ui_background_task/ui_background_task.dart';

/// Wraps flutter_foreground_task (Android) and ui_background_task (iOS) to keep transfers alive when app is backgrounded.
/// - Android: Foreground service with notification prevents process kill
/// - iOS: beginBackgroundTask gives ~30s to finish; long transfers should stay in foreground
/// - Transfer logic runs in main process; service only keeps it alive
/// - NEVER cancel transfer on lifecycle — only on explicit user cancel
class TransferForegroundService {
  static const int _serviceId = 0x54464253; // "TFBS" hex

  /// iOS: task ID from beginBackgroundTask; end when transfer completes/fails.
  static int? _iosBackgroundTaskId;

  /// Call from main() before runApp
  static void init() {
    FlutterForegroundTask.initCommunicationPort();
  }

  /// Start foreground service (Android) or background task (iOS) when transfer begins.
  static Future<bool> startTransferNotification({
    required bool isSender,
    required String fileName,
  }) async {
    if (Platform.isIOS) {
      try {
        _iosBackgroundTaskId = await UiBackgroundTask.instance.beginBackgroundTask();
        return true;
      } catch (e) {
        return false;
      }
    }
    if (!Platform.isAndroid) return true;

    try {
      final title = isSender ? 'Sending' : 'Receiving';
      final text = fileName.isNotEmpty ? fileName : 'File transfer in progress';

      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
        return true;
      }

      await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        notificationTitle: title,
        notificationText: text,
        notificationIcon: null,
        notificationButtons: [
          const NotificationButton(id: 'open', text: 'Open'),
        ],
        notificationInitialRoute: '/transfer-progress',
        callback: transferTaskCallback,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update notification with progress. Call periodically during transfer.
  static Future<void> updateProgress({
    required String fileName,
    required double progress,
    required double sentMB,
    required double totalMB,
    required double speedMBps,
    required bool isSender,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      final pct = (progress * 100).toInt();
      final text = '${sentMB.toStringAsFixed(1)} / ${totalMB.toStringAsFixed(1)} MB ($pct%) · ${speedMBps.toStringAsFixed(1)} MB/s';
      final title = isSender ? 'Sending' : 'Receiving';

      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    } catch (_) {}
  }

  /// Stop foreground service (Android) or end background task (iOS) when transfer completes or user cancels.
  static Future<void> stopTransferNotification() async {
    if (Platform.isIOS) {
      final taskId = _iosBackgroundTaskId;
      _iosBackgroundTaskId = null;
      if (taskId != null) {
        try {
          await UiBackgroundTask.instance.endBackgroundTask(taskId);
        } catch (_) {}
      }
      return;
    }
    if (!Platform.isAndroid) return;

    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}
  }

}

/// Top-level callback for foreground task. Required by plugin.
@pragma('vm:entry-point')
void transferTaskCallback() {
  FlutterForegroundTask.setTaskHandler(TransferTaskHandler());
}

class TransferTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // No-op: transfer logic runs in main isolate
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No-op: progress updates come from TransferController via updateService
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // No-op
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'open') {
      FlutterForegroundTask.launchApp('/transfer-progress');
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/transfer-progress');
  }

  @override
  void onNotificationDismissed() {}
}
