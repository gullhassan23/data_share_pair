import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_app_latest/app/controllers/transfer_controller.dart';
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

class _QrSenderScannerScreenState extends State<QrSenderScannerScreen> {
  final hotspotController = Get.find<HotspotController>();
  // final fileTransferController = Get.find<FileTransferController>();
  final fileTransferController = Get.find<TransferController>();
  final qrController = Get.find<QrController>();

  late final MobileScannerController cameraController;
  bool _isProcessing = false;
  bool _dialogShown = false;
  String _processingStatus = '';
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    print('📷 QrSenderScannerScreen initialized');
    qrController.flowState.value = TransferFlowState.idle;
    _initializeCamera();

    // Note: Progress dialog is shown in _startFileTransfer and closed after all files are sent.
  }

  Future<void> _initializeCamera() async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (status.isGranted) {
      cameraController = MobileScannerController();
      setState(() {
        _hasPermission = true;
      });
    } else {
      Get.snackbar(
        'Camera Permission Required',
        'Please grant camera permission to scan QR codes',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      Get.back(); // Go back if no permission
    }
  }

  @override
  void dispose() {
    if (_hasPermission) {
      cameraController.dispose();
    }
    super.dispose();
  }

  void _onQrCodeDetected(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      if (barcode.rawValue != null) {
        _processQrCode(barcode.rawValue!);
      }
    }
  }

  Future<void> _processQrCode(String qrData) async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 500); // 500 ms
    }
    if (_dialogShown) return; // Already showing a dialog, ignore
    _dialogShown = true; // Mark dialog as showing
    setState(() {
      _isProcessing = true;
      _processingStatus = 'Parsing QR code...';
    });

    try {
      // Parse QR code data - should contain receiver's connection info
      print('[QR] Sender: raw qrData = $qrData');
      final hotspotInfo = hotspotController.parseQrCodeData(qrData);

      if (hotspotInfo == null) {
        Get.snackbar(
          'Invalid QR Code',
          'This QR code does not contain valid connection information.',
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        _dialogShown = false;
        setState(() => _isProcessing = false);
        return;
      }

      if (hotspotInfo.ip.isEmpty) {
        Get.snackbar(
          'Invalid QR Code',
          'QR code has no IP address. Ensure the receiver is connected to Wi-Fi and try again.',
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        _dialogShown = false;
        setState(() => _isProcessing = false);
        return;
      }

      // Do NOT try to programmatically connect to Wi-Fi/hotspot on modern Android.
      // Instead, use the QR data (IP/port) for discovery and pairing. Show receiver card,
      // and only start TCP transfer when user explicitly taps the device.
      final displayName =
          hotspotInfo.deviceName.trim().isNotEmpty
              ? hotspotInfo.deviceName.trim()
              : null;
      setState(
        () =>
            _processingStatus =
                displayName != null
                    ? 'Resolving receiver on $displayName...'
                    : 'Resolving receiver…',
      );

      print(
        '[QR] Sender: parsed hotspotInfo ip=${hotspotInfo.ip} '
        'port=${hotspotInfo.port} deviceName=${hotspotInfo.deviceName}',
      );

      final tempDevice = DeviceInfo(
        name: displayName ?? 'Unknown',
        ip: hotspotInfo.ip,
        wsPort: 7070, // Default PairingController port
        transferPort: hotspotInfo.port,
      );

      // Handshake: send pairing_request and wait for receiver to accept.
      // After accept: only navigate to TransferFileScreen. No file dialog, no sendOffer here.
      print(
        '[QR] Sender: calling requestPairing to '
        '${tempDevice.ip}:${tempDevice.wsPort} (transferPort=${tempDevice.transferPort})',
      );
      final pairingAccepted = await qrController.requestPairing(tempDevice);
      print('[QR] Sender: requestPairing result = $pairingAccepted');
      if (!pairingAccepted) {
        _dialogShown = false;
        setState(() => _isProcessing = false);
        final message =
            Platform.isIOS
                ? 'Ensure both devices are on the same Wi-Fi and that you allowed Local Network access when prompted.'
                : 'The receiver did not accept pairing or the request timed out. Try again.';
        Get.snackbar(
          'Pairing Failed',
          message,
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
        );
        return;
      }

      final receiver = qrController.devices.firstWhereOrNull(
        (d) => d.ip == hotspotInfo.ip,
      );

      setState(() => _isProcessing = false);
      _dialogShown = false;

      if (receiver != null) {
        print(
          '[QR] Sender: receiver found after pairing '
          'name=${receiver.name} ip=${receiver.ip} wsPort=${receiver.wsPort} '
          'transferPort=${receiver.transferPort}',
        );
        // Pairing only: set flow state and remember receiver so user can
        // reopen file picker from scanner screen if they cancel later.
        qrController.flowState.value = TransferFlowState.paired;
        qrController.lastPairedReceiver.value = receiver;
        Get.back();
        AppNavigator.toTransferFile(device: receiver);
      } else {
        // Edge case: pairing accepted but receiver not in devices list
        print(
          '[QR] Sender: pairingAccepted=$pairingAccepted but receiver not found '
          'in qrController.devices for ip=${hotspotInfo.ip}. '
          'Devices list=${qrController.devices.map((d) => '${d.name}@${d.ip}:${d.wsPort}').toList()}',
        );
        Get.snackbar(
          'Receiver Not Found',
          'Pairing was accepted but the receiver could not be found. Try again.',
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      _dialogShown = false;
      setState(() => _isProcessing = false);
      Get.back(); // Close any open dialogs
      Get.snackbar(
        'Error',
        'Failed to process QR code: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Scan QR to Send Files',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body:
          !_hasPermission
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  MobileScanner(
                    controller: cameraController,
                    onDetect: _onQrCodeDetected,
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
                              'Scan the receiver’s QR code',
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Scan the receiver’s QR code to start file transfer',
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
                  ...(_isProcessing
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
                                  _processingStatus,
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
