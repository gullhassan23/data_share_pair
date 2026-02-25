import 'package:get/get.dart';
import 'package:share_app_latest/app/models/device_info.dart';
import 'app_routes.dart';

class AppNavigator {
  AppNavigator._(); // private constructor

  static void toSplash() {
    Get.toNamed(AppRoutes.splash);
  }

  static void toOnboarding() {
    Get.offNamed(AppRoutes.onboaring);
  }

  static void toLogin() {
    Get.offAllNamed(AppRoutes.login);
  }

  static void toSignup() {
    Get.toNamed(AppRoutes.signup);
  }

  static void tochooseMethod() {
    Get.toNamed(AppRoutes.chooseMethod);
  }

  static void tochooseMethodscan() {
    Get.toNamed(AppRoutes.choosemethodscan);
  }

  static void toHome() {
    Get.offAllNamed(AppRoutes.home);
  }

  static void toSendReceive() {
    Get.offAllNamed(AppRoutes.home);
  }

  static Future<dynamic>? toTransferProgress({
    required DeviceInfo device,
    required String filePath,
    required String fileName,
    String? senderTempPath,
  }) {
    return Get.toNamed(
      AppRoutes.transferProgress,
      arguments: {
        'device': device,
        'filePath': filePath,
        'fileName': fileName,
        if (senderTempPath != null) 'senderTempPath': senderTempPath,
      },
    );
  }

  static void toPairing({required bool isReceiver}) {
    Get.toNamed(
      AppRoutes.pairing,
      arguments: <String, dynamic>{'isReceiver': isReceiver},
    );
  }

  static void toConnectionMethod({required bool isReceiver}) {
    Get.toNamed(
      AppRoutes.connectionMethod,
      arguments: <String, dynamic>{'isReceiver': isReceiver},
    );
  }

  static void toQrSender(List<String> selectedFilePaths) {
    Get.toNamed(
      AppRoutes.qrSender,
      arguments: <String, dynamic>{'selectedFiles': selectedFilePaths},
    );
  }

  static void toQrReceiver() {
    Get.toNamed(AppRoutes.qrReceiver);
  }

  static Future<dynamic>? toTransferFile({required DeviceInfo device}) {
    return Get.toNamed(AppRoutes.transferFile, arguments: device);
  }

  static void toReceivedFiles({DeviceInfo? device}) {
    Get.toNamed(AppRoutes.receivedFiles, arguments: device);
  }

  /// Navigate to transfer recovery screen (after app relaunch when a transfer was interrupted).
  static void toTransferRecovery(Object? persistedState) {
    Get.offNamed(AppRoutes.transferRecovery, arguments: persistedState);
  }

  static void back() {
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
    }
  }
}
