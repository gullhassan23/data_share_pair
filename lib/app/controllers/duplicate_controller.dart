import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:share_app_latest/app/models/duplicate_item.dart';
import 'package:share_app_latest/app/controllers/transfer_controller.dart';
import 'package:share_app_latest/utils/media_permissions.dart';

class DuplicateController extends GetxController {
  final scanning = false.obs;
  final scanStatus = ''.obs;
  final duplicateGroups = <List<DuplicateItem>>[].obs;
  final selectedIds = <String>{}.obs;
  final error = ''.obs;
  final deleting = false.obs;

  static const _imageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
  ];
  static const _videoExtensions = [
    '.mp4',
    '.avi',
    '.mov',
    '.mkv',
    '.webm',
    '.m4v',
    '.3gp',
  ];

  bool get hasDuplicates => duplicateGroups.isNotEmpty;
  bool get isEmpty => duplicateGroups.isEmpty;
  int get totalDuplicateCount => duplicateGroups.fold<int>(
    0,
    (s, g) => s + g.where((e) => !e.isOriginal).length,
  );

  Future<bool> requestPermissions() async {
    error.value = '';
    try {
      final granted = await requestMediaPermissions();
      if (!granted) {
        error.value = 'Gallery access denied';
        return false;
      }
      return true;
    } catch (e) {
      error.value = 'Permission error: $e';
      return false;
    }
  }

  Future<void> scanDuplicates() async {
    if (scanning.value) return;
    scanning.value = true;
    error.value = '';
    duplicateGroups.clear();
    selectedIds.clear();
    try {
      final allItems = <DuplicateItem>[];

      scanStatus.value = 'Scanning gallery…';
      final galleryItems = await _loadGalleryMedia();
      allItems.addAll(galleryItems);

      scanStatus.value = 'Scanning app files…';
      final appItems = await _loadAppDocumentsMedia();
      allItems.addAll(appItems);

      final cacheItems = await _loadAppCacheMedia();
      allItems.addAll(cacheItems);

      if (allItems.isEmpty) {
        scanning.value = false;
        scanStatus.value = '';
        return;
      }

      scanStatus.value = 'Finding duplicates…';
      final groups = _findDuplicateGroups(allItems);
      duplicateGroups.assignAll(groups);
    } catch (e) {
      error.value = 'Scan failed: $e';
    } finally {
      scanning.value = false;
      scanStatus.value = '';
    }
  }

  static List<List<DuplicateItem>> _findDuplicateGroups(
    List<DuplicateItem> items,
  ) {
    final keyToItems = <String, List<DuplicateItem>>{};
    for (final item in items) {
      final key = '${item.name}_${item.size}';
      keyToItems.putIfAbsent(key, () => []).add(item);
    }
    final groups = <List<DuplicateItem>>[];
    for (final list in keyToItems.values) {
      if (list.length < 2) continue;
      list.sort((a, b) {
        return 0;
      });
      final withOriginal = List<DuplicateItem>.from(list);
      withOriginal[0] = DuplicateItem(
        id: withOriginal[0].id,
        assetId: withOriginal[0].assetId,
        path: withOriginal[0].path,
        name: withOriginal[0].name,
        size: withOriginal[0].size,
        type: withOriginal[0].type,
        source: withOriginal[0].source,
        isOriginal: true,
      );
      groups.add(withOriginal);
    }
    return groups;
  }

  Future<List<DuplicateItem>> _loadGalleryMedia() async {
    final list = <DuplicateItem>[];
    try {
      const pageSize = 100;
      int page = 0;
      while (true) {
        final assets = await PhotoManager.getAssetListPaged(
          page: page,
          pageCount: pageSize,
          type: RequestType.common,
        );
        if (assets.isEmpty) break;
        for (final asset in assets) {
          if (asset.type != AssetType.image && asset.type != AssetType.video)
            continue;
          final name = asset.title ?? asset.id;
          int size = 0;
          try {
            final file = await asset.getFile();
            if (file != null && await file.exists()) {
              size = await file.length();
            }
          } catch (_) {}
          final type = asset.type == AssetType.video ? 'video' : 'image';
          list.add(
            DuplicateItem(
              id: asset.id,
              assetId: asset.id,
              path: null,
              name: name,
              size: size,
              type: type,
              source: DuplicateSource.gallery,
              isOriginal: false,
            ),
          );
        }
        if (assets.length < pageSize) break;
        page++;
      }
    } on MissingPluginException catch (e) {
      debugPrint('DuplicateController: photo_manager plugin not linked: $e');
      error.value =
          'Gallery access is not available. Try a full restart of the app.';
    } catch (e) {
      debugPrint('DuplicateController: gallery load error: $e');
    }
    return list;
  }

  Future<List<DuplicateItem>> _loadAppDocumentsMedia() async {
    final list = <DuplicateItem>[];
    try {
      final dir = await getApplicationDocumentsDirectory();
      if (!await dir.exists()) return list;
      final files = dir.listSync().whereType<File>();
      for (final file in files) {
        final fileName = p.basename(file.path);
        final ext = p.extension(fileName).toLowerCase();
        if (!_imageExtensions.contains(ext) && !_videoExtensions.contains(ext))
          continue;
        final stat = await file.stat();
        final type = _videoExtensions.contains(ext) ? 'video' : 'image';
        list.add(
          DuplicateItem(
            id: file.path,
            assetId: null,
            path: file.path,
            name: fileName,
            size: stat.size,
            type: type,
            source: DuplicateSource.app_docs,
            isOriginal: false,
          ),
        );
      }
    } catch (e) {
      debugPrint('DuplicateController: app docs load error: $e');
    }
    return list;
  }

  Future<List<DuplicateItem>> _loadAppCacheMedia() async {
    final list = <DuplicateItem>[];
    try {
      final tmp = await getTemporaryDirectory();
      for (final dirName in ['transfer_out', 'transfer_in']) {
        final dir = Directory('${tmp.path}/$dirName');
        if (!await dir.exists()) continue;
        await for (final entity in dir.list()) {
          if (entity is! File) continue;
          final fileName = p.basename(entity.path);
          final ext = p.extension(fileName).toLowerCase();
          if (!_imageExtensions.contains(ext) &&
              !_videoExtensions.contains(ext))
            continue;
          final stat = await entity.stat();
          final type = _videoExtensions.contains(ext) ? 'video' : 'image';
          list.add(
            DuplicateItem(
              id: entity.path,
              assetId: null,
              path: entity.path,
              name: fileName,
              size: stat.size,
              type: type,
              source: DuplicateSource.app_cache,
              isOriginal: false,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('DuplicateController: app cache load error: $e');
    }
    return list;
  }

  // void toggleSelection(String id) {
  //   if (selectedIds.contains(id)) {
  //     selectedIds.remove(id);
  //   } else {
  //     selectedIds.add(id);
  //   }
  //   selectedIds.refresh();
  // }
  void toggleSelection(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
  }

  void selectAllDuplicates() {
    for (final group in duplicateGroups) {
      for (final item in group) {
        if (!item.isOriginal) selectedIds.add(item.id);
      }
    }
    selectedIds.refresh();
  }

  void clearSelection() {
    selectedIds.clear();
    selectedIds.refresh();
  }

  bool isSelected(String id) => selectedIds.contains(id);

  Future<bool> confirmDelete() async {
    if (selectedIds.isEmpty) return false;
    deleting.value = true;
    error.value = '';
    try {
      final transfer = Get.find<TransferController>();
      final toRemove = selectedIds.toList();
      final galleryIds = <String>[];
      for (final group in duplicateGroups) {
        for (final item in group) {
          if (!toRemove.contains(item.id)) continue;
          if (item.assetId != null) {
            galleryIds.add(item.assetId!);
          } else if (item.path != null) {
            final f = File(item.path!);
            if (await f.exists()) {
              await f.delete();
              if (item.source == DuplicateSource.app_docs) {
                transfer.receivedFiles.removeWhere(
                  (m) => (m['path'] as String?) == item.path,
                );
              }
            }
          }
        }
      }
      if (galleryIds.isNotEmpty) {
        try {
          await PhotoManager.editor.deleteWithIds(galleryIds);
        } on MissingPluginException catch (_) {
          error.value = 'Gallery delete not available. App files were removed.';
        }
      }
      await transfer.refreshReceivedFiles();
      selectedIds.clear();
      selectedIds.refresh();
      duplicateGroups.removeWhere((group) {
        group.removeWhere((item) => toRemove.contains(item.id));
        return group.length <= 1;
      });
      duplicateGroups.refresh();
      return true;
    } catch (e) {
      error.value = 'Delete failed: $e';
      return false;
    } finally {
      deleting.value = false;
    }
  }

  void reset() {
    scanning.value = false;
    scanStatus.value = '';
    duplicateGroups.clear();
    selectedIds.clear();
    error.value = '';
    deleting.value = false;
  }
}
