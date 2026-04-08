import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/components/bg_container.dart';
import 'package:share_app_latest/components/on_boardingbutton.dart';
import 'package:get/get.dart';
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/routes/app_navigator.dart';

import 'package:share_app_latest/widgets/ad_large_rect_widget.dart';
import 'package:share_app_latest/services/subscription_iap_service.dart';
import 'package:share_app_latest/config/ad_unit_ids.dart';

class getStartedScreen extends StatelessWidget {
  const getStartedScreen({super.key});

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
                /// TOP BAR
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.menu,
                          color: Color(0xff4e66fc),
                          size: 30,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.settings,
                          color: Color(0xff4e66fc),
                          size: 30,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// WHITE CARD / CONTAINER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    // height: cardHeight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFE3F2FD), // light bluer
                          // mid blues
                          // Color.fromARGB(255,s 133, 183, 226),
                          Color.fromARGB(255, 112, 126, 215),
                          // Color.fromARGB(255, 118, 125, 173), // darker blue
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
                        // TransferAnimation(height: 160, isTransferring: true),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Copy my data",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.roboto(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Transfer all your data in\none tap.",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.roboto(
                                      fontSize: 15,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: SizedBox(
                                  height: 170,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned.fill(
                                        child: Image.asset(
                                          "assets/icons/Circle.png",
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.center,
                                        child: Image.asset(
                                          "assets/icons/File Folder.png",
                                          height: 56,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      Positioned(
                                        left: -6,
                                        top: 72,
                                        child: Image.asset(
                                          "assets/icons/Like.png",
                                          height: 34,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      Positioned(
                                        top: -2,
                                        right: -4,
                                        child: Image.asset(
                                          "assets/icons/Thums Up.png",
                                          height: 46,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 2,
                                        left: 10,
                                        child: Image.asset(
                                          "assets/icons/QR.png",
                                          height: 20,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 15.0, right: 15.0),
                  child: On_BoardingButton(
                    ontap: () => AppNavigator.toHome(),
                    height: 45,
                    width: double.infinity,
                    text: "Start Transferring",
                    color: Color.fromARGB(255, 87, 107, 241),
                  ),
                ),

                /// DESCRIPTION
                // Padding(
                //   padding: const EdgeInsets.symmetric(horizontal: 32),
                //   child: Column(
                //     children: [
                //       Text(
                //         "Easily transfer photos, videos, and files easily using WiFi Direct, Bluetooth, or QR Code.",
                //         textAlign: TextAlign.center,
                //         style: GoogleFonts.roboto(
                //           color: const Color(0xff72777F),
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
                if (showAds)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 24),
                      child: AdLargeRectWidget(),
                    ),
                  )
                else
                  const SizedBox(height: 24),

                /// BUTTON
                // Padding(
                //   padding: const EdgeInsets.symmetric(horizontal: 32),
                //   child: SizedBox(
                //     width: double.infinity,
                //     height: 48,
                //     child: ElevatedButton(
                //       style: ElevatedButton.styleFrom(
                //         backgroundColor: Color(0xff00E5FF),
                //         shape: RoundedRectangleBorder(
                //           borderRadius: BorderRadius.circular(12),
                //         ),
                //       ),
                //       onPressed: () {
                //         AppNavigator.toHome();
                //       },
                //       child: Text(
                //         "GET STARTED",
                //         style: GoogleFonts.roboto(
                //           color: Colors.white,
                //           fontSize: 16,
                //           fontWeight: FontWeight.w700,
                //         ),
                //         // style: TextStyle(fontWeight: FontWeight.bold),
                //       ),
                //     ),
                //   ),
                // ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
