import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import 'package:path/path.dart' as p;
import 'package:share_app_latest/components/bg_container.dart';

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
import 'package:share_app_latest/routes/app_routes.dart';
import 'package:share_app_latest/services/analytics_screen_tracker.dart';

class TransferFileScreen extends StatefulWidget {
  const TransferFileScreen({super.key});

  @override
  State<TransferFileScreen> createState() => _TransferFileScreenState();
}

class _TransferFileScreenState extends State<TransferFileScreen> {
  DeviceInfo? device;
  bool isSender = false;

  /// When sending contacts, path to the temp VCF file so progress screen can register it for cleanup.
  String? _senderTempPath;
  bool _isPickingFile = false;
  List<String> _selectedFilePaths = <String>[];
  int _selectedFileBytes = 0;
  String? _selectedCategory;

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

   

    _transferCompleteWorker = ever<String>(progress.status, (status) {
      if (_didAutoNavigate) return;

      final isSuccess = status == 'sent';
      final hasError = progress.error.value.isNotEmpty;

      if (isSuccess && !hasError) {
        // Bluetooth: offer "Send another file" so consecutive transfers work without reconnecting
        final isBluetooth = device?.isBluetooth == true;
        if (isBluetooth) {
          _didAutoNavigate = true; // prevent re-entry until user chooses Done
          print("✅ File successfully sent to receiver!");
          Get.snackbar(
            "Transfer Completed",
            "Your file was sent successfully 🎉",
            backgroundColor: Colors.green.withOpacity(0.8),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            Get.dialog(
              barrierDismissible: false,
              AlertDialog(
                title: const Text('Transfer complete'),
                content: const Text(
                  'Send another file to the same device or go back to home.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Get.back(); // close dialog
                      _didAutoNavigate =
                          false; // allow next transfer to trigger completion again
                      // Return to TransferFileScreen so user can pick another file
                      if (Get.key.currentState?.canPop() ?? false) {
                        Get.back();
                      }
                    },
                    child: const Text('Send another file'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Get.back();
                      if (Get.key.currentState?.canPop() ?? false) {
                        Get.back();
                      }
                      AppNavigator.toHome();
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            );
          });
          return;
        }
        // WiFi/QR flow: go to home after delay
        _didAutoNavigate = true;
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
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) AppNavigator.toHome();
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
                'Choose what type of filess you want to send',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildFileTypeContainer(
                      icon: Icons.contacts,
                      label: 'Contacts',
                      color: Colors.teal,
                      onTap: _openContactsFlow,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFileTypeContainer(
                      icon: Icons.video_library,
                      label: 'Videos',
                      color: Colors.red,
                      onTap:
                          () =>
                              _pickFileWithType(FileType.video, null, 'Videos'),
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
                      onTap:
                          () =>
                              _pickFileWithType(FileType.image, null, 'Images'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFileTypeContainer(
                      icon: Icons.insert_drive_file,
                      label: 'Files',
                      color: Colors.orange,
                      onTap:
                          () => _pickFileWithType(FileType.any, null, 'Files'),
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
    String category,
  ) async {
    // Close only the modal selector dialog (if open). This method is also
    // used directly from the main screen cards, so unconditional back would
    // pop the whole screen and break the transfer flow.
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }

    if (_isPickingFile) return;
    _isPickingFile = true;
    try {
      final selectedPaths = await transfer.selectFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
      );

      if (selectedPaths.isNotEmpty) {
        int totalBytes = 0;
        for (final path in selectedPaths) {
          final selectedFile = File(path);
          final fileExists = await selectedFile.exists();
          if (!fileExists) {
            throw Exception('Selected file no longer exists.');
          }
          totalBytes += await selectedFile.length();
        }
        if (!mounted) return;
        setState(() {
          _selectedFilePaths = selectedPaths;
          _selectedFileBytes = totalBytes;
          _selectedCategory = category;
        });
        _senderTempPath = null;
      }
    } catch (e) {
      print('❌ File picker error: $e');
      Get.snackbar('File Picker Error', e.toString());
    } finally {
      _isPickingFile = false;
    }
  }

  Future<void> _openContactsFlow() async {
    try {
      final permission = await FlutterContacts.requestPermission();
      if (!permission) {
        Get.snackbar(
          'Permission needed',
          'Contacts permission is required to share contacts.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      if (contacts.isEmpty) {
        Get.snackbar(
          'No contacts',
          'There are no contacts on this device.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final path = await Get.to<String?>(
        () => _ContactsSelectionPage(contacts: contacts),
        routeName: AppRoutes.contactsSelection,
        fullscreenDialog: true,
      );
      if (path != null && mounted) {
        _senderTempPath = path;
        final selectedFile = File(path);
        final bytes = await selectedFile.length();
        setState(() {
          _selectedFilePaths = <String>[path];
          _selectedFileBytes = bytes;
          _selectedCategory = 'Contacts';
        });
      }
    } catch (e) {
      print('❌ Contacts flow error: $e');
      Get.snackbar(
        'Contacts',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
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
            senderTempPath: _senderTempPath,
            filePaths:
                _selectedFilePaths.length > 1
                    ? List<String>.from(_selectedFilePaths)
                    : null,
          );
          _senderTempPath = null;
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
    final fileBytes = await File(path).length();
    if (fileBytes > kBleMaxBytes) {
      // Don't allow BLE transfer for large files (too slow).
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'File too large',
        'Bluetooth supports up to 5MB. Use Wi‑Fi / same network for faster transfer.',
        duration: const Duration(seconds: 4),
      );
      return;
    }

    // Validate BLE connection so second transfer works without restart (plan: connection robustness)
    if (!bluetooth.isConnectionValid) {
      Get.snackbar(
        'Connection lost',
        'Please reconnect to the device and try again.',
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Fresh state for this offer so both accept + reject changes are observed
    bluetooth.offerAccepted.value = null;

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

    // IMPORTANT: set listener BEFORE sending offer (prevents missing fast accept after app restart)
    Timer? timeoutTimer;
    _bleOfferAcceptedWorker?.dispose();
    _bleOfferAcceptedWorker = once(bluetooth.offerAccepted, (accepted) {
      // ignore: avoid_print
      print(
        '[BT][TransferFileScreen] offerAccepted changed to $accepted '
        '(ip=${bluetooth.receiverIp}, port=${bluetooth.receiverPort})',
      );
      timeoutTimer?.cancel();
      if (Get.isDialogOpen ?? false) Get.back();
      _bleOfferAcceptedWorker?.dispose();
      _bleOfferAcceptedWorker = null;

      if (accepted != true) return;

      if (bluetooth.useBleTransfer) {
        // BLE-only transfer: no IP/port, file will be sent over Bluetooth
        final receiverDevice = DeviceInfo(
          name: deviceName,
          ip: '',
          transferPort: 0,
          isBluetooth: true,
        );
        progress.reset();
        AppNavigator.toTransferProgress(
          device: receiverDevice,
          filePath: path,
          fileName: fileName,
          senderTempPath: _senderTempPath,
        );
        _senderTempPath = null;
        return;
      }

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
        senderTempPath: _senderTempPath,
      );
      _senderTempPath = null;
    });

    timeoutTimer = Timer(const Duration(seconds: 30), () {
      // ignore: avoid_print
      print(
        '[BT][TransferFileScreen] BLE offer timeout waiting for receiver response',
      );
      if (_bleOfferAcceptedWorker != null) {
        _bleOfferAcceptedWorker?.dispose();
        _bleOfferAcceptedWorker = null;
        if (Get.isDialogOpen ?? false) Get.back();
        Get.snackbar(
          'Timeout',
          'Receiver did not respond. Make sure the receiver app is open on the other device and try again.',
          duration: const Duration(seconds: 4),
        );
      }
    });

    try {
      await bluetooth.sendOffer(path);
    } catch (e) {
      timeoutTimer.cancel();
      _bleOfferAcceptedWorker?.dispose();
      _bleOfferAcceptedWorker = null;
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar('Send failed', e.toString());
    }
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
    if (ext == '.vcf') return 'contacts';
    if (ext == '.apk') return 'apk';
    if (ext == '.mp4' || ext == '.mov') return 'video';
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png') return 'image';
    return 'file';
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final value =
        size >= 100 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
    return '$value ${units[unitIndex]}';
  }

  Future<void> _continueWithSelectedFile() async {
    if (_selectedFilePaths.isEmpty) {
      Get.snackbar(
        'Select file',
        'Please select one or more files before continuing.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    await AnalyticsScreenTracker.trackUiEvent(
      'after_select_file_continue',
      parameters: <String, Object>{
        'selected_category': _selectedCategory ?? 'unknown',
        'selected_file_count': _selectedFilePaths.length,
        'event_location': 'transfer_file_screen',
      },
    );
    await _sendSelectedFile(_selectedFilePaths.first);
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
    final hasSelectedFile = _selectedFilePaths.isNotEmpty;
    return Scaffold(
      body: bg_container(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: Icon(
                        Icons.adaptive.arrow_back,
                        color: Colors.black,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Back",
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: StepProgressBar(
                    currentStep: 5,
                    totalSteps: kTransferFlowTotalSteps,
                    activeColor: const Color(0xFF4A67F6),
                    inactiveColor: Colors.grey.shade300,
                    height: 12,
                    segmentSpacing: 8,
                    padding: const EdgeInsets.only(top: 8, bottom: 13),
                  ),
                ),
                const SizedBox(height: 12),
                if (hasSelectedFile)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A67F6),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_selectedFilePaths.length} file(s) selected',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatFileSize(_selectedFileBytes),
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (hasSelectedFile) const SizedBox(height: 18),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        BuildChooseOption(
                          icon: Icons.video_library,
                          title: 'Videos',
                          isSelected: _selectedCategory == 'Videos',
                          color: Colors.red,
                          onTap:
                              () => _pickFileWithType(
                                FileType.video,
                                null,
                                'Videos',
                              ),
                        ),
                        const SizedBox(height: 12),
                        BuildChooseOption(
                          icon: Icons.photo_library,
                          title: 'Images',
                          isSelected: _selectedCategory == 'Images',
                          color: Colors.blue,
                          onTap:
                              () => _pickFileWithType(
                                FileType.image,
                                null,
                                'Images',
                              ),
                        ),
                        const SizedBox(height: 12),
                        BuildChooseOption(
                          icon: Icons.contacts,
                          title: 'Contacts',
                          isSelected: _selectedCategory == 'Contacts',
                          color: Colors.teal,
                          onTap: _openContactsFlow,
                        ),
                        const SizedBox(height: 12),
                        BuildChooseOption(
                          icon: Icons.insert_drive_file,
                          title: 'Files',
                          isSelected: _selectedCategory == 'Files',
                          color: Colors.orange,
                          onTap:
                              () => _pickFileWithType(
                                FileType.any,
                                null,
                                'Files',
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (hasSelectedFile && !_isPickingFile)
                            ? _continueWithSelectedFile
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A67F6),
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isPickingFile
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(
                              'Continue',
                              style: GoogleFonts.roboto(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen page to select contacts and export to VCF.
class _ContactsSelectionPage extends StatefulWidget {
  const _ContactsSelectionPage({required this.contacts});

  final List<Contact> contacts;

  @override
  State<_ContactsSelectionPage> createState() => _ContactsSelectionPageState();
}

class _ContactsSelectionPageState extends State<_ContactsSelectionPage> {
  final Set<int> _selectedIndices = {};

  Future<void> _exportAndSend() async {
    if (_selectedIndices.isEmpty) {
      Get.snackbar(
        'Select contacts',
        'Select at least one contact to send.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    try {
      final sb = StringBuffer();
      for (final i in _selectedIndices) {
        if (i >= 0 && i < widget.contacts.length) {
          sb.writeln(widget.contacts[i].toVCard());
        }
      }
      final vcfContent = sb.toString();
      if (vcfContent.isEmpty) return;
      final dir = await getTemporaryDirectory();
      final name =
          'contacts_export_${DateTime.now().millisecondsSinceEpoch}.vcf';
      final path = p.join(dir.path, name);
      await File(path).writeAsString(vcfContent);
      if (!mounted) return;
      Get.back(result: path);
    } catch (e) {
      print('❌ Export contacts error: $e');
      Get.snackbar(
        'Export failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedIndices.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select contacts',
          style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Get.back(),
        ),
        actions: [
          TextButton(
            onPressed: selectedCount > 0 ? _exportAndSend : null,
            child: Text(
              'Send $selectedCount',
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w600,
                color:
                    selectedCount > 0
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: widget.contacts.length,
        itemBuilder: (context, index) {
          final c = widget.contacts[index];
          final name = c.displayName.isNotEmpty ? c.displayName : 'Unknown';
          final subtitle = c.phones.isNotEmpty ? c.phones.first.number : '';
          final selected = _selectedIndices.contains(index);
          return CheckboxListTile(
            value: selected,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedIndices.add(index);
                } else {
                  _selectedIndices.remove(index);
                }
              });
            },
            title: Text(name, style: GoogleFonts.roboto()),
            subtitle:
                subtitle.isNotEmpty
                    ? Text(
                      subtitle,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    )
                    : null,
            activeColor: Colors.teal,
          );
        },
      ),
    );
  }
}
