import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/routes/app_navigator.dart';

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

  void _goNext() {
    AppNavigator.toOnboarding();
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
            colors: [Color(0xFFBFE9FF), Colors.white],
          ),
        ),
        child: Column(
          children: [
            const Spacer(),

            /// LOGO
            Image.asset("assets/icons/logo.png", width: 100, height: 100),

            const SizedBox(height: 16),

            /// APP NAME
            Text(
              "FILE SHARE",

              style: GoogleFonts.bebasNeue(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3BA4F7),
              ),
            ),

            const SizedBox(height: 4),

            /// SUBTITLE
            Text(
              "SHARE INSTANTLY, SECURELY",
              style: GoogleFonts.openSans(
                fontSize: 12,

                color: Color(0xFF3BA4F7),
              ),
            ),

            const Spacer(),

            // LOADING BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ClipRRect(
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.blue.shade100,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF3BA4F7),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            /// LOADING TEXT + %
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "LOADING",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    "${(progress * 100).toInt()}%",
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            /// VERSION
            const Text(
              "VERSION 1.0",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
