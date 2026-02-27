import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_app_latest/app/controllers/duplicate_controller.dart';
import 'package:share_app_latest/app/models/duplicate_item.dart';
import 'package:share_app_latest/routes/app_routes.dart';
import 'package:share_app_latest/utils/constants.dart';
import 'package:share_app_latest/utils/tab_bar_progress.dart';

class DuplicatePreviewScreen extends StatelessWidget {
  const DuplicatePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(DuplicateController());
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
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Select duplicates to remove',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
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
              const SizedBox(height: 16),
              Obx(() {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${ctrl.duplicateGroups.length} group(s) · ${ctrl.totalDuplicateCount} duplicate(s)',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => ctrl.selectAllDuplicates(),
                        icon: const Icon(Icons.select_all, size: 20),
                        label: const Text('Select all'),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  if (ctrl.duplicateGroups.isEmpty) {
                    return Center(
                      child: Text(
                        'No duplicates to show',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: ctrl.duplicateGroups.length,
                    itemBuilder: (context, groupIndex) {
                      final group = ctrl.duplicateGroups[groupIndex];
                      return _DuplicateGroupCard(
                        group: group,
                        isSelected: (item) => ctrl.isSelected(item.id),
                        onToggle: (item) => ctrl.toggleSelection(item.id),
                      );
                    },
                  );
                }),
              ),
              Obx(() {
                final count = ctrl.selectedIds.length;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          count > 0 && !ctrl.deleting.value
                              ? () => _confirmDelete(context, ctrl)
                              : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          ctrl.deleting.value
                              ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                count > 0
                                    ? 'Delete $count selected'
                                    : 'Select duplicates to delete',
                                style: GoogleFonts.roboto(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DuplicateController ctrl,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete duplicates?'),
            content: const Text(
              'Selected duplicate files will be permanently deleted. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Delete',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ),
            ],
          ),
    );
    if (ok != true || !context.mounted) return;
    final success = await ctrl.confirmDelete();
    if (!context.mounted) return;
    if (success) {
      Get.snackbar(
        'Done',
        'Duplicates deleted successfully.',
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
      Get.delete<DuplicateController>(force: true);
      Get.offAllNamed(AppRoutes.home);
    } else if (ctrl.error.value.isNotEmpty) {
      Get.snackbar(
        'Error',
        ctrl.error.value,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }
}

class _DuplicateGroupCard extends StatelessWidget {
  const _DuplicateGroupCard({
    required this.group,
    required this.isSelected,
    required this.onToggle,
  });

  final List<DuplicateItem> group;
  final bool Function(DuplicateItem) isSelected;
  final void Function(DuplicateItem) onToggle;

  @override
  Widget build(BuildContext context) {
    final duplicates = group.where((e) => !e.isOriginal).toList();
    if (duplicates.isEmpty) return const SizedBox.shrink();
    final first = group.first;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              first.name,
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            ...duplicates.map(
              (item) => _DuplicateRow(
                item: item,
                selected: isSelected(item),
                onTap: () => onToggle(item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// class _DuplicateRow extends StatelessWidget {
//   const _DuplicateRow({
//     required this.item,
//     required this.selected,
//     required this.onTap,
//   });

//   final DuplicateItem item;
//   final bool selected;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return ListTile(
//       dense: true,
//       leading: SizedBox(
//         width: 48,
//         height: 48,
//         child:
//             item.assetId != null
//                 ? _GalleryThumbnail(assetId: item.assetId!)
//                 : _FileThumbnail(path: item.path),
//       ),
//       title: Text(
//         item.name,
//         style: GoogleFonts.roboto(fontSize: 13),
//         maxLines: 1,
//         overflow: TextOverflow.ellipsis,
//       ),
//       subtitle: Text(
//         '${_formatSize(item.size)} · ${item.source.label}',
//         style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey.shade600),
//       ),
//       trailing: Checkbox(value: selected, onChanged: (_) => onTap()),
//       onTap: onTap,
//     );
//   }
class _DuplicateRow extends StatelessWidget {
  const _DuplicateRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DuplicateItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: SizedBox(
        width: 48,
        height: 48,
        child:
            item.assetId != null
                ? _GalleryThumbnail(assetId: item.assetId!)
                : _FileThumbnail(path: item.path),
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Checkbox(value: selected, onChanged: (_) => onTap()),
      subtitle: Text(
        '${_formatSize(item.size)} · ${item.source.label}',
        style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey.shade600),
      ),
      onTap: onTap,
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _GalleryThumbnail extends StatelessWidget {
  const _GalleryThumbnail({required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssetEntity?>(
      future: AssetEntity.fromId(assetId),
      builder: (context, snapshot) {
        final entity = snapshot.data;
        if (entity == null) {
          return Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.image),
          );
        }
        return FutureBuilder<Uint8List?>(
          future: entity.thumbnailData,
          builder: (context, thumbSnapshot) {
            final bytes = thumbSnapshot.data;
            if (bytes == null || bytes.isEmpty) {
              return Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.image),
              );
            }
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: 48,
              height: 48,
            );
          },
        );
      },
    );
  }
}

class _FileThumbnail extends StatelessWidget {
  const _FileThumbnail({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return Container(
        color: Colors.grey.shade300,
        child: const Icon(Icons.insert_drive_file),
      );
    }
    final ext = path!.split('.').last.toLowerCase();
    final isVideo = [
      'mp4',
      'avi',
      'mov',
      'mkv',
      'webm',
      'm4v',
      '3gp',
    ].contains(ext);
    return Container(
      color: Colors.grey.shade300,
      child: Icon(
        isVideo ? Icons.videocam : Icons.image,
        color: Colors.grey.shade600,
      ),
    );
  }
}
