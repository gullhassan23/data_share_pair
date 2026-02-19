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

  // Future<void> _processQrCode(String qrData) async {
  //   if (await Vibration.hasVibrator()) {
  //     Vibration.vibrate(duration: 500); // 500 ms
  //   }
  //   if (_dialogShown) return; // Already showing a dialog, ignore
  //   _dialogShown = true; // Mark dialog as showing
  //   setState(() {
  //     _isProcessing = true;
  //     _processingStatus = 'Parsing QR code...';
  //   });

  //   try {
  //     // Parse QR code data - should contain receiver's connection info
  //     final hotspotInfo = hotspotController.parseQrCodeData(qrData);

  //     if (hotspotInfo == null) {
  //       Get.snackbar(
  //         'Invalid QR Code',
  //         'This QR code does not contain valid connection information.',
  //         backgroundColor: Colors.red.withOpacity(0.8),
  //         colorText: Colors.white,
  //       );
  //       _dialogShown = false;
  //       setState(() => _isProcessing = false);
  //       return;
  //     }

  //     if (hotspotInfo.ip.isEmpty) {
  //       Get.snackbar(
  //         'Invalid QR Code',
  //         'QR code has no IP address. Ensure the receiver is connected to Wi-Fi and try again.',
  //         backgroundColor: Colors.red.withOpacity(0.8),
  //         colorText: Colors.white,
  //       );
  //       _dialogShown = false;
  //       setState(() => _isProcessing = false);
  //       return;
  //     }

  //     // Do NOT try to programmatically connect to Wi-Fi/hotspot on modern Android.
  //     // Instead, use the QR data (IP/port) for discovery and pairing. Show receiver card,
  //     // and only start TCP transfer when user explicitly taps the device.
  //     final displayName =
  //         hotspotInfo.deviceName.trim().isNotEmpty
  //             ? hotspotInfo.deviceName.trim()
  //             : null;
  //     setState(
  //       () =>
  //           _processingStatus =
  //               displayName != null
  //                   ? 'Resolving receiver on $displayName...'
  //                   : 'Resolving receiver…',
  //     );

  //     final tempDevice = DeviceInfo(
  //       name: displayName ?? 'Unknown',
  //       ip: hotspotInfo.ip,
  //       wsPort: 7070, // Default PairingController port
  //       transferPort: hotspotInfo.port,
  //     );

  //     print('[QR] QR parsed ip=${hotspotInfo.ip} port=${hotspotInfo.port}');
  //     print('[QR] QR scan success, resolving receiver at ${hotspotInfo.ip}');
  //     await qrController.pairWith(tempDevice);
  //     final receiver = qrController.devices.firstWhereOrNull(
  //       (d) => d.ip == hotspotInfo.ip,
  //     );

  //     _isProcessing = false;

  //     if (receiver == null) {
  //       _dialogShown = false;
  //       print('[QR] pairWith failed (receiver null)');
  //       print('[QR] Pairing rejected or timed out, no navigation');
  //       Get.snackbar(
  //         'Pairing Declined',
  //         'The receiver did not accept pairing or the request timed out. Try again.',
  //         backgroundColor: Colors.orange.withOpacity(0.8),
  //         colorText: Colors.white,
  //       );
  //       return;
  //     }

  //     _dialogShown = false;
  //     print('[QR] pairWith success device=${receiver.name} ip=${receiver.ip}');
  //     if (widget.selectedFiles.isEmpty) {
  //       print(
  //         '[QR] Pairing accepted, navigating to TransferFileScreen for ${receiver.name}',
  //       );
  //       Get.back();
  //       AppNavigator.toTransferFile(device: receiver);
  //       return;
  //     }
  //     // Show confirmation dialog with receiver info; user taps Send to initiate offer
  //     Get.dialog(
  //       AlertDialog(
  //         title: Text('Send to ${receiver.name}?'),
  //         content: Text(
  //           'Send ${widget.selectedFiles.length} file(s) to ${receiver.name} (${receiver.ip})',
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Get.back();
  //             },
  //             child: const Text('Cancel'),
  //           ),
  //           ElevatedButton(
  //             onPressed: () async {
  //               Get.back();
  //               String targetIp = receiver.ip;

  //               // If the discovered device has a P2P hardware address (MAC), attempt native connect
  //               final looksLikeMac =
  //                   targetIp.contains(":") && targetIp.length >= 12;
  //               if (looksLikeMac) {
  //                 final ok = await qrController.connectToPeer(targetIp);
  //                 if (!ok) {
  //                   Get.snackbar(
  //                     'Connection Failed',
  //                     'Failed to establish P2P connection. Please try again.',
  //                     backgroundColor: Colors.red.withOpacity(0.8),
  //                     colorText: Colors.white,
  //                   );
  //                   return;
  //                 }

  //                 // Wait for native to provide groupOwner IP via EventChannel
  //                 String groupIp = '';
  //                 final timeout = DateTime.now().add(
  //                   const Duration(seconds: 10),
  //                 );
  //                 while (DateTime.now().isBefore(timeout)) {
  //                   if (qrController.wsDisplayIp.value.isNotEmpty) {
  //                     groupIp = qrController.wsDisplayIp.value;
  //                     break;
  //                   }
  //                   await Future.delayed(const Duration(milliseconds: 300));
  //                 }
  //                 if (groupIp.isEmpty) {
  //                   Get.snackbar(
  //                     'No IP Found',
  //                     'Could not obtain peer IP after P2P connect.',
  //                     backgroundColor: Colors.orange.withOpacity(0.8),
  //                     colorText: Colors.white,
  //                   );
  //                   return;
  //                 }
  //                 targetIp = groupIp;
  //               }

  //               final firstFile = widget.selectedFiles.first;
  //               final meta = FileMeta(
  //                 name: p.basename(firstFile),
  //                 size: await File(firstFile).length(),
  //                 type: 'file',
  //               );

  //               // Build a DeviceInfo with resolved IP
  //               final resolved = DeviceInfo(
  //                 name: receiver.name,
  //                 ip: targetIp,
  //                 wsPort: receiver.wsPort,
  //                 transferPort: receiver.transferPort,
  //               );
  //               print('📤 Sending offer to ${resolved.ip}:${resolved.wsPort}');
  //               print('[QR] sendOffer called from Qr_sender ip=${resolved.ip} wsPort=${resolved.wsPort}');
  //               final accepted = await qrController.sendOffer(resolved, meta);
  //               print('[QR] response received accepted=$accepted');
  //               print('📥 Offer accepted? $accepted');

  //               _dialogShown = false;
  //               if (accepted) {
  //                 await _startFileTransfer(
  //                   HotspotInfo(
  //                     ssid: receiver.name,
  //                     password: '',
  //                     ip: targetIp,
  //                     port: resolved.transferPort,
  //                     deviceName: receiver.name,
  //                   ),
  //                 );
  //               } else {
  //                 Get.snackbar(
  //                   'Offer Rejected',
  //                   'The receiver declined the file transfer.',
  //                   backgroundColor: Colors.orange.withOpacity(0.8),
  //                   colorText: Colors.white,
  //                 );
  //               }
  //             },
  //             child: const Text('Send'),
  //           ),
  //         ],
  //       ),
  //     );
  //   } catch (e) {
  //     _dialogShown = false;
  //     Get.back(); // Close any open dialogs
  //     Get.snackbar(
  //       'Error',
  //       'Failed to process QR code: $e',
  //       backgroundColor: Colors.red.withOpacity(0.8),
  //       colorText: Colors.white,
  //     );
  //     setState(() => _isProcessing = false);
  //   }
  // }

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

      final tempDevice = DeviceInfo(
        name: displayName ?? 'Unknown',
        ip: hotspotInfo.ip,
        wsPort: 7070, // Default PairingController port
        transferPort: hotspotInfo.port,
      );

      // Handshake: send pairing_request and wait for receiver to accept.
      // After accept: only navigate to TransferFileScreen. No file dialog, no sendOffer here.
      final pairingAccepted = await qrController.requestPairing(tempDevice);
      if (!pairingAccepted) {
        _dialogShown = false;
        setState(() => _isProcessing = false);
        Get.snackbar(
          'Pairing Declined',
          'The receiver did not accept pairing or the request timed out. Try again.',
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
        // Pairing only: set flow state and navigate. File selection and sendOffer happen on TransferFileScreen.
        qrController.flowState.value = TransferFlowState.paired;
        Get.back();
        AppNavigator.toTransferFile(device: receiver);
      } else {
        // Edge case: pairing accepted but receiver not in devices list
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
        title: Text(
          'Scan Receiver QR Code',
          style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions:
            _hasPermission
                ? [
                  IconButton(
                    icon: const Icon(Icons.flashlight_on),
                    onPressed: () => cameraController.toggleTorch(),
                  ),
                ]
                : null,
      ),
      body:
          !_hasPermission
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  // Camera Scanner
                  MobileScanner(
                    controller: cameraController,
                    onDetect: _onQrCodeDetected,
                  ),

                  // Overlay UI
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: Column(
                      children: [
                        // Top instructions
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Scan the receiver\'s QR code',
                                  style: GoogleFonts.roboto(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Point your camera at the QR code shown by the receiver',
                                  style: GoogleFonts.roboto(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Sending ${widget.selectedFiles.length} file${widget.selectedFiles.length > 1 ? 's' : ''}',
                                    style: GoogleFonts.roboto(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Scanner frame
                        Expanded(
                          flex: 3,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 40),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        // Bottom instructions
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Make sure the QR code is well lit and in focus',
                                  style: GoogleFonts.roboto(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () => Get.back(),
                                  icon: const Icon(Icons.cancel),
                                  label: const Text('Cancel'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.withOpacity(
                                      0.8,
                                    ),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
