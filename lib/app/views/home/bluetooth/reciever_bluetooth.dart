import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:share_app_latest/app/controllers/bluetooth_controller.dart';
import 'package:share_app_latest/app/controllers/transfer_controller.dart';
import 'package:share_app_latest/app/views/home/received_files_screen.dart';

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

  @override
  void initState() {
    super.initState();
    bluetooth = Get.put(BluetoothController(), tag: "receiver");

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
        bluetooth.error.value = 'Bluetooth permission denied';
        return;
      }

      _incomingOfferWorker = ever(bluetooth.incomingOffer, (offer) {
        if (offer != null) {
          _showIncomingOfferDialog(offer);
        }
      });

      try {
        await bluetooth.startReceiverMode();
      } catch (e) {
        if (mounted) {
          bluetooth.error.value = 'Failed to start receiver: $e';
        }
      }
    });
  }

  @override
  void dispose() {
    _incomingOfferWorker?.dispose();
    bluetooth.stopReceiverMode();
    super.dispose();
  }

  void _showIncomingOfferDialog(Map<String, dynamic> offer) async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 500); // 500 ms
    }
    final meta = offer['meta'];
    final fileName = (meta is Map ? meta['name']?.toString() : null) ??
        'Unknown file';

    Get.dialog(
      AlertDialog(
        title: const Text("Incoming File"),
        content: Text("Sender wants to send: $fileName"),
        actions: [
          TextButton(
            onPressed: () {
              bluetooth.sendMessage(jsonEncode({"type": "reject"}));
              bluetooth.incomingOffer.value = null;
              bluetooth.connectedSenderName.value = null;
              Get.back();
            },
            child: const Text("Reject"),
          ),
          ElevatedButton(
            onPressed: () async {
              final transfer = Get.find<TransferController>();
              final info = NetworkInfo();
              String? wifiIp = await info.getWifiIP();
              if (wifiIp == null || wifiIp.isEmpty) {
                Get.snackbar(
                  "Cannot receive",
                  "Connect to Wi‑Fi so the sender can send the file.",
                );
                return;
              }
              try {
                await transfer.startServer();
              } catch (e) {
                Get.snackbar("Error", "Failed to start receiver: $e");
                return;
              }
              final acceptMsg = {
                "type": "accept",
                "ip": wifiIp,
                "port": transfer.serverPort,
              };
              await bluetooth.sendMessage(jsonEncode(acceptMsg));
              bluetooth.incomingOffer.value = null;
              Get.back();

              // Show progress bar on receiver (same as QR flow)
              transfer.sessionState.value = TransferSessionState.transferring;
              transfer.progress.status.value = 'Receiving...';
              transfer.progress.receiveProgress.value = 0.0;
              showTransferProgressDialog(isSender: false, device: null);
            },
            child: const Text("Accept"),
          ),
        ],
      ),
      barrierDismissible: false,
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
                activeColor: Colors.blue,
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
                  color: Colors.blue,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Obx(() {
                    if (bluetooth.error.value.isNotEmpty) {
                      return _ErrorView(bluetooth.error.value);
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

Widget _ErrorView(String error) {
  return Center(
    child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 16)),
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
