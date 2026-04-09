import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/components/bg_container.dart';
import 'package:share_app_latest/routes/app_navigator.dart';

class HowItWorksScreen extends StatefulWidget {
  const HowItWorksScreen({super.key});

  @override
  State<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends State<HowItWorksScreen> {
  static const Color _textDark = Color(0xFF333333);
  bool _isFirstExpanded = true;
  bool _isSecondExpanded = true;

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
                    _buildQuestionTile(
                      title: 'What is Copy My Data?',
                      isExpanded: _isFirstExpanded,
                      onTap: () {
                        setState(() {
                          _isFirstExpanded = !_isFirstExpanded;
                        });
                      },
                    ),
                    if (_isFirstExpanded) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "Enable either put the OTP and files will begin to be shared.",
                          style: GoogleFonts.roboto(
                            fontSize: 29 * 0.5,
                            height: 1.3,
                            color: _textDark,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _buildQuestionTile(
                      title: 'How does Copy My Data work?',
                      isExpanded: _isSecondExpanded,
                      onTap: () {
                        setState(() {
                          _isSecondExpanded = !_isSecondExpanded;
                        });
                      },
                    ),
                    if (_isSecondExpanded) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "Enable either Wi-Fi hotspot or connect both phones to the same Wifi network. Make sure you have the Copy My Data app on both phones installed, and have one phone set to Send the other sent on Receive. On the sender phone, select the files you want to share, on the receiving phone select the sender's phone out of the list. Make sure to input the OTP and files will begin to be shared.",
                          style: GoogleFonts.roboto(
                            fontSize: 29 * 0.5,
                            height: 1.3,
                            color: _textDark,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
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
            'How it works?',
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

  Widget _buildQuestionTile({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
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
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: _textDark,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
