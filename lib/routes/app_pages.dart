import 'package:get/get.dart';
import 'package:share_app_latest/app/views/auth/login/login.dart';
import 'package:share_app_latest/app/views/auth/sign_up/signup.dart';
import 'package:share_app_latest/app/views/home/choose_file/choose_mode_screen.dart';
import 'package:share_app_latest/app/views/home/choose_file/transfer_file/transfer_file_screen.dart';

import 'package:share_app_latest/app/views/home/home_screen.dart';
import 'package:share_app_latest/app/views/home/pairing/pairing_page.dart';
import 'package:share_app_latest/app/views/home/received_files_screen.dart';
import 'package:share_app_latest/app/views/onboarding/onboarding_screen.dart';
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
      name: AppRoutes.home,
      page: () => const HomeScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.pairing,
      page: () => const PairingScreen(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: AppRoutes.chooseFile,
      page: () => ChooseModeScreen(),
      transition: Transition.rightToLeft,
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
      name: AppRoutes.receivedFiles,
      page: () => const ReceivedFilesScreen(),
      transition: Transition.rightToLeft,
    ),
  ];
}
