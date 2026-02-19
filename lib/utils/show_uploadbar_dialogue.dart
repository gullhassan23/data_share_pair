import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_app_latest/app/controllers/progress_controller.dart';
import 'package:share_app_latest/app/models/device_info.dart';
import 'package:share_app_latest/routes/app_routes.dart';

/// Placeholder device for receiver progress screen when sender DeviceInfo is unknown.
DeviceInfo get _placeholderSenderDevice =>
    DeviceInfo(name: 'Sender', ip: '0.0.0.0', transferPort: 9090);

/// Navigates to full-screen transfer progress with required arguments when possible.
/// Sender: pass [device], [filePath], [fileName] for single-file flow.
/// When sender omits file args (e.g. multi-file QR), shows a simple progress overlay instead.
/// Receiver: pass [device] (or null for placeholder).
void showTransferProgressDialog({
  required bool isSender,
  DeviceInfo? device,
  String? filePath,
  String? fileName,
}) {
  final d = device ?? _placeholderSenderDevice;
  final path = filePath ?? '';
  final name = fileName ?? '';
  if (isSender && path.isNotEmpty && name.isNotEmpty) {
    Get.toNamed(
      AppRoutes.transferProgress,
      arguments: <String, dynamic>{
        'device': d,
        'filePath': path,
        'fileName': name,
      },
    );
    return;
  }
  if (!isSender) {
    Get.toNamed(
      AppRoutes.transferProgress,
      arguments: <String, dynamic>{
        'device': d,
        'filePath': '',
        'fileName': '',
      },
    );
    return;
  }
  // Sender without file args (e.g. multi-file QR): show overlay that reads from ProgressController
  Get.dialog(
    PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Transferring...'),
              const SizedBox(height: 16),
              Obx(() {
                final progress = Get.find<ProgressController>();
                return LinearProgressIndicator(
                  value: progress.sendProgress.value.clamp(0.0, 1.0),
                );
              }),
            ],
          ),
        ),
      ),
    ),
    barrierDismissible: false,
  );
}
