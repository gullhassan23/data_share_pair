// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/components/bg_container.dart';

import 'package:share_app_latest/routes/app_navigator.dart';

import 'package:share_app_latest/services/subscription_iap_service.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';
import 'package:share_app_latest/widgets/ad_large_rect_widget.dart';

class ChooseMethodScan extends StatefulWidget {
  final bool isReciver;
  const ChooseMethodScan({Key? key, required this.isReciver}) : super(key: key);

  @override
  State<ChooseMethodScan> createState() => _ChooseMethodScanState();
}

class _ChooseMethodScanState extends State<ChooseMethodScan> {
  @override
  Widget build(BuildContext context) {
    final premium = Get.find<PremiumController>();
    return Scaffold(
      body: bg_container(
        child: SafeArea(
          child: Obx(() {
            final isAndroid = GetPlatform.isAndroid;
            final isPremium =
                premium.isPremium || SubscriptionIAPService().isPremium;
            return Column(
              children: [
                const SizedBox(height: 19),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Get.back();
                      },
                      icon: Icon(
                        Icons.adaptive.arrow_back,
                        color: Colors.black,
                        size: 28,
                      ),
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
                    const Spacer(),
                    if (!isAndroid)
                      TextButton.icon(
                        onPressed: () => AppNavigator.toPremium(),
                        icon: const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 20,
                        ),
                        label: Text(
                          isPremium ? 'Premium' : 'Free Plan',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                  ],
                ),

                /// Back Row

                /// Progress Barss
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

                /// Main White Card
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFE3F2FD),

                          Color.fromARGB(255, 112, 126, 215),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.isReciver ? "Receiver Via" : "Sender Via",
                          style: GoogleFonts.roboto(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Use either our core transfer method through\nWiFi and QR code",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),

                        const SizedBox(height: 18),
                        Divider(color: Colors.grey.shade300),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // TransferOptionIconCard(
                            //   title: "WiFi-direct",
                            //   icon: Icons.wifi,

                            //   onTap:
                            //       () => AppNavigator.toPairing(
                            //         isReceiver: widget.isReciver,
                            //       ),
                            // ),
                            InkWell(
                              onTap:
                                  () => AppNavigator.toPairing(
                                    isReceiver: widget.isReciver,
                                  ),
                              child: Image.asset(
                                'assets/icons/Wi-Fi.png',
                                height: 150,
                                width: 150,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                if (widget.isReciver) {
                                  AppNavigator.toQrReceiver();
                                } else {
                                  AppNavigator.toQrSender(<String>[]);
                                }
                              },
                              child: Image.asset(
                                'assets/icons/QR.png',
                                height: 150,
                                width: 150,
                              ),
                            ),
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
            );
          }),
        ),
      ),
    );
  }
}

class TransferOptionIconCard extends StatelessWidget {
  const TransferOptionIconCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.showLock = false,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool showLock;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xffF2F6FF), const Color(0xffEAF0FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200, width: 1.3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 30, color: Colors.blue),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          if (showLock)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(Icons.lock, size: 18, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
