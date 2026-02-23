import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:share_app_latest/app/controllers/bluetooth_controller.dart';

import 'package:share_app_latest/components/select_device_name.dart';
import 'package:share_app_latest/utils/constants.dart';

import 'package:share_app_latest/utils/permissions.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';

class BluetoothSenderScreen extends StatefulWidget {
  const BluetoothSenderScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothSenderScreen> createState() => _BluetoothSenderScreenState();
}

class _BluetoothSenderScreenState extends State<BluetoothSenderScreen> {
  late final BluetoothController bluetooth;
  bool _navigated = false;
  Worker? _devicesWorker;

  void _maybeNavigateToSelectDevice() {
    if (!mounted) return;
    if (_navigated) return;
    if (bluetooth.devices.isEmpty) return;

    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Bluetooth list comes from bluetooth.devices in SelectDeviceScreen; pass empty list.
      Get.to(
        () => SelectDeviceScreen(
          devices: const [],
          isBluetooth: true,
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    bluetooth = Get.put(BluetoothController(), tag: "sender");

    // Watch for scanned devices and navigate when at least one is found
    _devicesWorker = ever(
      bluetooth.devices,
      (_) => _maybeNavigateToSelectDevice(),
    );

    // Request permissions and start scanning
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final granted = await askPermissions();
      if (!granted) {
        bluetooth.error.value = 'Bluetooth permission denied';
        return;
      }
      await bluetooth.startScan();
    });
  }

  @override
  void dispose() {
    _devicesWorker?.dispose();
    bluetooth.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xffEEF4FF), Color(0xffF8FAFF), Color(0xffFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              const SizedBox(height: 19),

              /// Back Row
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Get.back();
                    },
                    icon: Icon(Icons.arrow_back),
                  ),
                  SizedBox(width: 5),
                  Text("Back"),
                ],
              ),

              /// Progress Barss
              StepProgressBar(
                currentStep: 3,
                totalSteps: kTransferFlowTotalSteps,
                activeColor: Colors.blue,
                inactiveColor: Colors.white.withOpacity(0.6),
                height: 6,
                segmentSpacing: 5,
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),

              const SizedBox(height: 40),
              Text(
                'Send via Bluetooth',
                style: GoogleFonts.roboto(
                  color: Colors.blue,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Make sure the receiver has opened Receive via Bluetooth.',
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Main Content
              Expanded(
                child: Obx(() {
                  if (bluetooth.error.value.isNotEmpty) {
                    return _ErrorView(bluetooth.error.value);
                  }
                  if (bluetooth.isScanning.value) {
                    return _SearchingView(bluetooth);
                  }
                  if (bluetooth.devices.isEmpty) {
                    return _NoDevicesView();
                  }
                  // Scanned devices present → navigation happens in ever() listener
                  return Center(
                    child: Text(
                      'Device found! Redirecting...',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _ErrorView(String error) {
  return Center(
    child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 16)),
  );
}

Widget _SearchingView(BluetoothController bluetooth) {
  return Column(
    children: [
      const SizedBox(height: 40),
      Lottie.asset('assets/lottie/bluetooth.json', height: 150),
      const SizedBox(height: 16),
      Text(
        'Searching nearby Bluetooth devices...',
        style: GoogleFonts.roboto(color: Colors.black54),
      ),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: () => bluetooth.stopScan(),
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('Stop Scan'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange.shade700,
        ),
      ),
    ],
  );
}

Widget _NoDevicesView() {
  return Column(
    children: [
      const SizedBox(height: 40),
      const Icon(Icons.bluetooth_disabled, size: 80, color: Colors.grey),
      const SizedBox(height: 16),
      Text(
        'No Bluetooth devices found',
        style: GoogleFonts.roboto(color: Colors.black54),
      ),
    ],
  );
}

Widget DeviceList(
  List<BluetoothDevice> devices,
  BluetoothController bluetooth,
) {
  if (devices.isEmpty) {
    return _NoDevicesView();
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: OutlinedButton.icon(
          onPressed: () => bluetooth.stopScan(),
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Stop Scan'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange.shade700,
          ),
        ),
      ),
      // ListView.builder(
      //   shrinkWrap: true,
      //   physics: const NeverScrollableScrollPhysics(),
      //   itemCount: devices.length,
      //   itemBuilder: (context, i) {
      //     final device = devices[i];

      //     return Obx(() {
      //       // Rebuild when connection state changes (connectedDevice is the source of truth)
      //       final connected = bluetooth.isDeviceConnected(device);
      //       return Card(
      //         shape: RoundedRectangleBorder(
      //           borderRadius: BorderRadius.circular(16),
      //         ),
      //         margin: const EdgeInsets.symmetric(vertical: 8),
      //         child: ListTile(
      //           leading: Icon(
      //             Icons.bluetooth,
      //             color: connected ? Colors.green : null,
      //           ),
      //           title: Text(getDisplayName(device)),
      //           subtitle: Text(device.remoteId.str),
      //           trailing:
      //               connected
      //                   ? Row(
      //                     mainAxisSize: MainAxisSize.min,
      //                     children: [
      //                       IconButton(
      //                         icon: const Icon(Icons.link_off),
      //                         tooltip: 'Disconnect',
      //                         onPressed: () => bluetooth.disconnect(device),
      //                         style: IconButton.styleFrom(
      //                           foregroundColor: Colors.red.shade700,
      //                         ),
      //                       ),
      //                       const SizedBox(width: 4),
      //                       ElevatedButton(
      //                         onPressed: () {
      //                           showFileSelectionDialog(context);
      //                         },
      //                         style: ElevatedButton.styleFrom(
      //                           backgroundColor: Colors.green.shade700,
      //                           foregroundColor: Colors.white,
      //                           disabledBackgroundColor: Colors.green.shade300,
      //                           disabledForegroundColor: Colors.white,
      //                         ),
      //                         child: const Text("Connected"),
      //                       ),
      //                     ],
      //                   )
      //                   : ElevatedButton(
      //                     onPressed: () => bluetooth.connect(device),
      //                     child: const Text("Connect"),
      //                   ),
      //         ),
      //       );
      //     });
      //   },
      // ),
    ],
  );
}
