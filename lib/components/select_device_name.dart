import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:share_app_latest/app/controllers/bluetooth_controller.dart';
import 'package:share_app_latest/app/controllers/pairing_controller.dart';
import 'package:share_app_latest/app/controllers/transfer_controller.dart';
import 'package:share_app_latest/app/models/device_info.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';

import '../../../routes/app_navigator.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SelectDeviceScreen extends StatefulWidget {
  final List<DeviceInfo> devices;
  final bool isBluetooth;
  final bool isReceiver;

  SelectDeviceScreen({
    super.key,
    required this.devices,
    this.isBluetooth = false,
    this.isReceiver = false,
  });

  @override
  State<SelectDeviceScreen> createState() => _SelectDeviceScreenState();
}

class _SelectDeviceScreenState extends State<SelectDeviceScreen> {
  int? selectedIndex;
  Worker? _connectedDeviceWorker;
  bool _navigatedToTransfer = false;
  bool _handshakeInProgress = false;
  int? _selectedBluetoothIndex;
  bool _bluetoothConnecting = false;
  @override
  void initState() {
    super.initState();
    if (widget.isBluetooth) {
      final bluetooth = Get.find<BluetoothController>(tag: 'sender');
      _connectedDeviceWorker = ever(bluetooth.connectedDevice, (device) {
        if (device == null || _navigatedToTransfer || !mounted) return;

        final info = bluetooth.connectedDeviceInfo;
        if (info == null) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _navigatedToTransfer) return;
          _navigatedToTransfer = true;
          AppNavigator.toTransferFile(device: info);
        });
      });
    }
  }

  @override
  void dispose() {
    _connectedDeviceWorker?.dispose();
    if (widget.isBluetooth) {
      try {
        final bluetooth = Get.find<BluetoothController>(tag: 'sender');
        bluetooth.stopScan();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isBluetooth) {
      return _buildBluetoothContent();
    }
    return _buildWiFiContent();
  }

  // Widget _buildBluetoothContent() {
  //   final bluetooth = Get.find<BluetoothController>(tag: 'sender');
  //   return Scaffold(
  //     body: Container(
  //       width: double.infinity,
  //       height: double.infinity,
  //       decoration: const BoxDecoration(
  //         gradient: LinearGradient(
  //           begin: Alignment.topLeft,
  //           end: Alignment.bottomRight,
  //           colors: [Color(0xffEEF4FF), Color(0xffF8FAFF), Color(0xffFFFFFF)],
  //         ),
  //       ),
  //       child: SafeArea(
  //         child: Padding(
  //           padding: const EdgeInsets.all(18.0),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Row(
  //                 children: [
  //                   IconButton(
  //                     onPressed: () => Get.back(),
  //                     icon: const Icon(Icons.arrow_back),
  //                   ),
  //                   Text(
  //                     "Back",
  //                     style: GoogleFonts.roboto(
  //                       fontSize: 16,
  //                       fontWeight: FontWeight.w500,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //               StepProgressBar(
  //                 currentStep: 3,
  //                 totalSteps: kTransferFlowTotalSteps,
  //                 activeColor: Theme.of(context).colorScheme.primary,
  //                 inactiveColor: Colors.grey.shade300,
  //                 height: 6,
  //                 segmentSpacing: 5,
  //                 padding: const EdgeInsets.only(top: 8, bottom: 16),
  //               ),
  //               const SizedBox(height: 30),
  //               Expanded(
  //                 child: Obx(() {
  //                   if (bluetooth.error.value.isNotEmpty) {
  //                     return Center(
  //                       child: Text(
  //                         bluetooth.error.value,
  //                         style: const TextStyle(
  //                           color: Colors.red,
  //                           fontSize: 16,
  //                         ),
  //                       ),
  //                     );
  //                   }
  //                   // Already connected: show the connected device (no scan list)
  //                   final connected = bluetooth.connectedDevice.value;
  //                   if (connected != null) {
  //                     return SingleChildScrollView(
  //                       child: Column(
  //                         crossAxisAlignment: CrossAxisAlignment.stretch,
  //                         children: [
  //                           Text(
  //                             "Already connected",
  //                             style: GoogleFonts.roboto(
  //                               fontSize: 22,
  //                               fontWeight: FontWeight.bold,
  //                             ),
  //                           ),
  //                           const SizedBox(height: 6),
  //                           Text(
  //                             "You are connected to the device below. Tap to send files or disconnect.",
  //                             style: GoogleFonts.roboto(
  //                               fontSize: 13,
  //                               color: Colors.grey.shade700,
  //                             ),
  //                           ),
  //                           const SizedBox(height: 16),
  //                           _BluetoothDeviceTile(
  //                             device: connected,
  //                             bluetooth: bluetooth,
  //                           ),
  //                         ],
  //                       ),
  //                     );
  //                   }
  //                   final devices = bluetooth.devices;
  //                   if (bluetooth.isScanning.value && devices.isEmpty) {
  //                     return Center(
  //                       child: Column(
  //                         mainAxisAlignment: MainAxisAlignment.center,
  //                         children: [
  //                           const CircularProgressIndicator(),
  //                           const SizedBox(height: 16),
  //                           Text(
  //                             'Searching for devices...',
  //                             style: GoogleFonts.roboto(
  //                               color: Colors.grey.shade700,
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     );
  //                   }
  //                   if (devices.isEmpty) {
  //                     return Center(
  //                       child: Column(
  //                         mainAxisAlignment: MainAxisAlignment.center,
  //                         children: [
  //                           Icon(
  //                             Icons.bluetooth_disabled,
  //                             size: 64,
  //                             color: Colors.grey.shade400,
  //                           ),
  //                           const SizedBox(height: 16),
  //                           Text(
  //                             'No Bluetooth devices found',
  //                             style: GoogleFonts.roboto(
  //                               color: Colors.grey.shade700,
  //                             ),
  //                           ),
  //                           const SizedBox(height: 16),
  //                           OutlinedButton.icon(
  //                             onPressed: () => bluetooth.startScan(),
  //                             icon: const Icon(Icons.refresh),
  //                             label: const Text('Scan again'),
  //                           ),
  //                         ],
  //                       ),
  //                     );
  //                   }
  //                   return SingleChildScrollView(
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.stretch,
  //                       children: [
  //                         Text(
  //                           "Select The Device",
  //                           style: GoogleFonts.roboto(
  //                             fontSize: 22,
  //                             fontWeight: FontWeight.bold,
  //                           ),
  //                         ),
  //                         const SizedBox(height: 6),
  //                         Text(
  //                           "Tap Connect on the device you want to send files to",
  //                           style: GoogleFonts.roboto(
  //                             fontSize: 13,
  //                             color: Colors.grey.shade700,
  //                           ),
  //                         ),
  //                         const SizedBox(height: 16),
  //                         ...devices.map(
  //                           (device) => _BluetoothDeviceTile(
  //                             device: device,
  //                             bluetooth: bluetooth,
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   );
  //                 }),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildBluetoothContent() {
    final bluetooth = Get.find<BluetoothController>(tag: 'sender');
    final transfer = Get.find<TransferController>();

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
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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

                const SizedBox(height: 30),

                Expanded(
                  child: Obx(() {
                    final devices = bluetooth.devices;

                    if (bluetooth.isScanning.value && devices.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (devices.isEmpty) {
                      return const Center(
                        child: Text("No Bluetooth devices found"),
                      );
                    }

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Select The Device",
                            style: GoogleFonts.roboto(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          ...devices.asMap().entries.map((entry) {
                            final index = entry.key;
                            final device = entry.value;

                            return GestureDetector(
                              onTap: () async {
                                if (_bluetoothConnecting) return;

                                setState(() {
                                  _bluetoothConnecting = true;
                                  _selectedBluetoothIndex = index;
                                });

                                await bluetooth.connect(device);

                                if (!mounted) return;

                                setState(() {
                                  _bluetoothConnecting = false;
                                });

                                // Fallback: if connection succeeded and observer missed the event,
                                // navigate directly to TransferFileScreen.
                                if (bluetooth.isDeviceConnected(device) &&
                                    !_navigatedToTransfer) {
                                  final info = bluetooth.connectedDeviceInfo ??
                                      DeviceInfo(
                                        name: bluetooth.getDeviceDisplayName(device),
                                        ip: '',
                                        transferPort: 0,
                                        isBluetooth: true,
                                        bluetoothDeviceId: device.remoteId.str,
                                      );
                                  if (mounted) {
                                    _navigatedToTransfer = true;
                                    AppNavigator.toTransferFile(device: info);
                                  }
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xffE7ECFF),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color:
                                        _selectedBluetoothIndex == index
                                            ? Colors.blue
                                            : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.blue,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color:
                                                _selectedBluetoothIndex == index
                                                    ? Colors.blue
                                                    : Colors.transparent,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            bluetooth.getDeviceDisplayName(device),
                                            style: GoogleFonts.roboto(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            device.remoteId.str,
                                            style: GoogleFonts.roboto(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    if (_bluetoothConnecting &&
                                        _selectedBluetoothIndex == index)
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  }),
                ),
                // When user cancelled the file picker after connecting,
                // offer a one-tap way to reopen it from this screen.
                Obx(() {
                  if (!transfer.canReopenPicker.value) return const SizedBox();
                  final info = bluetooth.connectedDeviceInfo;
                  if (info == null) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          AppNavigator.toTransferFile(device: info);
                        },
                        icon: const Icon(
                          Icons.refresh,
                          size: 18,
                        ),
                        label: Text(
                          'Pick file again',
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          side: BorderSide(
                            color: Theme.of(Get.context!)
                                .colorScheme
                                .primary
                                .withOpacity(0.6),
                          ),
                          foregroundColor:
                              Theme.of(Get.context!).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWiFiContent() {
    final transfer = Get.find<TransferController>();
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xffEEF4FF),
                  Color(0xffF8FAFF),
                  Color(0xffFFFFFF),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => AppNavigator.toSendReceive(),
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
                      currentStep: 4,
                      totalSteps: kTransferFlowTotalSteps,
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: Colors.grey.shade300,
                      height: 6,
                      segmentSpacing: 5,
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                    ),
                    const SizedBox(height: 30),
                    Center(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 22,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Select The Device",
                              style: GoogleFonts.roboto(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Select which device you want to send your files to",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.roboto(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            ListView.builder(
                              itemCount: widget.devices.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                final device = widget.devices[index];
                                return GestureDetector(
                                  onTap:
                                      _handshakeInProgress
                                          ? null
                                          : () async {
                                            setState(() {
                                              selectedIndex = index;
                                            });
                                            if (widget.isReceiver) {
                                              final pairing =
                                                  Get.find<PairingController>();
                                              final bool success =
                                                  await pairing.acceptHandshake(
                                                device.ip,
                                              );

                                              if (!mounted) return;

                                              if (success) {
                                                // Once the receiver taps we consider it "ready".
                                                // The controller ensures the transfer server is
                                                // running and future handshakes from this IP
                                                // are auto-accepted.
                                                Get.snackbar(
                                                  "Ready",
                                                  "Receiver is ready. Waiting for sender.",
                                                  backgroundColor: Colors.green
                                                      .withOpacity(0.85),
                                                  colorText: Colors.white,
                                                  snackPosition:
                                                      SnackPosition.BOTTOM,
                                                  duration: const Duration(
                                                    seconds: 3,
                                                  ),
                                                );
                                              } else {
                                                Get.snackbar(
                                                  "Handshake failed",
                                                  "Could not confirm readiness. Ensure both devices are on this screen and try again.",
                                                  backgroundColor: Colors.red
                                                      .withOpacity(0.85),
                                                  colorText: Colors.white,
                                                  snackPosition:
                                                      SnackPosition.BOTTOM,
                                                  duration: const Duration(
                                                    seconds: 3,
                                                  ),
                                                );
                                              }
                                              return;
                                            }
                                            if (_navigatedToTransfer) return;
                                            setState(() {
                                              _handshakeInProgress = true;
                                            });
                                            final pairing =
                                                Get.find<PairingController>();
                                            final confirmed = await pairing
                                                .confirmReceiverReady(device);
                                            if (!mounted) return;
                                            setState(() {
                                              _handshakeInProgress = false;
                                            });
                                            if (_navigatedToTransfer) return;
                                            if (confirmed) {
                                              _navigatedToTransfer = true;
                                              AppNavigator.toTransferFile(
                                                device: device,
                                              );
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Receiver not ready. Ensure the other device is on this screen and try again.',
                                                  ),
                                                  duration: Duration(
                                                    seconds: 4,
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffE7ECFF),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.blue,
                                              width: 2,
                                            ),
                                          ),
                                          child: Center(
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color:
                                                    (selectedIndex != null &&
                                                            selectedIndex ==
                                                                index)
                                                        ? Colors.blue
                                                        : Colors.transparent,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          device.name,
                                          style: GoogleFonts.roboto(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Show "Pick again" button on Wi‑Fi device selection screen
                    // after the user cancelled/closed the file picker.
                    Obx(() {
                      if (!transfer.canReopenPicker.value) {
                        return const SizedBox.shrink();
                      }
                      if (selectedIndex == null ||
                          selectedIndex! < 0 ||
                          selectedIndex! >= widget.devices.length) {
                        return const SizedBox.shrink();
                      }
                      final device = widget.devices[selectedIndex!];
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _handshakeInProgress
                              ? null
                              : () {
                                  AppNavigator.toTransferFile(device: device);
                                },
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Pick file again'),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          if (_handshakeInProgress)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        'Connnecting to receiver...',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BluetoothDeviceTile extends StatelessWidget {
  const BluetoothDeviceTile({required this.device, required this.bluetooth});

  final BluetoothDevice device;
  final BluetoothController bluetooth;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final connected = bluetooth.isDeviceConnected(device);
      final deviceInfo = connected ? bluetooth.connectedDeviceInfo : null;
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          onTap:
              connected && deviceInfo != null
                  ? () => AppNavigator.toTransferFile(device: deviceInfo)
                  : null,
          leading: Icon(
            Icons.bluetooth,
            color: connected ? Colors.green : null,
          ),
          title: Text(
            bluetooth.getDeviceDisplayName(device),
            style: GoogleFonts.roboto(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            device.remoteId.str,
            style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey),
          ),
          trailing:
              connected
                  ? TextButton(
                    onPressed:
                        deviceInfo != null
                            ? () =>
                                AppNavigator.toTransferFile(device: deviceInfo)
                            : null,
                    child: const Text(
                      'Connected',
                      style: TextStyle(color: Colors.green),
                    ),
                  )
                  : ElevatedButton(
                    onPressed: () => bluetooth.connect(device),
                    child: const Text('Connect'),
                  ),
        ),
      );
    });
  }
}
