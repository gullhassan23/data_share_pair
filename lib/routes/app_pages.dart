import 'package:get/get.dart';
import 'package:share_app_latest/app/views/auth/login/login.dart';
import 'package:share_app_latest/app/views/auth/sign_up/signup.dart';
import 'package:share_app_latest/app/views/home/ChooseMethods/choose_method.dart';
import 'package:share_app_latest/app/views/home/ChooseMethods/choose_method_scan.dart';
import 'package:share_app_latest/app/views/home/QR/Qr_reciever.dart';
import 'package:share_app_latest/app/views/home/QR/Qr_sender.dart';
import 'package:share_app_latest/app/views/home/connection/connection_method_screen.dart';
import 'package:share_app_latest/app/views/home/transfer_file/transfer_file_screen.dart';

import 'package:share_app_latest/app/views/home/home_screen.dart';
import 'package:share_app_latest/app/views/home/pairing/pairing_page.dart';
import 'package:share_app_latest/app/views/home/received_files_screen.dart';
import 'package:share_app_latest/app/views/onboarding/onboarding_screen.dart';
import 'package:share_app_latest/app/views/transfer_recovery/transfer_recovery_screen.dart';
import 'package:share_app_latest/components/transfer_progress_screen.dart';
import 'package:share_app_latest/app/views/splash/splash_screen.dart';
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
      page: () => const OnboardingScreen(),
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
      name: AppRoutes.chooseMethod,
      page: () => const ChooseMethod(),
      transition: Transition.fade,
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
      page: () => const PairingScreen(),
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
  ];
}
