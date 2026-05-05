import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/components/bg_container.dart';
import 'package:share_app_latest/components/on_boardingbutton.dart';
import 'package:get/get.dart';
import 'dart:math' as math;
import 'package:share_app_latest/app/controllers/premium_controller.dart';
import 'package:share_app_latest/routes/app_navigator.dart';

import 'package:share_app_latest/widgets/ad_large_rect_widget.dart';
import 'package:share_app_latest/widgets/ad_banner_widget.dart';
import 'package:share_app_latest/services/subscription_iap_service.dart';
import 'package:share_app_latest/config/ad_unit_ids.dart';

class getStartedScreen extends StatefulWidget {
  const getStartedScreen({super.key});

  @override
  State<getStartedScreen> createState() => _getStartedScreenState();
}

class _getStartedScreenState extends State<getStartedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final premium = Get.find<PremiumController>();
    return Scaffold(
      body: bg_container(
        child: SafeArea(
          child: Obx(() {
            final isPremiumFromController =
                premium.subscriptionStatus.value?.isPremium ?? false;
            final showAds =
                AdUnitIds.kForceFreeUserForAdTesting
                    ? true
                    : !(isPremiumFromController ||
                        SubscriptionIAPService().isPremium);
            return Column(
              children: [
                /// TOP BAR
                Row(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: IconButton(
                          onPressed: () => AppNavigator.toConfiguration(),
                          icon: const Icon(
                            Icons.menu,
                            color: Color(0xff4e66fc),
                            size: 30,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
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
                        showAds ? 'Free Plan' : 'Premium',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),

                // Banner Ads (Android only)
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                  ...[
                    const SizedBox(height: 4),
                    const Center(child: AdBannerWidget()),
                    const SizedBox(height: 12),
                  ],

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
                                  child: AnimatedBuilder(
                                    animation: _ringController,
                                    builder: (context, _) {
                                      final angle =
                                          _ringController.value * 2 * math.pi;
                                      return Stack(
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
                                              "assets/icons/File Share logo.png",
                                              height: 56,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                          Positioned(
                                            left:
                                                85 + math.cos(angle) * 56 - 17,
                                            top: 85 + math.sin(angle) * 36 - 17,
                                            child: Image.asset(
                                              "assets/icons/Like.png",
                                              height: 34,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                          Positioned(
                                            left:
                                                85 +
                                                math.cos(
                                                      angle + (2 * math.pi / 3),
                                                    ) *
                                                    60 -
                                                21,
                                            top:
                                                85 +
                                                math.sin(
                                                      angle + (2 * math.pi / 3),
                                                    ) *
                                                    42 -
                                                21,
                                            child: Image.asset(
                                              "assets/icons/Thums Up.png",
                                              height: 42,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
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
