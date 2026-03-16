import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/app/views/home/ChooseMethods/choose_method_scan.dart';
import 'package:share_app_latest/app/views/home/bluetooth/reciever_bluetooth.dart';
import 'package:share_app_latest/app/views/home/bluetooth/sender_bluetooth.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/services/admob_service.dart';
import 'package:share_app_latest/services/rewarded_access_store.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';
import 'package:share_app_latest/widgets/ad_large_rect_widget.dart';

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
    final premium = Get.find<PremiumController>();
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
                    onPressed: () async {
                      await AdMobService.instance.showInterstitial();
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
              Expanded(
                child: Container(
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
                          Obx(() {
                            final isPremium = premium.isPremium;
                            return TransferOptionIconCard(
                              title: "WiFi",
                              icon: Icons.wifi,
                              showLock: !isPremium,
                              onTap: () async {
                                if (isPremium) {
                                  print(
                                    '✅ Connection method chosen: WiFi Direct (isReceiver: ${widget.isReceiver})',
                                  );
                                  Get.to(
                                    () => ChooseMethodScan(
                                      isReciver: widget.isReceiver,
                                    ),
                                  );
                                  return;
                                }

                                // Try to use a rewarded credit first.
                                final usedCredit =
                                    await RewardedAccessStore.consumeCreditIfAvailable();
                                if (usedCredit) {
                                  print(
                                    '✅ WiFi Direct unlocked via rewarded credit (isReceiver: ${widget.isReceiver})',
                                  );
                                  Get.to(
                                    () => ChooseMethodScan(
                                      isReciver: widget.isReceiver,
                                    ),
                                  );
                                  return;
                                }

                                // No credits: offer Premium or Watch Ad.
                                if (!mounted) return;
                                await showModalBottomSheet<void>(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                  ),
                                  builder: (ctx) {
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        16,
                                        20,
                                        24,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Unlock Wi‑Fi Direct',
                                            style: GoogleFonts.roboto(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Watch a short ad to unlock one Wi‑Fi transfer, or go Premium for unlimited transfers with no limits.',
                                            style: GoogleFonts.roboto(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                Navigator.of(ctx).pop();
                                                final shown = await AdMobService
                                                    .instance
                                                    .showRewarded(
                                                  onEarned: (_, __) async {
                                                    await RewardedAccessStore
                                                        .addCredit();
                                                  },
                                                );
                                                if (!shown) return;
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    12,
                                                  ),
                                                ),
                                              ),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 4,
                                                  horizontal: 4,
                                                ),
                                                child: Text(
                                                  'Watch ad to unlock Wi‑Fi',
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  softWrap: true,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton(
                                              onPressed: () {
                                                Navigator.of(ctx).pop();
                                                AppNavigator.toPremium();
                                              },
                                              style: OutlinedButton.styleFrom(
                                                shape:
                                                    RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    12,
                                                  ),
                                                ),
                                              ),
                                              child: const Text(
                                                'Go Premium (unlimited)',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AdLargeRectWidget(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}