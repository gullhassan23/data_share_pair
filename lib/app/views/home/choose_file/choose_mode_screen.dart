import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/app/controllers/progress_controller.dart';
import 'package:share_app_latest/components/build_choose_option.dart';
import 'package:share_app_latest/routes/app_routes.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';
import '../../../models/device_info.dart';

class ChooseModeScreen extends StatefulWidget {
  const ChooseModeScreen({super.key});

  @override
  State<ChooseModeScreen> createState() => _ChooseFileScreenState();
}

class _ChooseFileScreenState extends State<ChooseModeScreen> {
  @override
  void initState() {
    super.initState();
    // Reset all transfer state when entering this screen
    // This ensures sender side starts fresh after completing a transfer
    final progress = Get.find<ProgressController>();
    progress.reset();
    print('✅ Transfer state reset in ChooseFileScreen');
  }

  @override
  Widget build(BuildContext context) {
    final dynamic args = Get.arguments;
    if (args == null || args is! DeviceInfo) {
      print("❌ Error: Invalid or missing DeviceInfo arguments");
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(
          child: Text("Error: No device information provided"),
        ),
      );
    }

    final DeviceInfo device = args;
    print(
      "device info - IP: ${device.ip}, Name: ${device.name}, TransferPort: ${device.transferPort}, WSPort: ${device.wsPort}",
    );
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device name input and controls
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
                StepProgressBar(
                  currentStep: 4, // ✅ step increased
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
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// Title
                        Text(
                          "Choose Your Transfer Type",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 8),

                        /// Subtitle
                        Text(
                          "Please choose to copy everything or choose what you want to copy",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 20),

                        /// Options Row
                        Row(
                          children: [
                            /// Transfer All
                            Expanded(
                              child: BuildChooseOption(
                                icon: Icons.folder,
                                title: "Send",
                                subtitle: "",
                                color: const Color(0xffF6C667),
                                onTap: () {
                                  print('🔘 Send button clicked');
                                  Get.toNamed(
                                    AppRoutes.transferFile,
                                    arguments: {
                                      'device': device,
                                      'isSender': true, // SEND
                                    },
                                  );
                                },
                              ),
                            ),

                            const SizedBox(width: 16),

                            /// Select Files
                            Expanded(
                              child: BuildChooseOption(
                                icon: Icons.insert_drive_file,
                                title: "Recieve",
                                subtitle: "",
                                color: const Color(0xff6C8EF5),
                                onTap: () async {
                                  print('🔘 Receive button clicked');

                                  // Return to pairing screen and set receiver mode
                                  // Get.back(result: {
                                  //   'isSender': false,
                                  //   'device': device,
                                  // });

                                  Get.snackbar(
                                    "Wait for sender",
                                    "Wait for sender to send aaa file",
                                    backgroundColor: Colors.green.withOpacity(
                                      0.8,
                                    ),
                                    colorText: Colors.white,
                                    snackPosition: SnackPosition.BOTTOM,
                                    duration: const Duration(seconds: 2),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Mode selection buttons
              ],
            ),
          ),
        ),
      ),
    );
  }
}
