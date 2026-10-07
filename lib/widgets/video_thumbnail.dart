import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class VideoThumbnail extends StatefulWidget {
  const VideoThumbnail({
    super.key,
    required this.asset,
    this.selected = false,
    this.showPlayIcon = true,
  });

  final AssetEntity asset;
  final bool selected;
  final bool showPlayIcon;

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  late Future<Uint8List?> _thumbnail;

  @override
  void initState() {
    super.initState();
    _thumbnail = _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _thumbnail = _loadThumbnail();
    }
  }

  Future<Uint8List?> _loadThumbnail() {
    return widget.asset.thumbnailDataWithSize(const ThumbnailSize(480, 720));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder<Uint8List?>(
          future: _thumbnail,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) {
              return const ColoredBox(
                color: Color(0xFF171A20),
                child: Center(
                  child: Icon(Icons.movie_outlined, color: Colors.white38, size: 28),
                ),
              );
            }
            return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
          },
        ),
        if (widget.showPlayIcon)
          const Positioned(
            right: 6,
            bottom: 6,
            child: Icon(
              Icons.play_arrow_rounded,
              size: 17,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
            ),
          ),
        if (widget.selected) ...[
          const Positioned.fill(
            child: ColoredBox(color: Color(0x449AE7D5)),
          ),
          const Positioned(
            top: 6,
            right: 6,
            child: CircleAvatar(
              radius: 11,
              backgroundColor: Color(0xFF9AE7D5),
              child: Icon(Icons.check_rounded, color: Color(0xFF08211B), size: 15),
            ),
          ),
        ],
      ],
    );
  }
}
