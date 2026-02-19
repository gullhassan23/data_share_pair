import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:path/path.dart' as p;

import 'package:share_app_latest/components/build_choose_option.dart';

import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';

import '../../../controllers/bluetooth_controller.dart';
import '../../../controllers/progress_controller.dart';
import '../../../controllers/transfer_controller.dart';
import '../../../controllers/pairing_controller.dart';
import '../../../controllers/QR_controller.dart';
import '../../../models/device_info.dart';
import '../../../models/file_meta.dart';
import 'package:share_app_latest/routes/app_navigator.dart';

class TransferFileScreen extends StatefulWidget {
  const TransferFileScreen({super.key});

  @override
  State<TransferFileScreen> createState() => _TransferFileScreenState();
}

class _TransferFileScreenState extends State<TransferFileScreen> {
  DeviceInfo? device;
  bool isSender = false;

  final transfer = Get.put(TransferController());
  final pairing = Get.put(PairingController());
  final progress = Get.put(ProgressController());
  Worker? _transferCompleteWorker;
  Worker? _bleOfferAcceptedWorker;
  bool _didAutoNavigate = false;

  void _handleInvalidArgs() {
    print(
      "❌ Error: Invalid or missing DeviceInfo arguments in TransferFileScreen",
    );
    Future.microtask(() {
      Get.back();
      Get.snackbar('Error', 'Invalid device information');
    });
  }

  @override
  void initState() {
    super.initState();

    final dynamic args = Get.arguments;
    if (args == null) {
      _handleInvalidArgs();
      return;
    }

    if (args is DeviceInfo) {
      device = args;
      final d = device;
      print(
        "📤 TransferFileScreen initialized with device: ${d?.name ?? 'Unknown'} at ${d?.ip ?? '?'}",
      );
    } else if (args is Map && args['device'] is DeviceInfo) {
      device = args['device'] as DeviceInfo;
      isSender = args['isSender'] == true;
      final d = device;
      print(
        "📤 TransferFileScreen initialized with device: ${d?.name ?? 'Unknown'} at ${d?.ip ?? '?'} (isSender: $isSender)",
      );
    } else {
      _handleInvalidArgs();
      return;
    }

    // Auto-close this screen as soon as the upload completes successfully.
    // This does NOT change transfer logic; it only reacts to existing progress signals.
    // _transferCompleteWorker = ever<double>(progress.sendProgress, (value) {
    //   if (_didAutoNavigate) return;

    //   final isDone = value >= 1.0;
    //   final isSuccess = progress.status.value == 'sent';
    //   final hasError = progress.error.value.isNotEmpty;

    //   if (isDone && isSuccess && !hasError) {
    //     _didAutoNavigate = true;
    //     // Navigate to the "next" screen by popping this transfer screen if possible.
    //     // Fallback to home if it can't pop.
    //     WidgetsBinding.instance.addPostFrameCallback((_) {
    //       if (!mounted) return;
    //       if (Get.key.currentState?.canPop() ?? false) {
    //         Get.back();
    //       } else {
    //         AppNavigator.toHome();
    //       }
    //     });
    //   }
    // });

    _transferCompleteWorker = ever<String>(progress.status, (status) {
      if (_didAutoNavigate) return;

      final isSuccess = status == 'sent';
      final hasError = progress.error.value.isNotEmpty;

      if (isSuccess && !hasError) {
        _didAutoNavigate = true;

        // 🎉 Print + UI feedback
        print("✅ File successfully sent to receiver!");
        Get.snackbar(
          "Transfer Completed",
          "Your file transfer successfully 🎉",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );

        if (Get.isRegistered<QrController>()) {
          Get.find<QrController>().flowState.value =
              TransferFlowState.completed;
        }
        // Navigate to Onboarding after successful transfer (sender flow complete)
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            AppNavigator.toHome();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _transferCompleteWorker?.dispose();
    _bleOfferAcceptedWorker?.dispose();
    super.dispose();
  }

  void showFileTypeSelection() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select File Type',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose what type of files you want to send',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildFileTypeContainer(
                      icon: Icons.android,
                      label: 'APK',
                      color: Colors.green,
                      onTap: () => _pickFileWithType(FileType.custom, ['apk']),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFileTypeContainer(
                      icon: Icons.video_library,
                      label: 'Videos',
                      color: Colors.red,
                      onTap: () => _pickFileWithType(FileType.video, null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildFileTypeContainer(
                      icon: Icons.photo_library,
                      label: 'Photos',
                      color: Colors.blue,
                      onTap: () => _pickFileWithType(FileType.image, null),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFileTypeContainer(
                      icon: Icons.insert_drive_file,
                      label: 'Files',
                      color: Colors.orange,
                      onTap: () => _pickFileWithType(FileType.any, null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  Future<void> _pickFileWithType(
    FileType type,
    List<String>? allowedExtensions,
  ) async {
    Get.back(); // Close the file type selection dialog

    try {
      // Use TransferController to select file
      final selectedPath = await transfer.selectFile(
        type: type,
        allowedExtensions: allowedExtensions,
      );

      if (selectedPath != null) {
        // Now initiate the transfer with the selected file
        await _sendSelectedFile(selectedPath);
      }
    } catch (e) {
      print('❌ File picker error: $e');
      Get.snackbar('File Picker Error', e.toString());
    }
  }

  Future<void> _sendSelectedFile(String path) async {
    try {
      print('🔍 DEBUG: Starting _sendSelectedFile with path: $path');
      print('🔍 DEBUG: device = $device');

      if (device == null) {
        throw Exception(
          'Device information is missing. Please restart the pairing process.',
        );
      }

      final deviceName = device?.name ?? 'Unknown';
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('Selected file no longer exists.');
      }

      final fileName = path.split('/').last;

      // Bluetooth flow: send via BLE, wait for accept
      if (device!.isBluetooth) {
        await _sendBluetoothOffer(path, fileName, deviceName);
        return;
      }

      // WiFi flow
      final deviceIp = device!.ip;
      final devicePort = device!.transferPort;
      if (deviceIp.isEmpty) {
        throw Exception(
          'Device IP address is missing. Please restart the pairing process.',
        );
      }
      if (devicePort <= 0) {
        throw Exception(
          'Device transfer port is invalid. Please restart the pairing process.',
        );
      }

      print('✅ Device validation passed: $deviceName at $deviceIp:$devicePort');

      if (Get.isRegistered<QrController>()) {
        Get.find<QrController>().flowState.value =
            TransferFlowState.fileSelected;
      }

      final meta = FileMeta(
        name: fileName,
        size: await file.length(),
        type: _extType(path),
      );

      final pairingCtrl = Get.find<PairingController>();

      Get.dialog(
        PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Waiting for receiver to accept...',
                    style: GoogleFonts.roboto(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Device: $deviceName',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      print('📤 Sending offer to device: $deviceName');
      print(
        '[QR] TransferFileScreen sendOffer ip=${device!.ip} wsPort=${device!.wsPort}',
      );

      if (Get.isRegistered<QrController>()) {
        Get.find<QrController>().flowState.value = TransferFlowState.offerSent;
      }

      final accepted = await pairingCtrl.sendOffer(device!, meta);

      print('[QR] TransferFileScreen sendOffer result accepted=$accepted');
      if (Get.isDialogOpen ?? false) Get.back();

      if (accepted) {
        print('✅ Offer accepted! Navigating to progress screen...');

        // Validate device still exists after async operation
        final finalDevice = device;
        if (finalDevice == null) {
          throw Exception(
            'Device information lost during transfer negotiation.',
          );
        }

        // Additional validation of device properties before navigation
        if (finalDevice.ip.isEmpty || finalDevice.transferPort <= 0) {
          throw Exception(
            'Device connection info is invalid after negotiation.',
          );
        }

        print('🔍 DEBUG: About to navigate to TransferProgressScreen with:');
        print(
          '  - device: ${finalDevice.name} at ${finalDevice.ip}:${finalDevice.transferPort}',
        );
        print('  - filePath: $path');
        print('  - fileName: $fileName');

        // Reset progress before starting new transfer
        progress.reset();

        if (Get.isRegistered<QrController>()) {
          Get.find<QrController>().flowState.value =
              TransferFlowState.transferring;
        }

        // Navigate to TransferProgressScreen - must be registered in app_pages
        try {
          await AppNavigator.toTransferProgress(
            device: finalDevice,
            filePath: path,
            fileName: fileName,
          );
          print('✅ Navigation to TransferProgressScreen completed');
        } catch (navError, navStack) {
          print(
            '❌ CRITICAL: Navigation to TransferProgressScreen failed: $navError',
          );
          print('❌ Stack: $navStack');
          throw Exception('Failed to open transfer screen: $navError');
        }
      } else {
        print('❌ Offer was rejected or timed out');
        Get.snackbar(
          'Transfer Failed',
          'The receiving device did not accept the transfer or timed out',
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      print('❌ Error sending file: $e');
      // Close loading dialog if open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      Get.snackbar(
        'Transfer Failed',
        e.toString(),
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _sendBluetoothOffer(
    String path,
    String fileName,
    String deviceName,
  ) async {
    final bluetooth = Get.find<BluetoothController>(tag: 'sender');

    Get.dialog(
      PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Waiting for receiver to accept...',
                  style: GoogleFonts.roboto(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Device: $deviceName',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    await bluetooth.sendOffer(path);

    Timer? timeoutTimer;
    _bleOfferAcceptedWorker?.dispose();
    _bleOfferAcceptedWorker = once(bluetooth.offerAccepted, (accepted) {
      timeoutTimer?.cancel();
      if (Get.isDialogOpen ?? false) Get.back();
      _bleOfferAcceptedWorker?.dispose();
      _bleOfferAcceptedWorker = null;

      if (accepted != true) return;

      final ip = bluetooth.receiverIp;
      final port = bluetooth.receiverPort;
      if (ip == null || ip.isEmpty || port == null) {
        Get.snackbar(
          'Error',
          'Receiver did not send address. Connect to same Wi-Fi.',
        );
        return;
      }

      final receiverDevice = DeviceInfo(
        name: 'Receiver',
        ip: ip,
        transferPort: port,
      );
      progress.reset();
      AppNavigator.toTransferProgress(
        device: receiverDevice,
        filePath: path,
        fileName: fileName,
      );
    });

    timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (_bleOfferAcceptedWorker != null) {
        _bleOfferAcceptedWorker?.dispose();
        _bleOfferAcceptedWorker = null;
        if (Get.isDialogOpen ?? false) Get.back();
        Get.snackbar(
          'Timeout',
          'Receiver did not respond in time.',
          duration: const Duration(seconds: 3),
        );
      }
    });
  }

  Widget _buildFileTypeContainer({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extType(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.apk') return 'apk';
    if (ext == '.mp4' || ext == '.mov') return 'video';
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png') return 'image';
    return 'file';
  }

  Future<void> pickAndSendFile() async {
    try {
      final d = device;
      if (d == null) {
        Get.snackbar(
          'Error',
          'Device information is missing. Please restart pairing.',
        );
        return;
      }

      await transfer.initiateFileTransfer(d);
    } catch (e) {
      print('❌ File transfer failed: $e');
      Get.snackbar(
        'Transfer Failed',
        e.toString(),
        duration: const Duration(seconds: 3),
      );
    }
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StepProgressBar(
                    currentStep: 5, // ✅ step increased
                    totalSteps: kTransferFlowTotalSteps,
                    activeColor: Theme.of(context).colorScheme.primary,
                    inactiveColor: Colors.grey.shade300,
                    height: 6,
                    segmentSpacing: 5,
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                  ),
                  const SizedBox(height: 20),

                  /// Top Info Card

                  /// Main Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        /// Select File Button
                        // SizedBox(
                        //   width: double.infinity,
                        //   child: ElevatedButton(
                        //     onPressed: _showFileTypeSelection,
                        //     child: const Text('Select File'),
                        //   ),
                        // ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(24),
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

                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Select File Type',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Choose what type of files you want to send',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: BuildChooseOption(
                                      icon: Icons.android,
                                      title: 'APK',
                                      subtitle: "",
                                      color: Colors.green,
                                      onTap:
                                          () => _pickFileWithType(
                                            FileType.custom,
                                            ['apk'],
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: BuildChooseOption(
                                      icon: Icons.video_library,
                                      title: 'Videos',
                                      subtitle: "",
                                      color: Colors.red,
                                      onTap:
                                          () => _pickFileWithType(
                                            FileType.video,
                                            null,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: BuildChooseOption(
                                      icon: Icons.photo_library,
                                      title: 'Photos',
                                      subtitle: "",
                                      color: Colors.blue,
                                      onTap:
                                          () => _pickFileWithType(
                                            FileType.image,
                                            null,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: BuildChooseOption(
                                      icon: Icons.insert_drive_file,
                                      title: 'Files',
                                      subtitle: "",
                                      color: Colors.orange,
                                      onTap:
                                          () => _pickFileWithType(
                                            FileType.any,
                                            null,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
