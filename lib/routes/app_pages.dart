import 'package:get/get.dart';
import 'package:share_app_latest/app/views/auth/login/login.dart';
import 'package:share_app_latest/app/views/auth/sign_up/signup.dart';
import 'package:share_app_latest/app/views/home/ChooseMethods/choose_method_scan.dart';
import 'package:share_app_latest/app/views/home/QR/Qr_reciever.dart';
import 'package:share_app_latest/app/views/home/QR/Qr_sender.dart';
import 'package:share_app_latest/app/views/home/connection/connection_method_screen.dart';
import 'package:share_app_latest/app/views/home/transfer_file/transfer_file_screen.dart';

import 'package:share_app_latest/app/views/home/home_screen.dart';
import 'package:share_app_latest/app/views/home/wifi-direct/pairing_page.dart';
import 'package:share_app_latest/app/views/home/received_files_screen.dart';
import 'package:share_app_latest/app/views/home/remove_duplicates/duplicate_preview_screen.dart';
import 'package:share_app_latest/app/views/home/remove_duplicates/duplicate_scan_screen.dart';
import 'package:share_app_latest/app/views/getStarted/get_started.dart';
import 'package:share_app_latest/app/views/transfer_recovery/transfer_recovery_screen.dart';
import 'package:share_app_latest/components/transfer_progress_screen.dart';
import 'package:share_app_latest/app/views/splash/splash_screen.dart';
import 'package:share_app_latest/app/views/premium/premium_page.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashScreen(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: AppRoutes.onboaring,
      page: () => const getStartedScreen(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginScreen(),
      transition: Transition.fade,
    ),
    GetPage(
      name: AppRoutes.signup,
      page: () => const SignUpScreen(),
      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: AppRoutes.choosemethodscan,
      page: () {
        final args = Get.arguments as Map<String, dynamic>?;
        final isReceiver = args?['isReceiver'] as bool? ?? false;
        return ChooseMethodScan(isReciver: isReceiver);
      },
      transition: Transition.fade,
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.connectionMethod,
      page: () {
        final args = Get.arguments as Map<String, dynamic>?;
        final isReceiver = args?['isReceiver'] as bool? ?? false;
        return ConnectionMethodScreen(isReceiver: isReceiver);
      },
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<PremiumController>()) {
          Get.put(PremiumController(), permanent: false);
        }
      }),
      transition: Transition.fade,
    ),
    GetPage(
      name: AppRoutes.qrReceiver,
      page: () => const QrReceiverDisplayScreen(),
      transition: Transition.upToDown,
    ),
    GetPage(
      name: AppRoutes.qrSender,
      page: () {
        final args = Get.arguments as Map<String, dynamic>?;
        final list = args?['selectedFiles'] as List<dynamic>?;
        final selectedFiles = list?.cast<String>() ?? <String>[];
        return QrSenderScannerScreen(selectedFiles: selectedFiles);
      },
      transition: Transition.fade,
    ),

    GetPage(
      name: AppRoutes.pairing,
      page: () {
        final args = Get.arguments as Map<String, dynamic>?;
        final isReceiver = args?['isReceiver'] as bool? ?? false;
        return PairingScreen(isReceiver: isReceiver);
      },
      transition: Transition.downToUp,
    ),
    GetPage(
      name: AppRoutes.transferFile,
      page: () => TransferFileScreen(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: AppRoutes.transferProgress,
      page: () => const TransferProgressScreen(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: AppRoutes.transferRecovery,
      page: () => const TransferRecoveryScreen(),
      transition: Transition.fade,
    ),
    GetPage(
      name: AppRoutes.receivedFiles,
      page: () => const ReceivedFilesScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.removeDuplicates,
      page: () => const DuplicateScanScreen(),
      transition: Transition.fade,
    ),
    GetPage(
      name: AppRoutes.duplicatePreview,
      page: () => const DuplicatePreviewScreen(),
      transition: Transition.fade,
    ),
    GetPage(
      name: AppRoutes.premium,
      page: () => const PremiumPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut<PremiumController>(() => PremiumController());
      }),
      transition: Transition.fade,
    ),
  ];
}
