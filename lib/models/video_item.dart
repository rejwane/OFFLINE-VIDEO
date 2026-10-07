import 'package:photo_manager/photo_manager.dart';

class VideoItem {
  const VideoItem({
    required this.asset,
    this.nameOverride,
  });

  final AssetEntity asset;
  final String? nameOverride;

  String get id => asset.id;

  String get displayName {
    final title = (nameOverride ?? asset.title)?.trim();
    return title == null || title.isEmpty ? 'Local video' : title;
  }

  Duration get duration => Duration(seconds: asset.duration);

  DateTime get createdAt => asset.createDateTime;
}
