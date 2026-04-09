import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/services/transfer_state_persistence.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double progress = 0.0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() async {
    final connectivity = await Connectivity().checkConnectivity();
    _fakeProgress(isOnline: connectivity != ConnectivityResult.none);
  }

  void _fakeProgress({required bool isOnline}) {
    timer = Timer.periodic(Duration(milliseconds: isOnline ? 70 : 180), (
      timer,
    ) {
      setState(() => progress += 0.02);

      if (progress >= 1.0) {
        timer.cancel();
        _goNext();
      }
    });
  }

  void _goNext() async {
    final hadTransfer = await TransferStatePersistence.hadTransferInProgress();
    if (hadTransfer) {
      final persisted = await TransferStatePersistence.getPersistedState();
      AppNavigator.toTransferRecovery(persisted);
    } else {
      AppNavigator.toOnboarding();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD3D4F7), Color(0xFF7D86F4)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final w = constraints.maxWidth;
              return Stack(
                children: [
                  Positioned(
                    left: w * 0.06,
                    right: w * 0.06,
                    top: h * 0.02,
                    height: h * 0.50,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          "assets/icons/Floating Files.png",
                          fit: BoxFit.contain,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: w * 0.03),
                          child: Image.asset(
                            "assets/icons/Confetti.png",
                            fit: BoxFit.contain,
                          ),
                        ),
                        // Align(
                        //   alignment: Alignment.bottomCenter,
                        //   child: Image.asset(
                        //     "assets/icons/logo.png.png",
                        //     height: h * 0.23,
                        //     fit: BoxFit.contain,
                        //   ),
                        // ),
                      ],
                    ),
                  ),

                  Positioned(
                    left: 16,
                    right: 56,
                    top: h * 0.45,
                    child: Center(
                      child: Image.asset(
                        "assets/icons/File Folder.png",
                        height: h * 0.14,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: h * 0.63,
                    child: Column(
                      children: [
                        Image.asset(
                          "assets/icons/logo.png.png",
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: "Copy My Data Pro",
                                style: GoogleFonts.openSans(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFECEEF8),
                                  letterSpacing: 0.2,
                                ),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.top,
                                child: Transform.translate(
                                  offset: const Offset(1, -7),
                                  child: Text(
                                    "+",
                                    style: GoogleFonts.openSans(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFECEEF8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),

                        Text(
                          "SHARE INSTANTLY, SECURELY",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.openSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFE7EAF9),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: h * 0.03,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.20),
                          width: 0.6,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 12,
                          backgroundColor: const Color(0xFFC5CCE3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF23B7E8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
