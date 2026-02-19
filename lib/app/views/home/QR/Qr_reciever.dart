import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:share_app_latest/app/controllers/transfer_controller.dart';
import 'package:share_app_latest/app/models/device_info.dart';
import 'package:share_app_latest/app/models/hotspot_info.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/show_uploadbar_dialogue.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';
import 'package:vibration/vibration.dart';

import '../../../controllers/hotspot_controller.dart';
import '../../../controllers/QR_controller.dart';
import '../../../../routes/app_navigator.dart';

class QrReceiverDisplayScreen extends StatefulWidget {
  const QrReceiverDisplayScreen({super.key});

  @override
  State<QrReceiverDisplayScreen> createState() =>
      _QrReceiverDisplayScreenState();
}

class _QrReceiverDisplayScreenState extends State<QrReceiverDisplayScreen> {
  final hotspotController = Get.put(HotspotController());
  final fileTransferController = Get.put(TransferController());
  final qrController = Get.find<QrController>();
  DeviceInfo? connectedDevice;
  bool _startupError = false;
  String _startupErrorMsg = '';
  bool _isInitializing = true;
  bool _pairingDialogShown = false;

  @override
  void initState() {
    super.initState();
    print('📱 QrReceiverDisplayScreen initialized');
    _initializeReceiving();

    // Listen for file transfer session state changes
    // ever(fileTransferController.sessionState, (TransferSessionState state) {

    //   if ((state == TransferSessionState.connected ||
    //           state == TransferSessionState.transferring) &&
    //       mounted) {
    //     // Once connected or transferring, move to progress screen
    //     AppNavigator.replaceWithTransferProgress(false);
    //   }
    // });

    // ever(fileTransferController.sessionState, (state) {
    //   if (state == TransferSessionState.completed && mounted) {
    //     // ✅ Success Snackbar
    //     Get.snackbar(
    //       'File Received',
    //       'File received successfully',
    //       snackPosition: SnackPosition.BOTTOM,
    //       backgroundColor: Colors.green.withOpacity(0.9),
    //       colorText: Colors.white,
    //       icon: const Icon(Icons.check_circle, color: Colors.white),
    //     );

    //     // ✅ Navigate to Receive Files Screen
    //     AppNavigator.toReceivedFiles();
    //     // if (connectedDevice != null) {
    //     //   // "!" laga kar force karein kyunke hum check kar chuke hain ke ye null nahi hai
    //     //   AppNavigator.toTransferFile(device: connectedDevice!);
    //     // } else {
    //     //   print("❌ Error: Device info not found for navigation");
    //     //   // Fallback agar device null ho (optional)
    //     //   // AppNavigator.toReceivedFiles();
    //     // }
    //   }
    // });
    ever(fileTransferController.sessionState, (state) {
      if (state == TransferSessionState.completed ||
          state == TransferSessionState.error) {
        if (Get.isDialogOpen ?? false) Get.back();
        if (Get.key.currentState?.canPop() ?? false) Get.back();
      }

      if (state == TransferSessionState.completed && mounted) {
        Get.snackbar(
          'File Received',
          'File received successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        AppNavigator.toReceivedFiles();
      }

      if (state == TransferSessionState.error) {
        Get.snackbar(
          'Error',
          'File transfer failed',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    });

    // Listen for incoming pairing requests (sender scanned our QR)
    ever(qrController.incomingPairingRequest, (request) {
      if (request != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && request == qrController.incomingPairingRequest.value) {
            _showIncomingPairDialog(request);
          }
        });
      }
    });

    // Listen for incoming file offers
    ever(qrController.incomingOffer, (offer) {
      if (offer != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && offer == qrController.incomingOffer.value) {
            print('[QR] dialog shown');
            _showIncomingOfferDialog(offer);
          }
        });
      }
    });
  }

  /// Device-agnostic initialization: permissions → pairing server → file server → hotspot.
  /// No magic delays; readiness-based sequencing.
  Future<void> _initializeReceiving() async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _startupError = false;
      _startupErrorMsg = '';
    });

    try {
      await qrController.stopServer();
      await fileTransferController.stopServer();
      if (Platform.isAndroid) {
        final status = await Permission.locationWhenInUse.request();
        if (!status.isGranted && !status.isLimited) {
          print(
            '⚠️ Location permission not granted; Wi-Fi discovery may fail on some devices',
          );
        }
      }

      await qrController.startServer();
      if (!mounted) return;

      if (!qrController.wsRunning.value) {
        throw Exception('Pairing server failed to start');
      }
      final bindIp = qrController.serverBindIp.value;
      if (bindIp.isEmpty || bindIp == '0.0.0.0') {
        await Future.delayed(const Duration(milliseconds: 800));
        final retryIp = qrController.serverBindIp.value;
        if (retryIp.isEmpty || retryIp == '0.0.0.0') {
          throw Exception(
            'Could not detect network IP. Ensure Wi-Fi is on and try again.',
          );
        }
      }

      await fileTransferController.startServer();
      if (!mounted) return;

      _startHotspot();
    } catch (e) {
      print('❌ Receiver init failed: $e');
      if (mounted) {
        setState(() {
          _startupError = true;
          _startupErrorMsg = e.toString().replaceAll('Exception:', '').trim();
          _isInitializing = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

  bool get _hasUsableNetwork {
    return hotspotController.isHotspotActive.value ||
        qrController.wsRunning.value ||
        qrController.wsDisplayIp.value.isNotEmpty;
  }

  Future<void> initP2P() async {
    await qrController.startP2P();

    // ❗ ONLY show error if NO network at all
    if (!_hasUsableNetwork && mounted) {
      Get.dialog(
        AlertDialog(
          title: const Text('No Network Available'),
          content: const Text(
            'Please connect both devices to the same Wi-Fi or enable Hotspot.',
          ),
        ),
      );
    }
  }

  void _showIncomingPairDialog(Map<String, dynamic> request) async {
    if (_pairingDialogShown) return;
    _pairingDialogShown = true;
    final fromIp = request['fromIp'] as String;
    final senderName = request['senderName'] as String? ?? 'Unknown';
    bool responded = false;
    print('[QR] Pairing dialog shown for $senderName');
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 500);
    }
    if (!mounted) return;
    Get.dialog(
      PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop && !responded) {
            qrController.respondToPairing(fromIp, false);
          }
          _pairingDialogShown = false;
        },
        child: AlertDialog(
          title: const Text('Pairing Request'),
          content: Text('Device $senderName wants to pair with you.'),
          actions: [
            TextButton(
              onPressed: () {
                responded = true;
                _pairingDialogShown = false;
                qrController.respondToPairing(fromIp, false);
                Get.back();
              },
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                responded = true;
                _pairingDialogShown = false;
                qrController.respondToPairing(fromIp, true);
                Get.back();
              },
              child: const Text('Accept'),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _showIncomingOfferDialog(Map<String, dynamic> offer) async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 500); // 500 ms
    }
    final fromIp = offer['fromIp'] as String;
    final meta = offer['meta'] as Map<String, dynamic>;
    final fileName = meta['name'] as String;
    final senderName = meta['deviceName'] ?? "Sender Device";
    setState(() {
      connectedDevice = DeviceInfo(
        name: senderName,
        ip: fromIp,
        transferPort: qrController.transferPort,
      );
    });
    Get.dialog(
      AlertDialog(
        title: const Text('Incoming File'),
        content: Text('A sender wants to send you: $fileName. Do you accept?'),
        actions: [
          TextButton(
            onPressed: () {
              qrController.respondToOffer(fromIp, false);
              Get.back();
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          // ElevatedButton(
          //   onPressed: () {
          //     qrController.respondToOffer(fromIp, true);
          //     Get.back();
          //     // TransferProgressScreen navigation is handled by fileTransferController.sessionState listener
          //   },
          //   child: const Text('Accept'),
          // ),
          ElevatedButton(
            onPressed: () {
              qrController.respondToOffer(fromIp, true);
              Get.back();

              final transfer = Get.find<TransferController>();

              transfer.sessionState.value = TransferSessionState.transferring;
              transfer.progress.status.value = 'Receiving...';
              transfer.progress.receiveProgress.value = 0.0;

              // 👇 dialog open — receiver mode so progress shows immediately (not after first chunk)
              showTransferProgressDialog(isSender: false, device: null);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _startHotspot() async {
    final success = await hotspotController.startHotspot();

    if (!success && !_hasUsableNetwork) {
      Get.snackbar(
        'Hotspot Not Started',
        'Using existing Wi-Fi connection instead.',
        backgroundColor: Colors.orange.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  @override
  void dispose() {
    _pairingDialogShown = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 QrReceiverDisplayScreen building...');
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Text(
                      'Receive Files',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 19),

              /// Back Rowss

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
              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Obx(() {
                    // Decide QR data source. CRITICAL: Use pairing server's bind IP when
                    // available—this is the address the sender connects to. HotspotController
                    // may have empty IP on same Wi-Fi (getWifiIP returns null on some devices).
                    final String? pairingIp =
                        qrController.wsRunning.value
                            ? (qrController.serverBindIp.value.isNotEmpty
                                ? qrController.serverBindIp.value
                                : qrController.wsDisplayIp.value.isNotEmpty
                                ? qrController.wsDisplayIp.value
                                : null)
                            : null;
                    final HotspotInfo? realHotspot =
                        hotspotController.hotspotInfo.value;

                    HotspotInfo? displayInfo;
                    if (pairingIp != null && pairingIp.isNotEmpty) {
                      // Prefer pairing server IP—authoritative for WebSocket discovery
                      displayInfo = HotspotInfo(
                        ssid:
                            realHotspot?.ssid ?? qrController.deviceName.value,
                        password:
                            realHotspot?.password ??
                            hotspotController.generatedPassword.value,
                        ip: pairingIp,
                        port: qrController.transferPort,
                        deviceName: qrController.deviceName.value,
                      );
                    } else if (realHotspot != null &&
                        realHotspot.ip.isNotEmpty) {
                      displayInfo = HotspotInfo(
                        ssid: realHotspot.ssid,
                        password: realHotspot.password,
                        ip: realHotspot.ip,
                        port: realHotspot.port,
                        deviceName:
                            qrController.deviceName.value.isNotEmpty
                                ? qrController.deviceName.value
                                : realHotspot.deviceName,
                      );
                    }

                    if (_startupError) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off,
                            size: 64,
                            color: Colors.orange.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Could not start receiver',
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _startupErrorMsg.isNotEmpty
                                  ? _startupErrorMsg
                                  : 'Check Wi-Fi and try again.',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _initializeReceiving(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5DADE2),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      );
                    }
                    if (displayInfo == null || _isInitializing) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            _isInitializing
                                ? 'Starting receiver...\nPlease wait'
                                : 'Starting receiver server...\nPlease wait',
                            style: GoogleFonts.roboto(
                              color: Colors.white.withOpacity(0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    }
                    final qrData = displayInfo.toJson();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Status Indicator
                        // Container(
                        //   padding: const EdgeInsets.symmetric(
                        //     horizontal: 16,
                        //     vertical: 8,
                        //   ),
                        //   decoration: BoxDecoration(
                        //     color: Colors.green.withOpacity(0.2),
                        //     borderRadius: BorderRadius.circular(20),
                        //     border: Border.all(color: Colors.green, width: 2),
                        //   ),
                        //   child: Row(
                        //     mainAxisSize: MainAxisSize.min,
                        //     children: [
                        //       Container(
                        //         width: 8,
                        //         height: 8,
                        //         decoration: const BoxDecoration(
                        //           color: Colors.green,
                        //           shape: BoxShape.circle,
                        //         ),
                        //       ),
                        //       const SizedBox(width: 8),
                        //       Obx(() {
                        //         if (hotspotController.isHotspotActive.value) {
                        //           return const Text(
                        //             'Hotspot Active',
                        //             style: TextStyle(
                        //               color: Colors.green,
                        //               fontWeight: FontWeight.bold,
                        //             ),
                        //           );
                        //         } else {
                        //           return const Text(
                        //             'Hotspot Not Active',
                        //             style: TextStyle(
                        //               color: Colors.orange,
                        //               fontWeight: FontWeight.bold,
                        //             ),
                        //           );
                        //         }
                        //       }),
                        //     ],
                        //   ),
                        // ),
                        // Status Indicator
                        Obx(() {
                          String statusText;
                          Color statusColor;

                          if (hotspotController.isHotspotActive.value) {
                            statusText = 'Hotspot Active';
                            statusColor = Colors.green;
                          } else if (qrController.wsRunning.value) {
                            statusText = 'Connected via Wi-Fi';
                            statusColor = Colors.white;
                          } else {
                            statusText = 'No Network';
                            statusColor = Colors.orange;
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor, width: 2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 24),

                        // Instruction Text
                        Text(
                          'Show this QR code to the sender',
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),
                        Text(
                          'The sender will scan this code to start transfer',
                          style: GoogleFonts.roboto(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),
                        Obx(() {
                          if (!hotspotController.isHotspotActive.value) {
                            return Column(
                              children: [
                                Text(
                                  'Hotspot is not active. Please enable it manually if required by your device.',
                                  style: GoogleFonts.roboto(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                // const SizedBox(height: 8),
                                // ElevatedButton.icon(
                                //   onPressed: () async {
                                //     try {
                                //       await HotspotService.openHotspotSettings();
                                //     } catch (_) {
                                //       Get.snackbar(
                                //         'Unable to open settings',
                                //         'Please open hotspot/wifi settings manually.',
                                //         backgroundColor: Colors.orange
                                //             .withOpacity(0.9),
                                //         colorText: Colors.white,
                                //       );
                                //     }
                                //   },
                                //   icon: const Icon(Icons.settings),
                                //   label: const Text('Open Hotspot Settings'),
                                //   style: ElevatedButton.styleFrom(
                                //     backgroundColor: Colors.orange,
                                //     foregroundColor: Colors.white,
                                //   ),
                                // ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        }),

                        const SizedBox(height: 40),

                        // QR Code Container
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // QR Code
                              QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 200.0,
                                backgroundColor: Colors.white,
                              ),

                              const SizedBox(height: 20),

                              // Hotspot Details
                              Text(
                                'Connection Details',
                                style: GoogleFonts.roboto(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Network Name
                              _buildDetailRow('Network', displayInfo.ssid),
                              const SizedBox(height: 8),

                              // Password
                              _buildDetailRow(
                                'Password',
                                displayInfo.password.isEmpty
                                    ? 'Not required'
                                    : displayInfo.password,
                              ),
                              const SizedBox(height: 8),

                              // IP Address
                              _buildDetailRow('IP Address', displayInfo.ip),

                              const SizedBox(height: 20),

                              // Copy Button
                              ElevatedButton.icon(
                                onPressed: () {
                                  // TODO: Implement copy to clipboard
                                  Get.snackbar(
                                    'Copied',
                                    'Connection details copied to clipboard',
                                    backgroundColor: Colors.green.withOpacity(
                                      0.8,
                                    ),
                                    colorText: Colors.white,
                                  );
                                },
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy Details'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5DADE2),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Discovered sender devices (appears when a sender connects)
                        Obx(() {
                          final devices = qrController.devices;
                          if (devices.isEmpty) {
                            return Column(
                              children: [
                                SizedBox(
                                  height: 100,
                                  child: Lottie.asset(
                                    'assets/lottie/wifi.json',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Waiting for sender to scan QR code...',
                                  style: GoogleFonts.roboto(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Tap the sender device to accept and start transfer',
                                style: GoogleFonts.roboto(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...devices.map((d) {
                                return Card(
                                  color: Colors.white,
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFF5DADE2),
                                      child: Icon(
                                        Icons.phone_android,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(d.name),
                                    subtitle: Text('${d.ip}:${d.transferPort}'),
                                    trailing: ElevatedButton(
                                      onPressed: () async {
                                        // Accept the sender and start transfer
                                        qrController.respondToOffer(d.ip, true);
                                        Get.snackbar(
                                          'Accepted',
                                          'Accepted transfer from ${d.name}',
                                          backgroundColor: Colors.green
                                              .withOpacity(0.8),
                                          colorText: Colors.white,
                                        );
                                      },
                                      child: const Text('Accept'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF5DADE2,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        }),

                        const SizedBox(height: 24),

                        // Stop Hotspot Button
                        TextButton.icon(
                          onPressed: () async {
                            await qrController.stopServer();
                            await qrController.stopP2P();
                            await fileTransferController.stopServer();
                            final success =
                                await hotspotController.stopHotspot();
                            if (success) {
                              Get.back();
                            }
                          },
                          icon: const Icon(Icons.stop, color: Colors.blue),
                          label: const Text(
                            'Stop Receiving',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
