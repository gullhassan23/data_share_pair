// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:share_app_latest/components/bg_curve_Ellipes.dart';
// import 'package:share_app_latest/components/step_progress_bar.dart';
// import 'package:share_app_latest/routes/app_navigator.dart';
// import 'package:share_app_latest/utils/constants.dart';

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         width: double.infinity,
//         height: double.infinity,
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [Color(0xffEEF4FF), Color(0xffF8FAFF), Color(0xffFFFFFF)],
//           ),
//         ),
//         child: Column(
//           children: [
//             // ClipPath(
//             //   clipper: CurvedBackground(),
//             //   child: Container(
//             //     height: MediaQuery.of(context).size.height * 0.45,
//             //     width: double.infinity,
//             //     color: const Color(0xFF5DADE2),
//             //     child: CustomPaint(painter: BackgroundEllipses()),
//             //   ),
//             // ),
//             SafeArea(
//               child: Column(
//                 children: [
//                   const SizedBox(height: 24),
//                   StepProgressBar(
//                     currentStep: 1,
//                     totalSteps: kTransferFlowTotalSteps,
//                     activeColor: Colors.blue,
//                     inactiveColor: Colors.white.withOpacity(0.5),
//                     height: 6,
//                     segmentSpacing: 5,
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 24,
//                       vertical: 10,
//                     ),
//                   ),
//                   const SizedBox(height: 48),

//                   /// Hero card
//                   Container(
//                     margin: const EdgeInsets.only(top: 80, left: 12, right: 12),
//                     padding: const EdgeInsets.all(16),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(16),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.08),
//                           blurRadius: 20,
//                           offset: const Offset(0, 10),
//                         ),
//                       ],
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.center,
//                       children: [
//                         // Container(s
//                         //   height: 50,
//                         //   width: 50,
//                         //   decoration: BoxDecoration(
//                         //     borderRadius: BorderRadius.circular(50),
//                         //     color: Colors.white,
//                         //   ),
//                         //   child: Padding(
//                         //     padding: const EdgeInsets.all(8.0),
//                         //     child: Image.asset(
//                         //       "assets/icons/galleryimage.png",
//                         //       height: 10,
//                         //       width: 10,
//                         //     ),
//                         //   ),
//                         // ),
//                         SizedBox(height: 20),
//                         Text(
//                           "Choose  Tranfer method",
//                           style: GoogleFonts.roboto(
//                             color: Colors.black,
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         Text(
//                           textAlign: TextAlign.center,
//                           "TRANSFER ALL YOUR DATA IN ONE TAP. SECURE, FAST AND RELIABLE MIGRATION.",
//                           style: GoogleFonts.roboto(
//                             color: Colors.black,
//                             fontSize: 13,
//                           ),
//                         ),
//                         SizedBox(height: 30),
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 20),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               _TransferMethodCard(
//                                 title: 'Same WiFi',
//                                 subtitle:
//                                     'Discover and pair on the same network',
//                                 icon: Icons.wifi_rounded,
//                                 gradient: const [
//                                   Color(0xff667eea),
//                                   Color(0xff764ba2),
//                                 ],
//                                 onTap: () => AppNavigator.toPairing(),
//                               ),
//                               const SizedBox(height: 16),
//                               _TransferMethodCard(
//                                 title: 'Bluetooth',
//                                 subtitle: 'Send or receive via Bluetooth',
//                                 icon: Icons.bluetooth_rounded,
//                                 gradient: const [
//                                   Color(0xff2193b0),
//                                   Color(0xff6dd5ed),
//                                 ],
//                                 onTap:
//                                     () => AppNavigator.toBluetoothConnection(),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                   const SizedBox(height: 30),

//                   /// Transfer method cards: WiFi (same network) & Bluetooth
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
                        TransferOptionCard(
                          title: "Wi-Fi",
                          icon: Icons.wifi,

                          onTap: () => AppNavigator.toPairing(),
                        ),

                        TransferOptionCard(
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

// class _TransferMethodCard extends StatelessWidget {
//   const _TransferMethodCard({
//     required this.title,
//     required this.subtitle,
//     required this.icon,
//     required this.gradient,
//     required this.onTap,
//   });

//   final String title;
//   final String subtitle;
//   final IconData icon;
//   final List<Color> gradient;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     // return Material(
//     //   color: Colors.transparent,
//     //   child: InkWell(
//     //     onTap: onTap,
//     //     borderRadius: BorderRadius.circular(20),
//     //     child: Container(
//     //       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
//     //       decoration: BoxDecoration(
//     //         gradient: LinearGradient(
//     //           colors: gradient,
//     //           begin: Alignment.topLeft,
//     //           end: Alignment.bottomRight,
//     //         ),
//     //         borderRadius: BorderRadius.circular(20),
//     //         boxShadow: [
//     //           BoxShadow(
//     //             color: Colors.black.withOpacity(0.15),
//     //             blurRadius: 20,
//     //             offset: const Offset(0, 8),
//     //           ),
//     //         ],
//     //       ),
//     //       child: Container(
//     //         padding: const EdgeInsets.all(14),
//     //         decoration: BoxDecoration(
//     //           color: Colors.white.withOpacity(0.25),
//     //           borderRadius: BorderRadius.circular(16),
//     //         ),
//     //         child: Icon(icon, size: 36, color: Colors.white),
//     //       ),
//     //     ),
//     //   ),
//     // );

//     return Container(
//       height: 100,
//       width: 100,
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.blue),
//         gradient: const LinearGradient(
//           colors: [Color(0xffF6F6F6), Color(0xffEDEDED)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Icon(icon, size: 36, color: Colors.blue),
//     );
//   }
// }
class TransferOptionCard extends StatelessWidget {
  const TransferOptionCard({
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
