import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_app_latest/components/select_device_name.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';
import '../../../controllers/pairing_controller.dart';
import '../../../controllers/QR_controller.dart';
import '../../../controllers/transfer_controller.dart';
import '../../../models/file_meta.dart';
import '../../../models/device_info.dart';
import '../../../../components/radar.dart';
import 'dart:math' as math;

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});
  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen>
    with TickerProviderStateMixin {
  final pairing = Get.put(PairingController());
  final transfer = Get.put(TransferController());
  bool _navigated = false;
  final nameCtrl = TextEditingController(text: 'Device');
  late AnimationController _radarCtrl;
  Timer? _discoveryTimer;
  bool _isReceiver = false;
  Worker? _devicesWorker;
  late Worker _offerWorker;
  bool _offerDialogShown = false; // Track if offer dialog is currently showing

  void _maybeNavigateToSelectDevice() {
    if (!mounted) return;
    if (_navigated) return;
    if (pairing.devices.isEmpty) return;
    _navigated = true;
    // Stop periodic discovery so radar/scanning stops and we don't re-scan in background
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Get.to(
        () => SelectDeviceScreen(
          devices: pairing.devices.toList(),
          isReceiver: _isReceiver,
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();

    final args = Get.arguments as Map<String, dynamic>?;
    _isReceiver = args?['isReceiver'] as bool? ?? false;

    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    pairing.devices.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _askPermissions();
      // Free port 7070 and clear QR state so Wi‑Fi Direct flow can use it
      final qrController = Get.find<QrController>();
      await qrController.stopServer();
      await qrController.stopP2P();
      qrController.devices.clear();
      qrController.incomingOffer.value = null;
      qrController.incomingPairingRequest.value = null;
      await pairing.startServer();
      pairing.discover();
      // Periodic discovery so receiver gets sender reliably (mergeResults: true)
      _discoveryTimer?.cancel();
      _discoveryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!mounted || _navigated) return;
        if (pairing.isScanning.value) return;
        pairing.discover(mergeResults: true);
      });
    });

    // ✅ Device detection worker
    _devicesWorker = ever(pairing.devices, (_) {
      _maybeNavigateToSelectDevice();
    });

    // ✅ Incoming offer worker (THIS FIXES YOUR ERROR)
    _offerWorker = ever(pairing.incomingOffer, (offer) {
      if (offer != null && mounted && !_offerDialogShown) {
        _showIncomingOfferDialog(offer);
      }
    });
  }

  void pairWithDevice(DeviceInfo device) async {
    try {
      print(
        '🔄 Starting pairing process with device: ${device.name} at ${device.ip}',
      );

      if (device.ip.isEmpty) {
        print('❌ Error: Device IP is empty');
        Get.snackbar('Error', 'Device IP is not available');
        return;
      }

      final args = Get.arguments as Map<String, dynamic>?;
      final isReceiver = args?['isReceiver'] as bool? ?? false;

      await pairing.startServer();
      print('✅ WebSocket server started');

      if (!isReceiver) {
        print('🔄 WiFi sender: navigating to TransferFileScreen');
        AppNavigator.toTransferFile(device: device);
      } else {
        print('🔄 WiFi receiver: starting transfer server');
        final transferController = Get.find<TransferController>();
        await transferController.startServer();
        Get.snackbar(
          'Ready to Receive',
          'Device is ready to receive files. Wait for transfer offers.',
          backgroundColor: Colors.blue.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      print('❌ Pairing failed: $e');
      Get.snackbar(
        'Pairing Failed',
        'Failed to start pairing process: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _askPermissions() async {
    await [
      Permission.storage,
      Permission.photos,
      Permission.videos,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  @override
  void dispose() {
    _devicesWorker?.dispose();
    _devicesWorker = null;
    _offerWorker.dispose();
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _radarCtrl.dispose();
    nameCtrl.dispose();
    // Free port 7070 and clear state so QR flow can use it when user switches
    pairing.stopServer();
    pairing.devices.clear();
    pairing.incomingOffer.value = null;
    super.dispose();
  }

  // void _showIncomingOfferDialog(Map<String, dynamic> offer) {
  //   // Prevent showing multiple dialogs
  //   if (_offerDialogShown) {
  //     print('⚠️ Offer dialog already showing, skipping...');
  //     return;
  //   }

  //   final ip = offer['fromIp'] as String;
  //   final meta = FileMeta.fromJson(offer['meta'] as Map<String, dynamic>);

  //   _offerDialogShown = true;
  //   Get.dialog(
  //     AlertDialog(
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Column(children: [Lottie.asset('assets/lottie/wifi.json')]),
  //           Text('Incoming File Transfer'),
  //           const SizedBox(height: 8),
  //           Container(
  //             decoration: BoxDecoration(
  //               color: Colors.grey.shade200,
  //               borderRadius: BorderRadius.circular(10),
  //             ),

  //             child: Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 Image.asset(
  //                   'assets/icons/document_image.png',
  //                   width: 50,
  //                   height: 50,
  //                 ),
  //                 Column(
  //                   children: [
  //                     Text(meta.name),
  //                     SizedBox(height: 8),
  //                     Text(meta.size.toString()),
  //                   ],
  //                 ),
  //               ],
  //             ),
  //           ),
  //           // Text('Size: ${_formatFileSize(meta.size)}'),
  //           const SizedBox(height: 16),
  //           const Text(
  //             'Do you want to accept this file?',
  //             style: TextStyle(fontSize: 14, color: Colors.grey),
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () {
  //             print('❌ User rejected file transfer from $ip');
  //             _offerDialogShown = false;
  //             pairing.respondToOffer(ip, false);
  //             Get.back();
  //           },
  //           child: const Text('Reject', style: TextStyle(color: Colors.red)),
  //         ),
  //         ElevatedButton(
  //           onPressed: () async {
  //             print('✅ User accepted file transfer from $ip');
  //             _offerDialogShown = false;
  //             pairing.respondToOffer(ip, true);
  //             Get.back();

  //             // Start transfer server so we can accept the incoming connection
  //             print('🔄 Starting transfer server for receiver...');
  //             final transferController = Get.find<TransferController>();
  //             await transferController.startServer();

  //             // Build sender device info for progress screen (receiver only has fromIp)
  //             final senderDevice = DeviceInfo(
  //               name: 'Sender',
  //               ip: ip,
  //               wsPort: 7070,
  //               transferPort: 9090,
  //             );

  //             // Navigate to TransferProgressScreen (receiver mode) for real-time progress
  //             transfer.progress.reset();
  //             await AppNavigator.toTransferProgress(
  //               device: senderDevice,
  //               filePath: '',
  //               fileName: meta.name,
  //             );
  //           },
  //           child: const Text('Accept'),
  //         ),
  //       ],
  //     ),
  //     barrierDismissible: false, // Prevent dismissing bfy tapping outside
  //   );
  // }
  void _showIncomingOfferDialog(Map<String, dynamic> offer) {
    if (_offerDialogShown) {
      print('⚠️ Offer dialog already showing, skipping...');
      return;
    }

    final ip = offer['fromIp'] as String;
    final meta = FileMeta.fromJson(offer['meta'] as Map<String, dynamic>);

    _offerDialogShown = true;

    Get.dialog(
      Center(
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Optional Lottie animation
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF5DADE2),
                    child: Icon(Icons.phone_android, color: Colors.white),
                  ),
                  title: Text(meta.name),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Reject button
                    ElevatedButton(
                      onPressed: () {
                        print('❌ User rejected file transfer from $ip');
                        _offerDialogShown = false;
                        pairing.respondToOffer(ip, false);
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        'Reject',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),

                    // Accept button
                    ElevatedButton(
                      onPressed: () async {
                        print('✅ User accepted file transfer from $ip');
                        _offerDialogShown = false;
                        pairing.respondToOffer(ip, true);
                        Get.back();

                        // Start transfer server for receiver
                        final transferController =
                            Get.find<TransferController>();
                        await transferController.startServer();

                        final senderDevice = DeviceInfo(
                          name: 'Sender',
                          ip: ip,
                          wsPort: 7070,
                          transferPort: 9090,
                        );

                        transfer.progress.reset();
                        await AppNavigator.toTransferProgress(
                          device: senderDevice,
                          filePath: '',
                          fileName: meta.name,
                        );

                        Get.snackbar(
                          'Accepted',
                          'Accepted transfer from ${meta.name}',
                          backgroundColor: Colors.green.withOpacity(0.8),
                          colorText: Colors.white,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5DADE2),
                      ),
                      child: const Text(
                        'Accept',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Global incoming offer detection - works regardless of current step
    // This allows receivers to get offers immediately after pairing
    return Stack(
      children: [
        // Main content
        _buildMainContent(),
        // Overlay for incoming offer dialog
        // Obx(() {
        //   final offer = pairing.incomingOffer.value;
        //   if (offer != null) {
        //     // Show dialog when offer is received (regardless of pairing status)
        //     // The receiver can receive offers even before pairing if their server is running
        //     print('🎯 Incoming offer detected, showing dialog...');
        //     WidgetsBinding.instance.addPostFrameCallback((_) {
        //       print('📱 Triggering offer dialog display');
        //       _showIncomingOfferDialog(offer);
        //     });
        //   }
        //   return const SizedBox.shrink();
        // }),
      ],
    );
  }

  Widget _buildMainContent() {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Text(
                      "Back",
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                StepProgressBar(
                  currentStep: 3,
                  totalSteps: kTransferFlowTotalSteps,
                  activeColor: Theme.of(context).colorScheme.primary,
                  inactiveColor: Colors.grey.shade300,
                  height: 6,
                  segmentSpacing: 5,
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                ),
                const SizedBox(height: 22),
                Text(
                  "Searching for nearby devices",
                  style: GoogleFonts.roboto(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "We are using out radar to catch devices near you. Be patient this may take little while",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Ensure both devices are on the same Wi-Fi. If you're receiving, open this screen first and wait; then send from the other device.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                // Radar Views
                SizedBox(height: 15),
                // Radar View
                AnimatedBuilder(
                  animation: _radarCtrl,
                  builder: (BuildContext context, Widget? child) {
                    return Obx(() {
                      final sweep = _radarCtrl.value * 2 * math.pi;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          RadarView(
                            size: 150,
                            devices: pairing.devices.toList(),
                            sweep: sweep,
                          ),
                          // Enhanced scanning animation overlay
                          AnimatedOpacity(
                            opacity: pairing.isScanning.value ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child:
                                pairing.isScanning.value
                                    ? Container(
                                      width: 160,
                                      height: 160,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            Colors.green.withOpacity(0.1),
                                            Colors.green.withOpacity(0.05),
                                            Colors.transparent,
                                          ],
                                          stops: const [0.0, 0.7, 1.0],
                                        ),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Pulsing rings animation
                                          ...List.generate(3, (index) {
                                            return AnimatedBuilder(
                                              animation: _radarCtrl,
                                              builder: (context, child) {
                                                final pulseProgress =
                                                    (_radarCtrl.value * 2 +
                                                        index * 0.3) %
                                                    1.0;
                                                final scale =
                                                    0.5 + pulseProgress * 0.5;
                                                return Transform.scale(
                                                  scale: scale,
                                                  child: Container(
                                                    width: 220,
                                                    height: 220,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Colors.green
                                                            .withOpacity(
                                                              (1.0 - pulseProgress) *
                                                                  0.3,
                                                            ),
                                                        width: 2,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          }),

                                          // Rotating radar sweep lines
                                          AnimatedBuilder(
                                            animation: _radarCtrl,
                                            builder: (context, child) {
                                              return Transform.rotate(
                                                angle:
                                                    _radarCtrl.value *
                                                    2 *
                                                    3.14159,
                                                child: Container(
                                                  width: 220,
                                                  height: 220,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: CustomPaint(
                                                    painter:
                                                        ScanningRadarPainter(
                                                          devices:
                                                              pairing.devices
                                                                  .toList(),
                                                          sweep: sweep,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),

                                          // Central pulsing dot
                                          AnimatedBuilder(
                                            animation: _radarCtrl,
                                            builder: (context, child) {
                                              final pulse =
                                                  (math.sin(
                                                        _radarCtrl.value *
                                                            4 *
                                                            3.14159,
                                                      ) +
                                                      1) /
                                                  2;
                                              return Container(
                                                width: 8 + pulse * 4,
                                                height: 8 + pulse * 4,
                                                decoration: BoxDecoration(
                                                  color: Colors.blue,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.blue
                                                          .withOpacity(0.6),
                                                      blurRadius: pulse * 8,
                                                      spreadRadius: pulse * 2,
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),

                                          // Scanning text with fade effect
                                        ],
                                      ),
                                    )
                                    : const SizedBox.shrink(),
                          ),
                        ],
                      );
                    });
                  },
                ),

                const SizedBox(height: 16),
                Obx(
                  () => ElevatedButton(
                    onPressed:
                        pairing.isScanning.value ? null : pairing.discover,
                    child:
                        pairing.isScanning.value
                            ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('Discovering...'),
                              ],
                            )
                            : const Text('Discover'),
                  ),
                ),

                const SizedBox(height: 16),

                // Discovered devices list
                // Expanded(
                //   child: Obx(
                //     () =>
                //         pairing.devices.isEmpty
                //             ? Center(
                //               child: Column(
                //                 mainAxisAlignment: MainAxisAlignment.center,
                //                 children: [
                //                   const Icon(
                //                     Icons.devices_other,
                //                     size: 64,
                //                     color: Colors.grey,
                //                   ),
                //                   const SizedBox(height: 16),
                //                   const Text(
                //                     'No devices found',
                //                     style: TextStyle(
                //                       fontSize: 18,
                //                       fontWeight: FontWeight.w500,
                //                       color: Colors.grey,
                //                     ),
                //                   ),
                //                   const SizedBox(height: 8),
                //                   const Text(
                //                     'Make sure both devices are on the same Wi-Fi network and running this app.',
                //                     textAlign: TextAlign.center,
                //                     style: TextStyle(color: Colors.grey),
                //                   ),
                //                   const SizedBox(height: 8),
                //                   const Text(
                //                     'Note: You need at least 2 devices to test pairing.',
                //                     textAlign: TextAlign.center,
                //                     style: TextStyle(
                //                       color: Colors.grey,
                //                       fontSize: 12,
                //                     ),
                //                   ),
                //                   const SizedBox(height: 24),
                //                   ElevatedButton.icon(
                //                     onPressed:
                //                         pairing.isScanning.value
                //                             ? null
                //                             : pairing.discover,
                //                     icon: const Icon(Icons.refresh),
                //                     label: const Text('Retry Discovery'),
                //                   ),
                //                 ],
                //               ),
                //             )
                //             : ListView.builder(
                //               itemCount: pairing.devices.length,
                //               itemBuilder: (context, index) {
                //                 final d = pairing.devices[index];
                //                 return Column(
                //                   children: [
                //                     Dismissible(
                //                       key: Key('device_${d.ip}_${index}'),
                //                       direction: DismissDirection.startToEnd,
                //                       background: Container(
                //                         margin: const EdgeInsets.symmetric(
                //                           vertical: 4,
                //                         ),
                //                         padding: const EdgeInsets.only(right: 20),
                //                         alignment: Alignment.centerRight,
                //                         decoration: BoxDecoration(
                //                           color: Colors.green,
                //                           borderRadius: BorderRadius.circular(16),
                //                         ),
                //                         child: const Icon(
                //                           Icons.delete,
                //                           color: Colors.white,
                //                         ),
                //                       ),
                //                       onDismissed: (direction) {
                //                         // Remove the device from the list
                //                         pairing.devices.removeAt(index);

                //                         // If no devices left, restart discovery automatically
                //                         if (pairing.devices.isEmpty) {
                //                           pairing.discover();
                //                         }

                //                         // Show snackbar feedback
                //                         Get.snackbar(
                //                           'Device Removed',
                //                           '${d.name} removed from list',
                //                           duration: const Duration(seconds: 2),
                //                         );
                //                       },
                //                       child: Card(
                //                         margin: const EdgeInsets.symmetric(
                //                           vertical: 4,
                //                         ),
                //                         child: ListTile(
                //                           leading: const Icon(
                //                             Icons.devices,
                //                             color: Colors.deepPurple,
                //                           ),
                //                           title: Text(d.name),
                //                           subtitle: Text('Device • Ready to pair'),
                //                           trailing: ElevatedButton(
                //                             onPressed: () => _pairWithDevice(d),
                //                             child: const Text('Pair'),
                //                           ),
                //                         ),
                //                       ),
                //                     ),

                //                     SizedBox(height: 20),
                //                     Text(
                //                       "Swipe left to right to reject the pairing request",
                //                       textAlign: TextAlign.center,
                //                       style: TextStyle(color: Colors.grey),
                //                     ),
                //                   ],
                //                 );
                //               },
                //             ),
                //   ),
                // ),
                // Expanded(
                //   child: Obx(
                //     () => Center(
                //       child: Column(
                //         mainAxisAlignment: MainAxisAlignment.center,
                //         children: [
                //           const Icon(Icons.radar, size: 60, color: Colors.grey),
                //           const SizedBox(height: 14),
                //           Text(
                //             _isReceiver
                //                 ? "Waiting for sender..."
                //                 : (pairing.devices.isEmpty
                //                     ? "Searching for devices..."
                //                     : "Device found! Redirecting..."),
                //             style: GoogleFonts.roboto(
                //               fontSize: 16,
                //               fontWeight: FontWeight.w500,
                //               color: Colors.grey.shade700,
                //             ),
                //           ),
                //         ],
                //       ),
                //     ),
                //   ),
                // ),
                // Bluetooth devices
              ],
            ),
          ),
        ),
      ),
    );
  }
}
