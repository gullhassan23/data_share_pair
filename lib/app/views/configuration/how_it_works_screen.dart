import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/components/bg_container.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/services/analytics_screen_tracker.dart';

class HowItWorksScreen extends StatefulWidget {
  const HowItWorksScreen({super.key});

  @override
  State<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends State<HowItWorksScreen> {
  static const Color _textDark = Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    AnalyticsScreenTracker.trackScreen('how_it_works_screen');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: bg_container(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    _buildIntroCard(),
                    const SizedBox(height: 12),
                    _buildStepCard(
                      step: 'Step 1',
                      title: 'Connect to the same Wi-Fi',
                      description:
                          'Make sure both devices are on the same Wi-Fi network. This is required before pairing.',
                    ),
                    const SizedBox(height: 10),
                    _buildStepCard(
                      step: 'Step 2',
                      title: 'Show receiver QR code',
                      description:
                          'On the receiving device, open Receive mode to generate your QR code.',
                    ),
                    const SizedBox(height: 10),
                    _buildStepCard(
                      step: 'Step 3',
                      title: 'Scan and pair',
                      description:
                          'On the sending device, scan the QR code with your camera. A pairing request is sent to the receiver.',
                    ),
                    const SizedBox(height: 10),
                    _buildStepCard(
                      step: 'Step 4',
                      title: 'Accept and transfer',
                      description:
                          'After the receiver accepts, a secure local connection is created and files transfer instantly over Wi-Fi - no internet needed.',
                    ),
                    const SizedBox(height: 12),
                    _buildTipCard(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 18, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => AppNavigator.back(),
              icon: Icon(Icons.arrow_back),
              label: Text(
                'Back',
                style: GoogleFonts.roboto(
                  fontSize: 28 * 0.57,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade800,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          Text(
            'How It Works',
            style: GoogleFonts.roboto(
              fontSize: 34 * 0.57,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Share files between devices quickly and safely. Just pair once with QR code, then transfer over your local Wi-Fi.',
        style: GoogleFonts.roboto(
          fontSize: 15,
          height: 1.35,
          color: _textDark,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String step,
    required String title,
    required String description,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B6B6B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  height: 1.35,
                  color: _textDark,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB7D7FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Color(0xFF126AC7), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tip: If pairing does not appear, check that both devices are on the same Wi-Fi and keep screens unlocked during connection.',
              style: GoogleFonts.roboto(
                fontSize: 13.5,
                height: 1.35,
                color: _textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
