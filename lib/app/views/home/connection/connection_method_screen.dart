import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:share_app_latest/app/views/home/ChooseMethods/choose_method_scan.dart';
import 'package:share_app_latest/app/views/home/bluetooth/reciever_bluetooth.dart';
import 'package:share_app_latest/app/views/home/bluetooth/sender_bluetooth.dart';

import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';


class ConnectionMethodScreen extends StatefulWidget {
  const ConnectionMethodScreen({super.key, required this.isReceiver});

  final bool isReceiver;

  @override
  State<ConnectionMethodScreen> createState() => _ConnectionMethodScreenState();
}

class _ConnectionMethodScreenState extends State<ConnectionMethodScreen> {
  @override
  void initState() {
    super.initState();
    print('✅ ConnectionMethodScreen opened (isReceiver: ${widget.isReceiver})');
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
                    icon: Icon(Icons.arrow_back, color: Colors.black, size: 28),
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
              const SizedBox(height: 40),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      widget.isReceiver ? "Receive via" : "Send via",
                      style: GoogleFonts.roboto(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Choose QR code, Bluetooth, or WiFi Direct.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "For WiFi: ensure both devices are on the same network. If receiving, open the WiFi screen first and wait.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // TransferOptionIconCard(
                        //   title: "QR",
                        //   icon: Icons.qr_code_scanner,
                        //   onTap: () {
                        //     print(
                        //       '✅ Connection method chosen: QR (isReceiver: ${widget.isReceiver})',
                        //     );
                        //     AppNavigator.toConnectionMethod(
                        //       isReceiver: widget.isReceiver,
                        //     );
                        //     // if (widget.isReceiver) {
                        //     //   AppNavigator.toQrReceiver();
                        //     // } else {
                        //     //   AppNavigator.toQrSender(<String>[]);
                        //     // }
                        //   },
                        // ),
                        TransferOptionIconCard(
                          title: "Bluetooth",
                          icon: Icons.bluetooth_rounded,
                          onTap: () {
                            print(
                              '✅ Connection method chosen: Bluetooth (isReceiver: ${widget.isReceiver})',
                            );
                            if (widget.isReceiver) {
                              Get.to(() => const BluetoothReceiverScreen());
                            } else {
                              Get.to(() => const BluetoothSenderScreen());
                            }
                          },
                        ),
                        TransferOptionIconCard(
                          title: "WiFi",
                          icon: Icons.wifi,
                          onTap: () {
                            print(
                              '✅ Connection method chosen: WiFi Direct (isReceiver: ${widget.isReceiver})',
                            );
                            // AppNavigator.toPairing(
                            //   isReceiver: widget.isReceiver,
                            // );
                            Get.to(
                              () => ChooseMethodScan(
                                isReciver: widget.isReceiver,
                              ),
                            );
                            // AppNavigator.tochooseMethodscan();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
