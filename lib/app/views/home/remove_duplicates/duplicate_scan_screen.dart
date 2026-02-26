import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/app/controllers/duplicate_controller.dart';
import 'package:share_app_latest/routes/app_routes.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';

class DuplicateScanScreen extends StatefulWidget {
  const DuplicateScanScreen({super.key});

  @override
  State<DuplicateScanScreen> createState() => _DuplicateScanScreenState();
}

class _DuplicateScanScreenState extends State<DuplicateScanScreen> {
  late final DuplicateController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(DuplicateController());
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  Future<void> _startScan() async {
    await _ctrl.scanDuplicates();
    if (!mounted) return;
    if (_ctrl.error.value.isNotEmpty) {
      Get.snackbar(
        'Error',
        _ctrl.error.value,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }
    if (_ctrl.isEmpty) {
      Get.snackbar(
        'No duplicates found',
        'No duplicate images or videos were found.',
        backgroundColor: Colors.blue.withOpacity(0.8),
        colorText: Colors.white,
      );
      Get.delete<DuplicateController>(force: true);
      Get.offAllNamed(AppRoutes.home);
      return;
    }
    Get.offNamed(AppRoutes.duplicatePreview);
  }

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
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Get.delete<DuplicateController>(force: true);
                      Get.offAllNamed(AppRoutes.home);
                    },
                    icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Remove Duplicates',
                    style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 19),
              StepProgressBar(
                currentStep: 1,
                totalSteps: kTransferFlowTotalSteps,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveColor: Colors.grey.shade300,
                height: 6,
                segmentSpacing: 5,
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Center(
                  child: Obx(() {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_ctrl.scanning.value) ...[
                          const CircularProgressIndicator(),
                          const SizedBox(height: 24),
                          Text(
                            _ctrl.scanStatus.value,
                            style: GoogleFonts.roboto(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ] else
                          const SizedBox.shrink(),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
