import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_app_latest/app/models/device_info.dart';
import 'package:share_app_latest/routes/app_navigator.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';

import '../../controllers/transfer_controller.dart';

class ReceivedFilesScreen extends StatefulWidget {
  final DeviceInfo? device;
  const ReceivedFilesScreen({Key? key, this.device}) : super(key: key);

  @override
  State<ReceivedFilesScreen> createState() => _ReceivedFilesScreenState();
}

class _ReceivedFilesScreenState extends State<ReceivedFilesScreen> {
  final transfer = Get.put(TransferController());

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

              /// Back Row
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      AppNavigator.toHome();
                    },
                    icon: Icon(Icons.arrow_back, color: Colors.black, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Received Files",
                    style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),

              /// Progress Barss
              StepProgressBar(
                currentStep: 7,
                totalSteps: kTransferFlowTotalSteps,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveColor: Colors.grey.shade300,
                height: 6,
                segmentSpacing: 5,
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),

              const SizedBox(height: 40),

              /// Main Content Card
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      /// Header
                      const SizedBox(height: 20),

                      /// Files List
                      Expanded(
                        child: Obx(() {
                          final files = transfer.receivedFiles;
                          if (files.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No received files yet",
                                    style: GoogleFonts.roboto(
                                      fontSize: 18,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Files you receive will appear here",
                                    style: GoogleFonts.roboto(
                                      fontSize: 14,
                                      color: Colors.black,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }

                          // return ListView.builder(
                          //   itemCount: files.length,
                          //   itemBuilder: (context, index) {
                          //     final file = files[index];
                          //     final fileName = file['name'] as String;
                          //     final filePath = file['path'] as String;
                          //     final fileSize = file['size'] as int;
                          //     final fileType = file['type'] as String;
                          //     final timestamp = file['timestamp'] as DateTime;

                          //     return Card(
                          //       margin: const EdgeInsets.only(bottom: 12),
                          //       child: ListTile(
                          //         leading: _getFileIcon(fileType),
                          //         title: Text(
                          //           fileName,
                          //           style: const TextStyle(
                          //             fontWeight: FontWeight.w500,
                          //           ),
                          //         ),
                          //         subtitle: Column(
                          //           crossAxisAlignment:
                          //               CrossAxisAlignment.start,
                          //           children: [
                          //             Text(
                          //               _formatFileSize(fileSize),
                          //               style: TextStyle(
                          //                 color: Colors.grey.shade600,
                          //               ),
                          //             ),
                          //             Text(
                          //               _formatTimestamp(timestamp),
                          //               style: TextStyle(
                          //                 color: Colors.grey.shade500,
                          //                 fontSize: 12,
                          //               ),
                          //             ),
                          //           ],
                          //         ),
                          //         trailing: PopupMenuButton<String>(
                          //           onSelected: (value) {
                          //             if (value == 'save') {
                          //               _saveFile(filePath, fileName);
                          //             } else if (value == 'delete') {
                          //               _deleteFile(index, filePath);
                          //             }
                          //           },
                          //           itemBuilder:
                          //               (context) => [
                          //                 const PopupMenuItem(
                          //                   value: 'save',
                          //                   child: Row(
                          //                     children: [
                          //                       Icon(Icons.save),
                          //                       SizedBox(width: 8),
                          //                       Text('Save to Downloads'),
                          //                     ],
                          //                   ),
                          //                 ),
                          //                 const PopupMenuItem(
                          //                   value: 'delete',
                          //                   child: Row(
                          //                     children: [
                          //                       Icon(
                          //                         Icons.delete,
                          //                         color: Colors.red,
                          //                       ),
                          //                       SizedBox(width: 8),
                          //                       Text('Delete'),
                          //                     ],
                          //                   ),
                          //                 ),
                          //               ],
                          //         ),
                          //         onTap: () {
                          //           // Could open file preview in future
                          //           Get.snackbar(
                          //             'File Ready',
                          //             'File is available at: ${p.basename(filePath)}',
                          //             duration: const Duration(seconds: 2),
                          //           );
                          //         },
                          //       ),
                          //     );
                          //   },
                          // );

                          return GridView.builder(
                            itemCount: files.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 1,
                                ),
                            itemBuilder: (context, index) {
                              final file = files[index];
                              final fileName = file['name'] as String;
                              final filePath = file['path'] as String;
                              final fileType = file['type'] as String;

                              return GestureDetector(
                                onTap: () async {
                                  if (fileType == 'image') {
                                    showDialog(
                                      context: context,
                                      builder:
                                          (_) => Dialog(
                                            child: InteractiveViewer(
                                              child: Image.file(File(filePath)),
                                            ),
                                          ),
                                    );
                                  } else {
                                    try {
                                      await OpenFilex.open(filePath);
                                    } catch (e) {
                                      Get.snackbar("Error", "Cannot open file");
                                    }
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child:
                                      fileType == 'image'
                                          ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Image.file(
                                              File(filePath),
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                          : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                fileType == 'video'
                                                    ? Icons.video_file
                                                    : fileType == 'document'
                                                    ? Icons.description
                                                    : fileType == 'apk'
                                                    ? Icons.android
                                                    : Icons.insert_drive_file,
                                                size: 36,
                                                color: Colors.blueGrey,
                                              ),
                                              const SizedBox(height: 6),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                    ),
                                                child: Text(
                                                  fileName,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget getFileIcon(String fileType) {
    IconData icon;
    Color color;

    switch (fileType) {
      case 'image':
        icon = Icons.image;
        color = Colors.blue;
        break;
      case 'video':
        icon = Icons.video_library;
        color = Colors.red;
        break;
      case 'document':
        icon = Icons.description;
        color = Colors.orange;
        break;
      case 'apk':
        icon = Icons.android;
        color = Colors.green;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  void saveFile(String filePath, String fileName) async {
    try {
      await transfer.saveToDownloads(filePath, fileName);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save file: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  void deleteFile(int index, String filePath) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete File'),
        content: const Text('Are you sure you want to delete this file?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              try {
                final file = File(filePath);
                if (await file.exists()) {
                  await file.delete();
                  transfer.receivedFiles.removeAt(index);
                  Get.snackbar(
                    'Deleted',
                    'File deleted successfully',
                    backgroundColor: Colors.green.withOpacity(0.8),
                    colorText: Colors.white,
                  );
                }
              } catch (e) {
                Get.snackbar(
                  'Error',
                  'Failed to delete file: $e',
                  backgroundColor: Colors.red.withOpacity(0.8),
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
