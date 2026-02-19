// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/routes/app_navigator.dart';

import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';

class ChooseMethodScan extends StatefulWidget {
  final bool isReciver;
  const ChooseMethodScan({Key? key, required this.isReciver}) : super(key: key);

  @override
  State<ChooseMethodScan> createState() => _ChooseMethodScanState();
}

class _ChooseMethodScanState extends State<ChooseMethodScan> {
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
              const SizedBox(height: 19),

              /// Back Row

              /// Progress Barss
              StepProgressBar(
                currentStep: 2,
                totalSteps: kTransferFlowTotalSteps,
                activeColor: Colors.blue,
                inactiveColor: Colors.white.withOpacity(0.6),
                height: 6,
                segmentSpacing: 5,
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),

              const SizedBox(height: 40),

              /// Main White Card
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
                      "Choose Transfer Method",
                      style: GoogleFonts.roboto(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Use either our core transfer method through\nWiFi or rely on third party services.",
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
                        TransferOptionIconCard(
                          title: "WiFi-direct",
                          icon: Icons.wifi,

                          onTap:
                              () => AppNavigator.toPairing(isReceiver: widget.isReciver),
                        ),
                        TransferOptionIconCard(
                          title: "QR",
                          icon: Icons.qr_code_scanner,
                          onTap: () {
                            if (widget.isReciver) {
                              AppNavigator.toQrReceiver();
                            } else {
                              AppNavigator.toQrSender(<String>[]);
                            }
                          },
                          // onTap: () => AppNavigator.toPairing(),
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

class TransferOptionIconCard extends StatelessWidget {
  const TransferOptionIconCard({
    super.key,
    required this.title,
    required this.icon,

    required this.onTap,
  });

  final String title;
  final IconData icon;

  final VoidCallback onTap;

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

          /// Coming Soon Ribbon
        ],
      ),
    );
  }
}
