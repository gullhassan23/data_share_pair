import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/components/bg_curve_Ellipes.dart';
import 'package:share_app_latest/components/on_boardingbutton.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/utils/transfer_animation.dart';

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
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  child: Container(
                    // height: 250,
                    // width: 350,
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
                    child: Column(
                      children: [
                        TransferAnimation(height: 160, isTransferring: true),

                        // ElevatedButton(
                        //   style: ElevatedButton.styleFrom(
                        //     backgroundColor: const Color(0xff00E5FF),
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(12),
                        //     ),
                        //   ),
                        //   onPressed: () {
                        //     AppNavigator.toHome();
                        //   },
                        //   child: Row(
                        //     mainAxisAlignment: MainAxisAlignment.center,
                        //     mainAxisSize: MainAxisSize.min,
                        //     children: [
                        //       Flexible(
                        //         child: Text(
                        //           "Start Transferring",
                        //           overflow: TextOverflow.ellipsis,
                        //           style: GoogleFonts.roboto(
                        //             color: Colors.white,
                        //             fontSize: 17,
                        //             fontWeight: FontWeight.w700,
                        //           ),
                        //         ),
                        //       ),
                        //       const SizedBox(width: 8),
                        //       const Icon(
                        //         Icons.arrow_forward,
                        //         size: 18,
                        //         color: Colors.white,
                        //       ),
                        //     ],
                        //   ),
                        // ),
                        On_BoardingButton(
                          ontap: () => AppNavigator.toHome(),
                          height: 40,
                          width: double.infinity,
                          text: "Start Transferring",
                          color: Color(0xff00E5FF),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                /// DESCRIPTION
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        "Easily transfer photos, videos, and files easily using WiFi Direct, Bluetooth, or QR Code.",
                        textAlign: TextAlign.center,
                        // style: TextStyle(color: Colors.grey.shade600),
                        style: GoogleFonts.roboto(color: Color(0xff72777F)),
                      ),
                    ],
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
