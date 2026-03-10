import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/app/controllers/bluetooth_controller.dart';
import 'package:share_app_latest/components/app_dialog.dart';
import 'package:share_app_latest/app/controllers/transfer_controller.dart';
import 'package:share_app_latest/app/views/home/received_files_screen.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/permissions.dart';
import 'package:share_app_latest/utils/show_uploadbar_dialogue.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';
import 'package:vibration/vibration.dart';

class BluetoothReceiverScreen extends StatefulWidget {
  const BluetoothReceiverScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothReceiverScreen> createState() =>
      _BluetoothReceiverScreenState();
}

class _BluetoothReceiverScreenState extends State<BluetoothReceiverScreen> {
  late final BluetoothController bluetooth;
  Worker? _incomingOfferWorker;
  Worker? _receiverReadyWorker;
  StreamSubscription<double>? _bleProgressSub;
  StreamSubscription<Map<String, dynamic>>? _bleCompleteSub;
  StreamSubscription<String>? _bleErrorSub;

  @override
  void initState() {
    super.initState();
    bluetooth = Get.put(BluetoothController(), tag: "receiver");

    // Show snackbar once when BLE advertising has started
    _receiverReadyWorker = ever(bluetooth.receiverReady, (ready) {
      if (ready == true && mounted) {
        Get.snackbar(
          'Ready',
          'Ready to receive – waiting for sender.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    });

    // When transfer completes, close progress dialog and navigate (same as QR receiver)
    final transfer = Get.find<TransferController>();
    ever(transfer.sessionState, (state) {
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
        Get.to(() => const ReceivedFilesScreen());
      }
      if (state == TransferSessionState.error && mounted) {
        Get.snackbar(
          'Error',
          'File transfer failed',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final granted = await askPermissions();
      if (!granted) {
        // ignore: avoid_print
        print('[BT][ReceiverScreen] Permissions not granted – showing error to user');
        bluetooth.error.value = 'Bluetooth permission denied';
        return;
      }
      // ignore: avoid_print
      print('[BT][ReceiverScreen] Permissions granted – starting receiver mode');

      _incomingOfferWorker = ever(bluetooth.incomingOffer, (offer) {
        if (offer != null) {
          _showIncomingOfferDialog(offer);
        }
      });

      try {
        await bluetooth.startReceiverMode();
      } catch (e) {
        if (mounted) {
          // ignore: avoid_print
          print('[BT][ReceiverScreen] startReceiverMode() failed: $e');
          bluetooth.error.value = 'Failed to start receiver: $e';
        }
      }
    });
  }

  @override
  void dispose() {
    _bleProgressSub?.cancel();
    _bleCompleteSub?.cancel();
    _bleErrorSub?.cancel();
    _incomingOfferWorker?.dispose();
    _receiverReadyWorker?.dispose();
    bluetooth.stopReceiverMode();
    super.dispose();
  }

  void _showIncomingOfferDialog(Map<String, dynamic> offer) async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 500); // 500 ms
    }
    // Null-safe: avoid crash on malformed offer (missing meta or meta.name)
    String fileName = 'Unknown file';
    try {
      final meta = offer['meta'];
      final name = meta is Map ? meta['name']?.toString() : null;
      fileName =
          (name != null && name.trim().isNotEmpty)
              ? name.trim()
              : 'Unknown file';
    } catch (_) {
      fileName = 'Unknown file';
    }

    showAppDialog<void>(
      title: 'Incoming File',
      message: 'Sender wants to send: $fileName',
      primaryLabel: 'Accept',
      secondaryLabel: 'Reject',
      barrierDismissible: false,
      onSecondary: () {
        bluetooth.sendMessage(jsonEncode({"type": "reject"}));
        bluetooth.incomingOffer.value = null;
        bluetooth.connectedSenderName.value = null;
      },
      onPrimary: () async {
        final transfer = Get.find<TransferController>();

        // Prepare BLE file receive and UI BEFORE sending accept so that
        // file_meta and chunks are handled with progress from the very start.
        bluetooth.startReceivingFile();
        transfer.sessionState.value = TransferSessionState.transferring;
        transfer.progress.status.value = 'Receiving...';
        transfer.progress.receiveProgress.value = 0.0;
        transfer.progress.error.value = '';
        showTransferProgressDialog(isSender: false, device: null);

        _bleProgressSub?.cancel();
        _bleProgressSub = bluetooth.bleReceiveProgress.listen((p) {
          if (mounted) {
            transfer.progress.receiveProgress.value = p;
          }
        });

        _bleCompleteSub?.cancel();
        _bleCompleteSub = bluetooth.bleReceiveComplete.listen((result) {
          if (!mounted) return;
          final savePath = result['savePath'] as String?;
          final meta = result['meta'] as Map<String, dynamic>?;
          if (savePath != null) {
            transfer.receivedFiles.add({
              'path': savePath,
              'name': meta?['name'] ?? 'received_file',
              'size': meta?['size'] ?? 0,
              'type': meta?['type'] ?? 'file',
            });
            transfer.progress.receiveProgress.value = 1.0;
            transfer.progress.status.value = 'received';
            transfer.sessionState.value = TransferSessionState.completed;
          }
          _bleProgressSub?.cancel();
          _bleCompleteSub?.cancel();
          _bleErrorSub?.cancel();
        });

        _bleErrorSub?.cancel();
        _bleErrorSub = bluetooth.bleReceiveError.listen((msg) {
          if (mounted) {
            transfer.progress.error.value = msg;
            transfer.sessionState.value = TransferSessionState.error;
            _bleProgressSub?.cancel();
            _bleCompleteSub?.cancel();
            _bleErrorSub?.cancel();
          }
        });

        // BLE-only transfer: no WiFi or TCP server needed
        final acceptMsg = {
          "type": "accept",
          "bleTransfer": true,
        };
        await bluetooth.sendMessage(jsonEncode(acceptMsg));
        bluetooth.incomingOffer.value = null;
        Get.back();
      },
    );
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

              // Top Bar
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
              Text(
                'Receive via Bluetooth',
                style: GoogleFonts.roboto(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Obx(() {
                    if (bluetooth.error.value.isNotEmpty) {
                      return _ErrorView(
                        bluetooth.error.value,
                        onOpenSettings: () => openAppSettings(),
                      );
                    }
                    final senderName = bluetooth.connectedSenderName.value;
                    return _ReceiverStatusView(connectedSenderName: senderName);
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _ErrorView(String error, {VoidCallback? onOpenSettings}) {
  final isPermissionError =
      error.toLowerCase().contains('permission') ||
      error.toLowerCase().contains('location');
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            error,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          if (isPermissionError && onOpenSettings != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Open settings'),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _ReceiverStatusView({String? connectedSenderName}) {
  final isConnected =
      connectedSenderName != null && connectedSenderName.isNotEmpty;
  return Column(
    children: [
      const SizedBox(height: 60),
      Icon(
        isConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
        size: 80,
        color: isConnected ? Colors.green : Colors.blue,
      ),
      const SizedBox(height: 16),
      Text(
        isConnected
            ? 'Connected with $connectedSenderName'
            : 'Waiting for sender to connect…',
        style: GoogleFonts.roboto(fontSize: 16),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

// Widget IncomingConnectionDialog(BluetoothDevice device) {
//   final bluetooth = Get.find<BluetoothController>(tag: "receiver");

//   return AlertDialog(
//     title: const Text('Incoming Connection'),
//     content: Text(
//       'Device ${device.name.isNotEmpty ? device.name : device.remoteId.str} wants to connect',
//     ),
//     actions: [
//       TextButton(
//         onPressed: () {
//           // Reject connection
//           bluetooth.incomingConnection.value = null;
//         },
//         child: const Text('Reject'),
//       ),
//       TextButton(
//         onPressed: () async {
//           // Accept connection
//           await device.connect();
//           bluetooth.incomingConnection.value = null;
//           Get.snackbar('Connected', 'Connected to ${device.name}');
//         },
//         child: const Text('Accept'),
//       ),
//     ],
//   );
// }
