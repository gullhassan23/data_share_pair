import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_app_latest/routes/app_navigator.dart';

import 'package:vibration/vibration.dart';
import '../../../controllers/hotspot_controller.dart';

import '../../../controllers/QR_controller.dart';
import '../../../models/device_info.dart';

import 'package:permission_handler/permission_handler.dart';

class QrSenderScannerScreen extends StatefulWidget {
  final List<String> selectedFiles;

  const QrSenderScannerScreen({super.key, required this.selectedFiles});

  @override
  State<QrSenderScannerScreen> createState() => _QrSenderScannerScreenState();
}

class QrSenderScannerController extends GetxController {
  QrSenderScannerController({
    required this.hotspotController,
    required this.qrController,
  });

  final HotspotController hotspotController;
  final QrController qrController;

  MobileScannerController? cameraController;
  final isProcessing = false.obs;
  final dialogShown = false.obs;
  final processingStatus = ''.obs;
  final hasPermission = false.obs;

  @override
  void onClose() {
    cameraController?.dispose();
    super.onClose();
  }

  Future<void> initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      cameraController = MobileScannerController();
      hasPermission.value = true;
      return;
    }

    Get.snackbar(
      'Camera Access Needed',
      'Allow camera access to scan QR codes and connect devices.',
      backgroundColor: Colors.red.withOpacity(0.8),
      colorText: Colors.white,
    );
    Get.back();
  }

  void onQrCodeDetected(BarcodeCapture capture) {
    if (isProcessing.value) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      if (barcode.rawValue != null) {
        processQrCode(barcode.rawValue!);
      }
    }
  }

  Future<void> processQrCode(String qrData) async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 500);
    }
    if (dialogShown.value) return;
    dialogShown.value = true;
    isProcessing.value = true;
    processingStatus.value = 'Reading QR code...';

    try {
      print('[QR] Sender: raw qrData = $qrData');
      final hotspotInfo = hotspotController.parseQrCodeData(qrData);

      if (hotspotInfo == null) {
        Get.snackbar(
          'Invalid QR Code',
          'This QR code is not recognized. Please scan the QR code from the receiver device.',
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        dialogShown.value = false;
        isProcessing.value = false;
        return;
      }

      if (hotspotInfo.ip.isEmpty) {
        Get.snackbar(
          'Invalid QR Code',
          'Receiver is not ready. Ensure both devices are on the same Wi-Fi and try again.',
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        dialogShown.value = false;
        isProcessing.value = false;
        return;
      }

      final displayName =
          hotspotInfo.deviceName.trim().isNotEmpty
              ? hotspotInfo.deviceName.trim()
              : null;
      processingStatus.value =
          displayName != null
              ? 'Connecting to $displayName...'
              : 'Establishing secure connection...';

      print(
        '[QR] Sender: parsed hotspotInfo ip=${hotspotInfo.ip} '
        'port=${hotspotInfo.port} deviceName=${hotspotInfo.deviceName}',
      );

      final tempDevice = DeviceInfo(
        name: displayName ?? 'Unknown',
        ip: hotspotInfo.ip,
        wsPort: 7070,
        transferPort: hotspotInfo.port,
      );

      print(
        '[QR] Sender: calling requestPairing to '
        '${tempDevice.ip}:${tempDevice.wsPort} (transferPort=${tempDevice.transferPort})',
      );
      final pairingAccepted = await qrController.requestPairing(tempDevice);
      print('[QR] Sender: requestPairing result = $pairingAccepted');
      if (!pairingAccepted) {
        dialogShown.value = false;
        isProcessing.value = false;
        final message =
            Platform.isIOS
                ? 'Make sure both devices are on the same Wi-Fi and Local Network permission is enabled.'
                : 'Could not connect to the receiver. Make sure both devices are on the same Wi-Fi and try again.';
        Get.snackbar(
          'Connection Failed',
          message,
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
        );
        return;
      }

      final receiver = qrController.devices.firstWhereOrNull(
        (d) => d.ip == hotspotInfo.ip,
      );

      isProcessing.value = false;
      dialogShown.value = false;

      if (receiver != null) {
        print(
          '[QR] Sender: receiver found after pairing '
          'name=${receiver.name} ip=${receiver.ip} wsPort=${receiver.wsPort} '
          'transferPort=${receiver.transferPort}',
        );
        qrController.flowState.value = TransferFlowState.paired;
        qrController.lastPairedReceiver.value = receiver;
        Get.back();
        AppNavigator.toTransferFile(device: receiver);
      } else {
        print(
          '[QR] Sender: pairingAccepted=$pairingAccepted but receiver not found '
          'in qrController.devices for ip=${hotspotInfo.ip}. '
          'Devices list=${qrController.devices.map((d) => '${d.name}@${d.ip}:${d.wsPort}').toList()}',
        );
        Get.snackbar(
          'Connection Error',
          'Receiver not found after connection. Please scan again.',
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      dialogShown.value = false;
      isProcessing.value = false;
      Get.back();
      Get.snackbar(
        'Error',
        'Failed to process QR code: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }
}

class _QrSenderScannerScreenState extends State<QrSenderScannerScreen> {
  late final QrSenderScannerController screenController;
  late final String controllerTag;

  @override
  void initState() {
    super.initState();
    print('📷 QrSenderScannerScreen initialized');
    controllerTag = 'qr_sender_scanner_${UniqueKey()}';
    final qrController = Get.find<QrController>();
    qrController.flowState.value = TransferFlowState.idle;
    screenController = Get.put(
      QrSenderScannerController(
        hotspotController: Get.find<HotspotController>(),
        qrController: qrController,
      ),
      tag: controllerTag,
    );
    screenController.initializeCamera();
  }

  @override
  void dispose() {
    if (Get.isRegistered<QrSenderScannerController>(tag: controllerTag)) {
      Get.delete<QrSenderScannerController>(tag: controllerTag);
    }
    super.dispose();
  }
  // Future<void> _startFileTransfer(HotspotInfo receiverInfo) async {
  //   try {
  //     for (final filePath in widget.selectedFiles) {
  //       final success = await fileTransferController.sendFile(
  //         filePath,
  //         receiverInfo.ip,
  //         receiverInfo.port,
  //       );

  //       if (!success) {
  //         Get.snackbar(
  //           'Transfer Failed',
  //           'Failed to send file: ${filePath.split('/').last}',
  //           backgroundColor: Colors.red.withOpacity(0.8),
  //           colorText: Colors.white,
  //         );

  //         break;
  //       }
  //     }

  //     // All files sent successfully - transfer progress screen will handle navigation
  //     Get.snackbar(
  //       'Transfer Complete',
  //       'All files sent successfully!',
  //       backgroundColor: Colors.green.withOpacity(0.8),
  //       colorText: Colors.white,
  //       duration: const Duration(seconds: 3),
  //     );
  //   } catch (e) {
  //     Get.snackbar(
  //       'Transfer Error',
  //       'Failed to send files: $e',
  //       backgroundColor: Colors.red.withOpacity(0.8),
  //       colorText: Colors.white,
  //     );

  //     print('Failed to send files: $e');
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    print('🎨 QrSenderScannerScreen building...');
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Get.back(),
          ),
          title: Text(
            'Scan to Connect',
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontSize: 24,
            ),
          ),
          centerTitle: true,
        ),
        body:
            !screenController.hasPermission.value
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                  children: [
                    MobileScanner(
                      controller: screenController.cameraController!,
                      onDetect: screenController.onQrCodeDetected,
                    ),
                    Column(
                      children: [
                        Container(
                          width: double.infinity,
                          color: Colors.black.withOpacity(0.78),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Connect to Receiver',
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Make sure both devices are connected to the same Wi-Fi network. Then scan the QR code shown on the receiver device to continue.',
                                style: GoogleFonts.roboto(
                                  color: Colors.white70,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 300,
                              height: 300,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                ),
                              ),
                              child: Stack(
                                children: const [
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    child: _ScanCorner(isTop: true, isLeft: true),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: _ScanCorner(
                                      isTop: true,
                                      isLeft: false,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    child: _ScanCorner(
                                      isTop: false,
                                      isLeft: true,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: _ScanCorner(
                                      isTop: false,
                                      isLeft: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Container(
                      //   width: double.infinity,
                      //   color: Colors.black.withOpacity(0.78),
                      //   padding: const EdgeInsets.symmetric(
                      //     horizontal: 20,
                      //     vertical: 16,
                      //   ),
                      //   child: SafeArea(
                      //     top: false,
                      //     child: Column(
                      //       mainAxisSize: MainAxisSize.min,
                      //       children: [
                      //         Row(
                      //           mainAxisAlignment:
                      //               MainAxisAlignment.spaceAround,
                      //           children: [
                      //             _bottomAction(
                      //               icon: Icons.dialpad,
                      //               label: 'Enter Till\nNumber',
                      //               onTap: () {},
                      //             ),
                      //             _bottomAction(
                      //               icon: Icons.flashlight_on,
                      //               label: 'Torch',
                      //               onTap: () => cameraController.toggleTorch(),
                      //             ),
                      //             _bottomAction(
                      //               icon: Icons.image,
                      //               label: 'Scan from\nGallery',
                      //               onTap: () {},
                      //             ),
                      //             _bottomAction(
                      //               icon: Icons.more_horiz,
                      //               label: 'More',
                      //               onTap: () => Get.back(),
                      //             ),
                      //           ],
                      //         ),
                      //         const SizedBox(height: 10),
                      //         Obx(() {
                      //           final canReopen =
                      //               fileTransferController
                      //                   .canReopenPicker
                      //                   .value;
                      //           final device =
                      //               qrController.lastPairedReceiver.value;
                      //           if (!canReopen || device == null) {
                      //             return const SizedBox.shrink();
                      //           }
                      //           return TextButton(
                      //             onPressed:
                      //                 () => AppNavigator.toTransferFile(
                      //                   device: device,
                      //                 ),
                      //             child: Text(
                      //               'Pick file again',
                      //               style: GoogleFonts.roboto(
                      //                 color: Colors.white,
                      //                 fontSize: 13,
                      //                 fontWeight: FontWeight.w500,
                      //               ),
                      //             ),
                      //           );
                      //         }),
                      //       ],
                      //     ),
                      //   ),
                      // ),
                      ],
                    ),
                    ...(screenController.isProcessing.value
                        ? [
                          Container(
                            color: Colors.black.withOpacity(0.8),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    screenController.processingStatus.value,
                                    style: GoogleFonts.roboto(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ]
                        : []),
                  ],
                ),
      ),
    );
  }
}

class _ScanCorner extends StatelessWidget {
  final bool isTop;
  final bool isLeft;

  const _ScanCorner({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(painter: _CornerPainter(isTop: isTop, isLeft: isLeft)),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;

  _CornerPainter({required this.isTop, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = const Color(0xFF00E676)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final path = Path();
    final xStart = isLeft ? 0.0 : size.width;
    final xMid = isLeft ? size.width : 0.0;
    final yStart = isTop ? 0.0 : size.height;
    final yMid = isTop ? size.height : 0.0;

    path.moveTo(xStart, yMid);
    path.lineTo(xStart, yStart);
    path.lineTo(xMid, yStart);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
