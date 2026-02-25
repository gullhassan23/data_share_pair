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
          if (!mounted) return;

          // If this screen is opened as receiver, don't navigate
          if (!widget.isBluetooth) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Connected successfully. Please wait for sender...',
                ),
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }

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
                                            getDisplayName(device),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWiFiContent() {
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
                                              final transferController =
                                                  Get.find<
                                                    TransferController
                                                  >();
                                              await transferController
                                                  .startServer();
                                              if (!mounted) return;
                                              // ScaffoldMessenger.of(context)
                                              //     .showSnackBar(
                                              //   const SnackBar(
                                              //     content: Text(
                                              //       'Waiting for sender...',
                                              //     ),
                                              //     duration: Duration(seconds: 3),
                                              //   ),
                                              // );
                                              Get.snackbar(
                                                "Wait",
                                                "Wait for sender to select the file",
                                                backgroundColor: Colors
                                                    .yellowAccent
                                                    .withOpacity(0.8),
                                                colorText: Colors.black,
                                                snackPosition:
                                                    SnackPosition.BOTTOM,
                                                duration: const Duration(
                                                  seconds: 2,
                                                ),
                                              );
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
            getDisplayName(device),
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
