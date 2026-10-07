import 'dart:ui' show Rect;

import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';

import '../models/video_item.dart';
import 'media_service.dart';

class ShareService {
  static Future<bool> shareVideo(
    VideoItem item, {
    Rect? sharePositionOrigin,
  }) async {
    final file = await MediaService.getLocalVideoFile(item.asset);
    if (file == null) return false;

    await SharePlus.instance.share(
      ShareParams(
        title: item.displayName,
        files: <XFile>[XFile(file.path)],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    return true;
  }
}
