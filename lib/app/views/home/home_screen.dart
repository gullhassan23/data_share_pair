import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/app/controllers/progress_controller.dart';

import 'package:share_app_latest/components/transfer_option_card.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/images_resource.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Reset all transfer state when entering this screen
    // This ensures sender side starts fresh after completing a transfer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final progress = Get.find<ProgressController>();
      progress.reset();
    });
    print('✅ Transfer state reset in SendReceiveScreen');
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
              const SizedBox(height: 19),

              /// Back Row
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

              /// Progress Barss
              StepProgressBar(
                currentStep: 1,
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
                      "Start Transfer",
                      style: GoogleFonts.roboto(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Choose an option to start transferring between devices.",
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
                        TransferOptionCard(
                          title: "Send Files",
                          image: ImageRes.sendFiles,
                          onTap:
                              () => AppNavigator.toConnectionMethod(
                                isReceiver: false,
                              ),
                        ),

                        TransferOptionCard(
                          title: 'Receive Files',
                          image: ImageRes.recieveFiles,
                          onTap:
                              () => AppNavigator.toConnectionMethod(
                                isReceiver: true,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              /// ACTION BUTTONS
              // Padding(
              //   padding: const EdgeInsets.all(8.0),
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.center,
              //     children: [
              //       // Send Button
              //       Expanded(
              //         child: Custombutton(
              //           textColor: Colors.white,
              //           colors: [Color(0xff04E0FF), Color(0xff6868FF)],
              //           text: "Send Files",
              //           ontap: () async {
              //             // Show file selection dialog first
              //             // _showFileSelectionDialog();
              //             // showSendOptions(context );
              //             showSendOptions(context);
              //           },
              //         ),
              //       ),

              //       const SizedBox(width: 16),

              //       // Receive Button
              //       Expanded(
              //         child: Custombutton(
              //           textColor: Colors.white,
              //           colors: [Color(0xffFF6B6B), Color(0xffFF8E53)],
              //           text: "Receive Files",
              //           ontap: () {
              //             showReceiveOptions(context);
              //             // AppNavigator.toQrReceiver();
              //           },
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
