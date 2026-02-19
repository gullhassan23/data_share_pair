import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/app/views/home/ChooseMethods/choose_method_scan.dart';

import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';

class ChooseMethod extends StatefulWidget {
  const ChooseMethod({super.key});

  @override
  State<ChooseMethod> createState() => _ChooseMethodState();
}

class _ChooseMethodState extends State<ChooseMethod> {
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
                currentStep: 1,
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
                          title: "WiFi",
                          icon: Icons.wifi,
                          onTap: () => AppNavigator.tochooseMethodscan(),
                          // onTap: () => AppNavigator.toPairing(),
                        ),

                        TransferOptionIconCard(
                          title: 'Bluetooth',

                          icon: Icons.bluetooth_rounded,
                          onTap: () => null,
                          // onTap: () => AppNavigator.toBluetoothConnection(),
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
