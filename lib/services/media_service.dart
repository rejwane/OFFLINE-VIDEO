import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

import '../models/video_item.dart';

class VideoFolder {
  const VideoFolder({required this.id, required this.name});

  final String id;
  final String name;
}

class VideoPageResult {
  const VideoPageResult({required this.items, required this.hasMore});

  final List<VideoItem> items;
  final bool hasMore;
}

/// Owns local gallery access and paged reads. Playback never uses a network URL.
class MediaService {
  static const int pageSize = 80;

  AssetPathEntity? _allVideosPath;
  Map<String, AssetPathEntity> _folderPaths = <String, AssetPathEntity>{};

  Future<PermissionState> requestLibraryAccess() {
    // photo_manager handles full and limited gallery access on Android and iOS.
    return PhotoManager.requestPermissionExtend();
  }

  void reset() {
    _allVideosPath = null;
    _folderPaths = <String, AssetPathEntity>{};
  }

  Future<List<VideoFolder>> loadVideoFolders() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      hasAll: false,
    );
    _folderPaths = <String, AssetPathEntity>{
      for (final path in paths) path.id: path,
    };
    return paths
        .map((path) => VideoFolder(id: path.id, name: path.name))
        .toList(growable: false);
  }

  Future<VideoPageResult> loadVideoPage({
    required int page,
    String? folderId,
  }) async {
    final path = await _getPath(folderId);
    if (path == null) {
      return const VideoPageResult(items: <VideoItem>[], hasMore: false);
    }

    final assets = await path.getAssetListPaged(page: page, size: pageSize);
    final localItems = <VideoItem>[];
    for (final asset in assets) {
      try {
        // Do not trigger an iCloud/cloud download while building an offline feed.
        if (await asset.isLocallyAvailable()) {
          localItems.add(VideoItem(asset: asset));
        }
      } catch (_) {
        // Ignore media that disappeared or became inaccessible during the scan.
      }
    }

    return VideoPageResult(
      items: localItems,
      hasMore: assets.length == pageSize,
    );
  }

  Future<List<VideoItem>> loadAllLocalVideos({String? folderId}) async {
    final items = <VideoItem>[];
    var page = 0;
    while (true) {
      final result = await loadVideoPage(page: page, folderId: folderId);
      for (final item in result.items) {
        String? title = item.asset.title;
        if (title == null || title.trim().isEmpty) {
          try {
            title = await item.asset.titleAsync;
          } catch (_) {
            // The asset still appears in the list under its generic label.
          }
        }
        items.add(VideoItem(asset: item.asset, nameOverride: title));
      }
      if (!result.hasMore) break;
      page += 1;
    }
    return items;
  }

  Future<AssetPathEntity?> _getPath(String? folderId) async {
    if (folderId == null) {
      final cachedPath = _allVideosPath;
      if (cachedPath != null) return cachedPath;

      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: true,
      );
      if (paths.isEmpty) return null;
      _allVideosPath = paths.first;
      return _allVideosPath;
    }

    var path = _folderPaths[folderId];
    if (path == null) {
      await loadVideoFolders();
      path = _folderPaths[folderId];
    }
    return path;
  }

  /// Refuse cloud-only assets so the feed remains genuinely offline.
  static Future<File?> getLocalVideoFile(AssetEntity asset) async {
    final isLocal = await asset.isLocallyAvailable();
    if (!isLocal) return null;
    return asset.file;
  }
}
