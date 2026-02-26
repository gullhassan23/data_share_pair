/// Represents a single file/asset that may be a duplicate.
/// [id] uniquely identifies the item (asset id for gallery, path for app files).
/// [assetId] is set for gallery items (used for PhotoManager.editor.deleteWithIds).
/// [path] is set for app_docs and app_cache (used for File delete).
class DuplicateItem {
  final String id;
  final String? assetId;
  final String? path;
  final String name;
  final int size;
  final String type; // 'image' | 'video'
  final DuplicateSource source;
  final bool isOriginal;

  const DuplicateItem({
    required this.id,
    this.assetId,
    this.path,
    required this.name,
    required this.size,
    required this.type,
    required this.source,
    this.isOriginal = false,
  });
}

enum DuplicateSource {
  gallery,
  app_docs,
  app_cache,
}

extension DuplicateSourceX on DuplicateSource {
  String get label {
    switch (this) {
      case DuplicateSource.gallery:
        return 'Gallery';
      case DuplicateSource.app_docs:
        return 'App files';
      case DuplicateSource.app_cache:
        return 'Cache';
    }
  }
}
