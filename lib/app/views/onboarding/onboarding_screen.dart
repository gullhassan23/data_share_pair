import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/components/bg_curve_Ellipes.dart';
import 'package:share_app_latest/routes/app_navigator.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          /// BLUE CURVED BACKGROUND
          ClipPath(
            clipper: CurvedBackground(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.45,
              width: double.infinity,
              color: const Color(0xFF5DADE2),
              child: CustomPaint(painter: BackgroundEllipses()),
            ),
          ),

          /// CONTENT
          SafeArea(
            child: Column(
              children: [
                /// TOP BAR
                // Padding(
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 16,
                //     vertical: 12,
                //   ),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: const [
                //       Icon(Icons.arrow_back, color: Colors.white),
                //       Text(
                //         "SKIP",
                //         style: TextStyle(
                //           color: Colors.white,
                //           fontWeight: FontWeight.w600,
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
                const SizedBox(height: 70),

                /// TITLE
                const Text(
                  "Share photos &\nvideos instantly",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 50),

                /// WHITE CARD / CONTAINER
                Container(
                  width: 350,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 210, // define height or Stack will collapse
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              "assets/icons/transfer_image.png",
                              height: 190,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),

                        Positioned(
                          top: 155,
                          left: 20,
                          right: 20,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff00E5FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              AppNavigator.toHome();
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    "Start Transferring",
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.roboto(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                /// DESCRIPTION
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    "Connect with friends nearby or across the world and share memories in original quality without delays.",
                    textAlign: TextAlign.center,
                    // style: TextStyle(color: Colors.grey.shade600),
                    style: GoogleFonts.roboto(color: Color(0xff72777F)),
                  ),
                ),

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
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
