import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/components/bg_container.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/services/admob_service.dart';
import 'package:share_app_latest/services/one_time_free_send_store.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';

class TransferCompleteScreen extends StatefulWidget {
  const TransferCompleteScreen({super.key, required this.isSender});

  final bool isSender;

  @override
  State<TransferCompleteScreen> createState() => _TransferCompleteScreenState();
}

class _TransferCompleteScreenState extends State<TransferCompleteScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.isSender) {
      // One-time free send is consumed after first successful sender transfer.
      OneTimeFreeSendStore.markUsed();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AdMobService.instance.showInterstitial();
    });
  }

  void _goNext() {
    if (widget.isSender) {
      AppNavigator.toHome();
    } else {
      AppNavigator.toReceivedFiles(device: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: bg_container(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _goNext(),
                        icon: Icon(Icons.adaptive.arrow_back),
                      ),
                      Text(
                        "Done",
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  StepProgressBar(
                    currentStep: 6,
                    totalSteps: kTransferFlowTotalSteps,
                    activeColor: Theme.of(context).colorScheme.primary,
                    inactiveColor: Colors.grey.shade300,
                    height: 6,
                    segmentSpacing: 5,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFE9ECFF), Color(0xFF6378F5)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              'assets/icons/Files Transfer Folder.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.isSender
                                ? 'Send Complete!'
                                : 'Receive Complete!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.roboto(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Thanks for using Copy My Data to transfer your files! We hope you enjoyed your experience with the app.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.roboto(
                              fontSize: 15,
                              height: 1.25,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
