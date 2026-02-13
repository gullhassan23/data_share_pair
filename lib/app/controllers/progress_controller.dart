import 'package:get/get.dart';

class ProgressController extends GetxController {
  /// Progress (0.0 - 1.0)
  final sendProgress = 0.0.obs;
  final receiveProgress = 0.0.obs;

  /// File size info (Sender side)
  final sentMB = 0.0.obs;
  final totalMB = 0.0.obs;

  /// File size info (Receiver side)
  final receivedMB = 0.0.obs;
  final receiveTotalMB = 0.0.obs;

  /// Speed (MB per second)
  final speedMBps = 0.0.obs; // Sender upload speed
  final receiveSpeedMBps = 0.0.obs; // Receiver download speed

  /// Status & Errors
  final status = ''.obs;
  final error = ''.obs;

  /// Reset all progress values
  void reset() {
    sendProgress.value = 0;
    receiveProgress.value = 0;
    sentMB.value = 0;
    totalMB.value = 0;
    receivedMB.value = 0;
    receiveTotalMB.value = 0;
    speedMBps.value = 0;
    receiveSpeedMBps.value = 0;
    status.value = '';
    error.value = '';
  }
}
