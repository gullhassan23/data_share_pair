import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:share_app_latest/app/controllers/QR_controller.dart';
import 'package:share_app_latest/app/controllers/hotspot_controller.dart';
import 'package:share_app_latest/app/controllers/pairing_controller.dart';
import 'package:share_app_latest/app/controllers/transfer_controller.dart';
import 'package:share_app_latest/app/controllers/progress_controller.dart';
import 'package:share_app_latest/app/controllers/bluetooth_controller.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/routes/app_pages.dart';
import 'package:share_app_latest/routes/app_routes.dart';
import 'package:share_app_latest/services/transfer_foreground_service.dart';
import 'package:share_app_latest/services/fcm_token_service.dart';
import 'package:share_app_latest/services/subscription_iap_service.dart';
import 'package:share_app_latest/services/admob_service.dart';
import 'package:share_app_latest/services/premium_status_store.dart';
import 'package:share_app_latest/services/adapty_service.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/routes/app_navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await Firebase.initializeApp();
  await initializeFcmAndUploadToken();

  // Load cached premium status (if any) so ads respect Pro immediately.
  final cachedPremium = await PremiumStatusStore.loadIsPremium();
  if (cachedPremium != null) {
    SubscriptionIAPService().setCachedPremium(cachedPremium);
  }

  await SubscriptionIAPService().init();
  await AdaptyService.instance.init();
  await AdMobService.initialize();
  AdMobService.instance.loadAppOpenAd();
  AdMobService.instance.maybePreloadInterstitial();
  AdMobService.instance.maybePreloadRewarded();

  // Restrict to portrait only
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Initialize foreground task plugin before runApp (required for transfer notifications)
  TransferForegroundService.init();

  // Initialize controllers globally so they persist across screens
  Get.put(PairingController(), permanent: true);
  Get.put(TransferController(), permanent: true);
  Get.put(ProgressController(), permanent: true);
  Get.put(BluetoothController(), permanent: true);

  Get.put(QrController(), permanent: true);

  // Start listening to Firestore subscription status as soon as app launches,
  // so premium cache stays in sync with backend on every open/renewal.
  Get.put(PremiumController(), permanent: true);

  Get.put(HotspotController(), permanent: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Share-It',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
      builder: (context, child) => _TransferLifecycleWrapper(child: child!),
    );
  }
}

/// When app resumes and a transfer is in progress, navigates to transfer progress screen.
class _TransferLifecycleWrapper extends StatefulWidget {
  const _TransferLifecycleWrapper({required this.child});

  final Widget child;

  @override
  State<_TransferLifecycleWrapper> createState() =>
      _TransferLifecycleWrapperState();
}

class _TransferLifecycleWrapperState extends State<_TransferLifecycleWrapper>
    with WidgetsBindingObserver {
  bool _firstFrameDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_firstFrameDone && mounted) {
        _firstFrameDone = true;
        AdMobService.instance.showAppOpenIfAvailable();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  Future<void> _onResumed() async {
    AdMobService.instance.showAppOpenIfAvailable(minInterval: const Duration(seconds: 45));
    if (!Get.isRegistered<TransferController>()) return;
    final transfer = Get.find<TransferController>();
    if (transfer.sessionState.value != TransferSessionState.transferring)
      return;
    final currentRoute = Get.currentRoute;
    if (currentRoute == AppRoutes.transferProgress) return;
    await AppNavigator.toTransferProgressResume();
  }
}
