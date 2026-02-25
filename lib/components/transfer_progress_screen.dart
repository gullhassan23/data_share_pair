import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_app_latest/app/controllers/progress_controller.dart';
import 'package:share_app_latest/app/controllers/transfer_controller.dart';
import 'package:share_app_latest/app/models/device_info.dart';
import 'package:share_app_latest/components/custom_upload_bar.dart';

import 'package:share_app_latest/utils/constants.dart';

import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';

class TransferProgressScreen extends StatefulWidget {
  const TransferProgressScreen({super.key});

  @override
  State<TransferProgressScreen> createState() => _TransferProgressScreenState();
}

class _TransferProgressScreenState extends State<TransferProgressScreen> {
  DeviceInfo? device;
  String? filePath;
  String? fileName;
  String? senderTempPath;
  bool isSender = true; // Determine mode based on filePath

  late final ProgressController progress;
  late final TransferController transfer;

  @override
  void initState() {
    super.initState();

    // Get arguments - defensive logging of raw args
    final args = Get.arguments;
    print('🔍 DEBUG: TransferProgressScreen raw Get.arguments: $args');
    if (args != null && args is Map) {
      print(
        '🔍 DEBUG: args keys=${args.keys.toList()}, device type=${args['device']?.runtimeType}, filePath type=${args['filePath']?.runtimeType}, fileName type=${args['fileName']?.runtimeType}',
      );
    }

    if (args == null || args is! Map) {
      print(
        "❌ Invalid arguments passed to TransferProgressScreen (null or not Map)",
      );
      _showErrorAndExit('Invalid navigation data. Please try again.');
      return;
    }

    device = args['device'] is DeviceInfo ? args['device'] as DeviceInfo : null;
    filePath = args['filePath'] is String ? args['filePath'] as String : null;
    fileName = args['fileName'] is String ? args['fileName'] as String : null;
    senderTempPath = args['senderTempPath'] is String ? args['senderTempPath'] as String : null;

    print('🔍 DEBUG: TransferProgressScreen arguments parsed:');
    print('  - device: $device');
    print('  - device?.name: ${device?.name}');
    print('  - device?.ip: ${device?.ip}');
    print('  - device?.transferPort: ${device?.transferPort}');
    print('  - filePath: $filePath');
    print('  - fileName: $fileName');

    // Determine mode: if filePath is not null and not empty, we're sender
    final hasFilePath = (filePath ?? '').isNotEmpty;
    isSender = hasFilePath;

    if (device == null) {
      print("❌ CRITICAL: Missing device in TransferProgressScreen");
      _showErrorAndExit(
        'Device information is missing. Please restart the pairing process.',
      );
      return;
    }

    final safeDevice = device!;
    // Validate device has required connection info
    final deviceIp = safeDevice.ip;
    final deviceTransferPort = safeDevice.transferPort;
    if (deviceIp.isEmpty) {
      print("❌ CRITICAL: Device IP is empty in TransferProgressScreen");
      _showErrorAndExit('Device IP address is missing');
      return;
    }

    if (deviceTransferPort <= 0) {
      print(
        "❌ CRITICAL: Device transfer port is invalid in TransferProgressScreen",
      );
      _showErrorAndExit('Device transfer port is invalid');
      return;
    }

    // Sender mode requires filePath - validate before starting transfer
    if (isSender && (filePath ?? '').isEmpty) {
      print("❌ CRITICAL: Sender mode but filePath is null or empty");
      _showErrorAndExit('File path is missing. Cannot start transfer.');
      return;
    }

    // Use existing controllers - DO NOT create new instances
    progress = Get.find<ProgressController>();
    transfer = Get.find<TransferController>();

    print("✅ TransferProgressScreen initialized");
    print("✅ Mode: ${isSender ? 'SENDER' : 'RECEIVER'}");
    print("✅ Device: ${device?.name ?? 'Unknown'}");
    print("✅ File: $fileName");

    // Completion handling (snackbar + navigation) lives in TransferController so it runs
    // even when this screen is disposed (e.g. app backgrounded). Progress reset is done
    // when starting a new transfer in TransferController.sendFile / receiver callback.

    if (isSender) {
      _startTransfer();
    } else {
      print("🔄 Receiver mode - waiting for incoming file...");
    }
  }

  Future<void> _startTransfer() async {
    try {
      print("🚀 Starting file transfer...");
      print('🔍 DEBUG: _startTransfer called with:');
      print('  - filePath: $filePath');
      print('  - device: $device');
      print('  - device?.name: ${device?.name}');
      print('  - device?.ip: ${device?.ip}');
      print('  - device?.transferPort: ${device?.transferPort}');

      // ========== CRITICAL VALIDATION SECTION ==========
      // Extract filePath safely to avoid null check errors
      final safeFilePath = filePath;
      if (safeFilePath == null || safeFilePath.isEmpty) {
        print('❌ CRITICAL: File path is null or empty');
        throw Exception('File path is missing. Cannot start transfer.');
      }
      print('✅ File path validated: $safeFilePath');

      // Validate file actually exists on disk
      final file = File(safeFilePath);
      if (!await file.exists()) {
        print('❌ CRITICAL: File does not exist at path: $safeFilePath');
        throw Exception('Selected file no longer exists on device.');
      }
      final fileSize = await file.length();
      print('✅ File exists on disk: ${fileSize} bytes');

      // Extract device safely to avoid null check errors
      final safeDevice = device;
      if (safeDevice == null) {
        print('❌ CRITICAL: Device is null in _startTransfer');
        throw Exception(
          'Device information is missing. Cannot start transfer.',
        );
      }
      print('✅ Device validated: ${safeDevice.name}');

      // Extract device IP safely
      final deviceIp = safeDevice.ip;
      if (deviceIp.isEmpty) {
        print('❌ CRITICAL: Device IP is empty');
        throw Exception(
          'Device IP address is missing. Cannot connect to receiver.',
        );
      }
      print('✅ Device IP validated: $deviceIp');

      // Extract device port safely
      final devicePort = safeDevice.transferPort;
      if (devicePort <= 0 || devicePort > 65535) {
        print('❌ CRITICAL: Device transfer port is invalid: $devicePort');
        throw Exception(
          'Device transfer port is invalid. Cannot connect to receiver.',
        );
      }
      print('✅ Device port validated: $devicePort');

      // Use DeviceInfo helper for consistency
      // if (!safeDevice.isValidForTransfer) {
      //   print('❌ CRITICAL: Device failed isValidForTransfer check');
      //   throw Exception('Device connection info is invalid. Please restart pairing.');
      // }

      // ========== ALL VALIDATIONS PASSED ==========
      print("✅ All transfer validations passed");
      print("✅ Sending to: $deviceIp:$devicePort");
      print("✅ File: $safeFilePath (${fileSize} bytes)");
      print(
        "🔍 DEBUG: Calling sendFile with path=$safeFilePath, ip=$deviceIp, port=$devicePort",
      );

      // Start the transfer with validated, non-null variables
      await transfer.sendFile(
        safeFilePath,
        deviceIp,
        devicePort,
        senderTempPath: senderTempPath,
      );

      print("✅ Transfer initiated successfully");
    } catch (e, stackTrace) {
      print("❌ CRITICAL ERROR in _startTransfer: $e");
      print("❌ Stack trace: $stackTrace");
      progress.error.value = e.toString();
    }
  }

  void _showErrorAndExit(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.snackbar(
        'Error',
        message,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Get.back();
        }
      });
    });
  }

  @override
  void dispose() {
    // Do not reset progress here: transfer may still be running. Reset only when
    // a new transfer starts (TransferController.sendFile / receiver callback).
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent back button during active transfer
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Show warning that transfer is in progress
          Get.snackbar(
            'Transfer in Progress',
            'Please wait for the transfer to complete',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
          );
        }
      },
      child: Scaffold(
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
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const SizedBox(height: 16),

                  // Step Progress Bar
                  StepProgressBar(
                    currentStep: 6,
                    totalSteps: kTransferFlowTotalSteps,
                    activeColor: Theme.of(context).colorScheme.primary,
                    inactiveColor: Colors.grey.shade300,
                    height: 6,
                    segmentSpacing: 5,
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                  ),

                  const SizedBox(height: 30),

                  // Main Progress Card
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Obx(() {
                            final hasError = progress.error.value.isNotEmpty;

                            if (hasError) {
                              return _buildErrorState();
                            }

                            return _buildProgressState();
                          }),
                        ),
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

  Widget _buildProgressState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isSender
                ? Icons.cloud_upload_rounded
                : Icons.cloud_download_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),

        const SizedBox(height: 24),

        // Title
        Text(
          isSender ? "Transferring File" : "Receiving File",
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 8),

        // File Name
        if ((fileName ?? '').isNotEmpty)
          Text(
            fileName ?? '',
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

        const SizedBox(height: 8),

        // Device Name (receiver: show sender name; sender: show receiver name)
        if (device != null)
          Text(
            isSender
                ? "To: ${device!.name.trim().isNotEmpty ? device!.name.trim() : 'Unknown'}"
                : "From: ${device!.name.trim().isNotEmpty ? device!.name.trim() : 'Sender'}",
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),

        const SizedBox(height: 32),

        // Progress Bar
        Obx(
          () => CustomUploadProgress(
            progress:
                isSender
                    ? progress.sendProgress.value
                    : progress.receiveProgress.value,
            sentMB:
                isSender ? progress.sentMB.value : progress.receivedMB.value,
            totalMB:
                isSender
                    ? progress.totalMB.value
                    : progress.receiveTotalMB.value,
            speedMBps:
                isSender
                    ? progress.speedMBps.value
                    : progress.receiveSpeedMBps.value,
          ),
        ),

        const SizedBox(height: 16),

        // Status Text
        Obx(() {
          final status = progress.status.value;
          final isComplete =
              isSender ? (status == 'sent') : (status == 'received');

          if (isComplete) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Transfer Complete!",
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          }
          return Text(
            "Please keep this screen open...",
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          );
        }),

        const SizedBox(height: 24),

        // Cancel Button (only while transfer running)
        Obx(() {
          final status = progress.status.value;
          final isComplete =
              isSender ? (status == 'sent') : (status == 'received');

          if (isComplete || progress.error.value.isNotEmpty) {
            return const SizedBox.shrink();
          }

          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _confirmCancel();
              },
              icon: const Icon(Icons.close),
              label: const Text("Cancel Transfer"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.red),
                foregroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  void _confirmCancel() {
    Get.dialog(
      AlertDialog(
        title: const Text("Cancel Transfer?"),
        content: const Text(
          "Are you sure you want to cancel the file transfer?",
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("No")),
          TextButton(
            onPressed: () {
              Get.back();
              transfer.cancelTransfer();
              Get.back(); // exit screen
            },
            child: const Text(
              "Yes, Cancel",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Error Icon
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: Colors.red,
          ),
        ),

        const SizedBox(height: 24),

        // Error Title
        Text(
          "Transfer Failed",
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),

        const SizedBox(height: 16),

        // Error Message
        Obx(
          () => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Text(
              progress.error.value,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Retry Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              AppNavigator.toSendReceive();
            },
            icon: const Icon(Icons.refresh),
            label: const Text("Try Again"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
