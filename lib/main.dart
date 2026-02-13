import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_app_latest/routes/app_pages.dart';
import 'package:share_app_latest/routes/app_routes.dart';
import 'package:share_app_latest/app/controllers/pairing_controller.dart';
import 'package:share_app_latest/app/controllers/transfer_controller.dart';
import 'package:share_app_latest/app/controllers/progress_controller.dart';
import 'package:share_app_latest/app/controllers/bluetooth_controller.dart';

void main() {
  // Initialize controllers globally so they persist across screens
  Get.put(PairingController(), permanent: true);
  Get.put(TransferController(), permanent: true);
  Get.put(ProgressController(), permanent: true);
  Get.put(BluetoothController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Share-It',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // GETX ROUTING
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
    );
  }
}
