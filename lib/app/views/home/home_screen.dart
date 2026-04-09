import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/app/controllers/progress_controller.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/app/views/home/ChooseMethods/choose_method_scan.dart';
import 'package:share_app_latest/components/bg_container.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/services/subscription_iap_service.dart';
import 'package:share_app_latest/config/ad_unit_ids.dart';
import 'package:share_app_latest/utils/constants.dart';

import 'package:share_app_latest/utils/tab_bar_progress.dart';
import 'package:share_app_latest/widgets/ad_large_rect_widget.dart';

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
    final premium = Get.find<PremiumController>();
    return Scaffold(
      body: bg_container(
        child: SafeArea(
          child: Obx(() {
            final showAds =
                AdUnitIds.kForceFreeUserForAdTesting
                    ? true
                    : !(premium.isPremium ||
                        SubscriptionIAPService().isPremium);
            return Column(
              children: [
                const SizedBox(height: 19),

                /// Back Row
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        AppNavigator.toOnboarding();
                      },
                      icon: Icon(
                        Icons.arrow_back,
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
                    TextButton.icon(
                      onPressed: () => AppNavigator.toPremium(),
                      icon: const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 20,
                      ),
                      label: Text(
                        'Premium',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
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
                          "Start Transfer",
                          style: GoogleFonts.roboto(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Choose an option to start transferring\n between devices.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),

                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap:
                                    () => Get.to(
                                      () => ChooseMethodScan(isReciver: false),
                                    ),
                                child: Image.asset(
                                  'assets/icons/send.png',
                                  height: 130,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap:
                                    () => Get.to(
                                      () => ChooseMethodScan(isReciver: true),
                                    ),
                                child: Image.asset(
                                  'assets/icons/Receive.png',
                                  height: 130,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            // TransferOptionCard(
                            //   title: "Send Files",
                            //   image: ImageRes.sendFiles,
                            //   // onTap:
                            //   //     () => AppNavigator.toConnectionMethod(
                            //   //       isReceiver: false,
                            //   //     ),
                            //   onTap:
                            //       () => Get.to(
                            //         () => ChooseMethodScan(isReciver: false),
                            //       ),
                            // ),
                          ],
                        ),

                        // const SizedBox(height: 16),
                        // _RemoveDuplicatesButton(),
                        // TransferOptionCard(
                        //   title: 'Remove Duplications',
                        //   image: ImageRes.delete,
                        //   onTap: () async {
                        //     final granted = await requestMediaPermissions();
                        //     if (!granted) {
                        //       Get.snackbar(
                        //         'Permission needed',
                        //         'Gallery access is required to find duplicate photos and videos.',
                        //         backgroundColor: Colors.orange.withOpacity(0.8),
                        //         colorText: Colors.white,
                        //       );
                        //       return;
                        //     }
                        //     AppNavigator.toRemoveDuplicates();
                        //   },
                        // ),
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
