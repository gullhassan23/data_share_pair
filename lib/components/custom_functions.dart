import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';


import 'package:share_app_latest/utils/constants.dart';


import 'package:share_app_latest/app/controllers/bluetooth_controller.dart';

/// GLOBAL VARIABLE
SendMode? selectedMode;

/// SHOW SEND OPTIONS
void showSendOptions(BuildContext context) {
  Get.bottomSheet(
    Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            "Send files using",
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 24),

//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: [
//               SendOptionItem(
//                 icon: Icons.bluetooth,
//                 label: "Bluetooth",
//                 onTap: () {
//                   selectedMode = SendMode.bluetooth;
//                   Get.back();
//                   Get.to(() => const BluetoothSenderScreen());
//                 },
//               ),
//               SendOptionItem(
//                 icon: Icons.qr_code_scanner,
//                 label: "Scanner",
//                 onTap: () {
//                   selectedMode = SendMode.scanner;
//                   Get.back();
//                   showFileSelectionDialog(context);
//                 },
//               ),
//             ],
//           ),

//           const SizedBox(height: 20),
//         ],
//       ),
//     ),
//   );
// }

// /// SHOW RECEIVE OPTIONS
// void showReceiveOptions(BuildContext context) {
//   Get.bottomSheet(
//     Container(
//       padding: const EdgeInsets.all(20),
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 40,
//             height: 5,
//             decoration: BoxDecoration(
//               color: Colors.grey.shade300,
//               borderRadius: BorderRadius.circular(10),
//             ),
//           ),
//           const SizedBox(height: 20),

//           Text(
//             "Receive files using",
//             style: GoogleFonts.roboto(
//               fontSize: 18,
//               fontWeight: FontWeight.w600,
//             ),
//           ),

//           const SizedBox(height: 24),

//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: [
//               SendOptionItem(
//                 icon: Icons.bluetooth,
//                 label: "Bluetooth",
//                 onTap: () {
//                   selectedMode = SendMode.bluetooth;
//                   Get.back();
//                   Get.to(() => const BluetoothReceiverScreen());
//                 },
//               ),
//               SendOptionItem(
//                 icon: Icons.qr_code_scanner,
//                 label: "QR Code",
//                 onTap: () {
//                   selectedMode = SendMode.scanner;
//                   Get.back();
//                   AppNavigator.toQrReceiver();
//                 },
//               ),
//             ],
//           ),

          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

/// FILE SELECTION DIALOG
void showFileSelectionDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Files to Send',
              style: GoogleFonts.roboto(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: buildFileTypeButton(
                    context: context,
                    icon: Icons.file_present,
                    label: 'Files',
                    onTap: () => selectFiles(context, FileType.any),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildFileTypeButton(
                    context: context,
                    icon: Icons.image,
                    label: 'Images',
                    onTap: () => selectFiles(context, FileType.image),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: buildFileTypeButton(
                    context: context,
                    icon: Icons.video_file,
                    label: 'Videos',
                    onTap: () => selectFiles(context, FileType.video),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildFileTypeButton(
                    context: context,
                    icon: Icons.android,
                    label: 'APK',
                    onTap:
                        () => selectFiles(context, FileType.custom, ['.apk']),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      );
    },
  );
}

/// BUTTON BUILDER
Widget buildFileTypeButton({
  required BuildContext context,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return ElevatedButton(
    onPressed: () {
      Navigator.pop(context);
      onTap();
    },
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Column(
      children: [Icon(icon, size: 32), const SizedBox(height: 8), Text(label)],
    ),
  );
}

/// SELECT FILES FUNCTION
Future<void> selectFiles(
  BuildContext context,
  FileType type, [
  List<String>? extensions,
]) async {
  try {
    FilePickerResult? result;

    if (type == FileType.custom && extensions != null) {
      result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: extensions,
        allowMultiple: true,
      );
    } else {
      result = await FilePicker.platform.pickFiles(
        type: type,
        allowMultiple: true,
      );
    }

    if (result != null && result.files.isNotEmpty) {
      final paths = result.files.map((f) => f.path!).toList();

      if (selectedMode == SendMode.scanner) {
        // AppNavigator.toQrSender(paths);
      } else if (selectedMode == SendMode.bluetooth) {
        final bluetooth = Get.find<BluetoothController>(tag: "sender");
        await bluetooth.sendOffer(paths[0]);
      }
    }
  } catch (e) {
    Get.snackbar(
      'Error',
      'Failed to select files: $e',
      backgroundColor: Colors.red.withOpacity(0.8),
      colorText: Colors.white,
    );
  }
}
