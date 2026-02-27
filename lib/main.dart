import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_app_latest/app/controllers/QR_controller.dart';
import 'package:share_app_latest/app/controllers/hotspot_controller.dart';
import 'package:share_app_latest/routes/app_pages.dart';
import 'package:share_app_latest/routes/app_routes.dart';
import 'package:share_app_latest/app/controllers/pairing_controller.dart';
import 'package:share_app_latest/app/controllers/transfer_controller.dart';
import 'package:share_app_latest/app/controllers/progress_controller.dart';
import 'package:share_app_latest/app/controllers/bluetooth_controller.dart';
import 'package:share_app_latest/services/transfer_foreground_service.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/routes/app_navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    if (state != AppLifecycleState.resumed) return;
    _onResumed();
  }

  Future<void> _onResumed() async {
    if (!Get.isRegistered<TransferController>()) return;
    final transfer = Get.find<TransferController>();
    if (transfer.sessionState.value != TransferSessionState.transferring) return;
    final currentRoute = Get.currentRoute;
    if (currentRoute == AppRoutes.transferProgress) return;
    await AppNavigator.toTransferProgressResume();
  }
}
