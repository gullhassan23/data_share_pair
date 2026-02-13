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

  static void toHome() {
    Get.offAllNamed(AppRoutes.home);
  }

  // static void toChooseFile() {
  //   Get.offAllNamed(AppRoutes.chooseFile);
  // }
 static Future<dynamic>? toTransferProgress({
    required DeviceInfo device,
    required String filePath,
    required String fileName,
  }) {
    return Get.toNamed(
      AppRoutes.transferProgress,
      arguments: {
        'device': device,
        'filePath': filePath,
        'fileName': fileName,
      },
    );
  }
  static void toPairing() {
    Get.toNamed(AppRoutes.pairing);
  }

  // static void toChooseFile({required DeviceInfo device}) {
  //   Get.toNamed(AppRoutes.chooseFile, arguments: device);
  // }
  static Future<dynamic>? toChooseFile({required DeviceInfo device}) {
    return Get.toNamed(AppRoutes.chooseFile, arguments: device);
  }

  static Future<dynamic>? toTransferFile({required DeviceInfo device}) {
    return Get.toNamed(AppRoutes.transferFile, arguments: device);
  }

  static void toReceivedFiles({DeviceInfo? device}) {
    Get.toNamed(AppRoutes.receivedFiles, arguments: device);
  }

  static void back() {
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
    }
  }
}
