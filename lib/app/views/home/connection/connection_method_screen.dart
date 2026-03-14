import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/app/views/home/connection/transfer_type_tile.dart';
import 'package:share_app_latest/app/views/home/bluetooth/reciever_bluetooth.dart';
import 'package:share_app_latest/app/views/home/bluetooth/sender_bluetooth.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';

enum TransferType {
  bluetooth,
  wifiScanner,
  wifiSameNetwork,
}

class ConnectionMethodScreen extends StatefulWidget {
  const ConnectionMethodScreen({super.key, required this.isReceiver});

  final bool isReceiver;

  @override
  State<ConnectionMethodScreen> createState() => _ConnectionMethodScreenState();
}

class _ConnectionMethodScreenState extends State<ConnectionMethodScreen> {
  TransferType _selected = TransferType.bluetooth;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<PremiumController>()) {
      Get.put(PremiumController(), permanent: false);
    }
  }

  bool get _isPremium =>
      Get.isRegistered<PremiumController>()
          ? Get.find<PremiumController>().isPremium
          : false;

  void _onTapTransferType(TransferType type) {
    setState(() => _selected = type);
  }

  void _onContinue() {
    final type = _selected;
    final isProType = type == TransferType.wifiScanner ||
        type == TransferType.wifiSameNetwork;
    if (isProType && !_isPremium) {
      Get.snackbar(
        'Premium required',
        'Wi‑Fi Direct and Same Network transfer are available in the Pro version.',
        snackPosition: SnackPosition.BOTTOM,
        mainButton: TextButton(
          onPressed: () {
            Get.closeCurrentSnackbar();
            AppNavigator.toPremium();
          },
          child: const Text('Upgrade'),
        ),
      );
      return;
    }

    switch (type) {
      case TransferType.bluetooth:
        if (widget.isReceiver) {
          Get.to(() => const BluetoothReceiverScreen());
        } else {
          Get.to(() => const BluetoothSenderScreen());
        }
        break;
      case TransferType.wifiScanner:
      case TransferType.wifiSameNetwork:
        AppNavigator.toPairing(isReceiver: widget.isReceiver);
        break;
    }
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Back",
                    style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 19),
              StepProgressBar(
                currentStep: 2,
                totalSteps: kTransferFlowTotalSteps,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveColor: Colors.grey.shade300,
                height: 6,
                segmentSpacing: 5,
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isReceiver ? "Receive via" : "Send via",
                      style: GoogleFonts.roboto(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Choose how to transfer. Bluetooth is free; Wi‑Fi options (unlimited, fast, no server) are Pro.",
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      TransferTypeTile(
                        title: "Bluetooth Transfer",
                        subtitle: "Basic device-to-device transfer. Available in the free version.",
                        icon: Icons.bluetooth_rounded,
                        isSelected: _selected == TransferType.bluetooth,
                        isPro: false,
                        onTap: () => _onTapTransferType(TransferType.bluetooth),
                      ),
                      const SizedBox(height: 14),
                      TransferTypeTile(
                        title: "Wi‑Fi Direct (Scan & connect)",
                        subtitle: "Scan and connect to the other device. Unlimited data, fast speed. Direct device-to-device—no server storage.",
                        icon: Icons.wifi_find_rounded,
                        isSelected: _selected == TransferType.wifiScanner,
                        isPro: true,
                        onTap: () => _onTapTransferType(TransferType.wifiScanner),
                      ),
                      const SizedBox(height: 14),
                      TransferTypeTile(
                        title: "Wi‑Fi Same Network",
                        subtitle: "Connect when both are on the same Wi‑Fi, then transfer. Unlimited data, fast. Direct device-to-device—no server.",
                        icon: Icons.wifi_rounded,
                        isSelected: _selected == TransferType.wifiSameNetwork,
                        isPro: true,
                        onTap: () => _onTapTransferType(TransferType.wifiSameNetwork),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Continue',
                            style: GoogleFonts.roboto(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
