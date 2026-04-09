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
import 'package:share_app_latest/components/bg_container.dart'
    show bg_container;
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/show_uploadbar_dialogue.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';
import 'package:share_app_latest/components/app_dialog.dart';
import 'package:vibration/vibration.dart';

import '../../../controllers/hotspot_controller.dart';
import '../../../controllers/QR_controller.dart';
import '../../../controllers/pairing_controller.dart';
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
  final Rxn<DeviceInfo> connectedDevice = Rxn<DeviceInfo>();
  final RxBool _startupError = false.obs;
  final RxString _startupErrorMsg = ''.obs;
  final RxBool _isInitializing = true.obs;
  bool _pairingDialogShown = false;
  final RxBool _isPaired = false.obs;
  final RxString _pairedDeviceName = ''.obs;
  Worker? _sessionStateWorker;
  Worker? _pairingRequestWorker;
  Worker? _incomingOfferWorker;
  @override
  void initState() {
    super.initState();
    print('📱 QrReceiverDisplayScreen initialized');
    _initializeReceiving();

    _sessionStateWorker = ever(fileTransferController.sessionState, (state) {
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
    _pairingRequestWorker = ever(qrController.incomingPairingRequest, (request) {
      if (request != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && request == qrController.incomingPairingRequest.value) {
            _showIncomingPairDialog(request);
          }
        });
      }
    });

    // Listen for incoming file offers
    _incomingOfferWorker = ever(qrController.incomingOffer, (offer) {
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
    _isInitializing.value = true;
    _startupError.value = false;
    _startupErrorMsg.value = '';

    try {
      // Free port 7070 and clear Wi‑Fi Direct state so QR flow can use it
      final pairing = Get.find<PairingController>();
      await pairing.stopServer();
      pairing.devices.clear();
      pairing.incomingOffer.value = null;
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
      if (!mounted) return;

      // Start Wi‑Fi P2P discovery so this device can be found (e.g. when not on same Wi‑Fi).
      // Non-blocking: receiver UI is already usable via pairing server; P2P is an extra path.
      // initP2P();
    } catch (e) {
      print('❌ Receiver init failed: $e');
      if (mounted) {
        _startupError.value = true;
        _startupErrorMsg.value =
            e.toString().replaceAll('Exception:', '').trim();
        _isInitializing.value = false;
      }
      return;
    }

    if (mounted) {
      _isInitializing.value = false;
    }
  }

  bool get _hasUsableNetwork {
    return hotspotController.isHotspotActive.value ||
        qrController.wsRunning.value ||
        qrController.wsDisplayIp.value.isNotEmpty;
  }

  Future<void> initP2P() async {
    try {
      final started = await qrController.startP2P();
      if (!mounted) return;

      if (!started) {
        // P2P discovery failed but we may still have pairing server over Wi‑Fi
        if (_hasUsableNetwork) {
          if (mounted) {
            Get.snackbar(
              'Wi‑Fi Direct unavailable',
              'You can still receive via same Wi‑Fi or hotspot.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.orange.withOpacity(0.9),
              colorText: Colors.white,
              duration: const Duration(seconds: 4),
            );
          }
        } else {
          Get.dialog(
            AlertDialog(
              title: const Text('No Network Available'),
              content: const Text(
                'Please connect both devices to the same Wi-Fi or enable Hotspot.',
              ),
            ),
          );
        }
        return;
      }

      // ❗ ONLY show error dialog if NO network at all (startP2P succeeded but no connectivity)
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
    } catch (e) {
      print('❌ initP2P failed: $e');
      if (mounted && _hasUsableNetwork) {
        Get.snackbar(
          'Wi‑Fi Direct unavailable',
          'You can still receive via same Wi‑Fi or hotspot.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  void _showIncomingPairDialog(Map<String, dynamic> request) async {
    if (_pairingDialogShown) return;
    _pairingDialogShown = true;
    // Clear so a delayed duplicate doesn't trigger the popup again after user accepts
    qrController.incomingPairingRequest.value = null;
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
        child: const SizedBox.shrink(),
      ),
      barrierDismissible: false,
    );

    await showAppDialog<void>(
      title: 'Pairing Request',
      message: 'Device $senderName wants to pair with you.',
      primaryLabel: 'Accept',
      secondaryLabel: 'Reject',
      onSecondary: () {
        responded = true;
        _pairingDialogShown = false;
        qrController.respondToPairing(fromIp, false);
      },
      onPrimary: () {
        responded = true;
        _pairingDialogShown = false;
        qrController.respondToPairing(fromIp, true);
        _isPaired.value = true;
        _pairedDeviceName.value = senderName;
      },
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
    connectedDevice.value = DeviceInfo(
      name: senderName,
      ip: fromIp,
      transferPort: qrController.transferPort,
    );
    await showAppDialog<void>(
      title: 'Incoming File',
      message: 'A sender wants to send you: $fileName. Do you accept?',
      primaryLabel: 'Accept',
      secondaryLabel: 'Reject',
      barrierDismissible: false,
      onSecondary: () {
        qrController.respondToOffer(fromIp, false);
      },
      onPrimary: () {
        qrController.respondToOffer(fromIp, true);

        final transfer = Get.find<TransferController>();
        transfer.sessionState.value = TransferSessionState.transferring;
        transfer.progress.status.value = 'Receiving...';
        transfer.progress.receiveProgress.value = 0.0;

        showTransferProgressDialog(isSender: false, device: null);
      },
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
    _sessionStateWorker?.dispose();
    _pairingRequestWorker?.dispose();
    _incomingOfferWorker?.dispose();
    // Free pairing WebSocket, transfer server, P2P, and hotspot so Wi‑Fi flows can reuse ports
    qrController.stopServer();
    qrController.stopP2P();
    fileTransferController.stopServer();
    hotspotController.stopHotspot();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 QrReceiverDisplayScreen building...');
    return Scaffold(
      body: bg_container(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                    ),
                    Text(
                      'Receive Files',
                      style: GoogleFonts.roboto(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              /// Back Rowsss

              /// Progress Barss
              StepProgressBar(
                currentStep: 3,
                totalSteps: kTransferFlowTotalSteps,
                activeColor: Theme.of(context).colorScheme.primary,
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

                    if (_startupError.value) {
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
                              _startupErrorMsg.value.isNotEmpty
                                  ? _startupErrorMsg.value
                                  : 'Check Wi-Fi and try again.',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: Colors.black,
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
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      );
                    }
                    if (displayInfo == null || _isInitializing.value) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            _isInitializing.value
                                ? 'Starting receiver...\nPlease wait'
                                : 'Starting receiver server...\nPlease wait',
                            style: GoogleFonts.roboto(
                              color: Colors.black.withOpacity(0.9),
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
                        Obx(() {
                          String statusText;
                          Color statusColor;

                          if (hotspotController.isHotspotActive.value) {
                            statusText = 'Hotspot Active';
                            statusColor = Colors.green;
                          } else if (qrController.wsRunning.value) {
                            statusText = 'Connected via Wi-Fi';
                            statusColor = Colors.black;
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
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),
                        Text(
                          'The sender will scan this code to start transfer',
                          style: GoogleFonts.roboto(
                            color: Colors.black.withOpacity(0.8),
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
                                    color: Colors.black.withOpacity(0.9),
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        }),

                        const SizedBox(height: 40),

                        if (!_isPaired.value)
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
                                QrImageView(
                                  data: qrData,
                                  version: QrVersions.auto,
                                  size: 200.0,
                                  backgroundColor: Colors.white,
                                ),
                                // ...rest of QR details
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 60,
                                  color: Colors.green,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Device successfully connected to ${_pairedDeviceName.value}',
                                  style: GoogleFonts.roboto(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade900,
                                  ),
                                  textAlign: TextAlign.center,
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

  // _buildDetailRow helper kept in history for possible future reuse
  // with QR / hotspot connection details UI.
}
