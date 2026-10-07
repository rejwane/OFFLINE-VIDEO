import 'package:flutter/material.dart';

import '../models/video_item.dart';
import 'video_thumbnail.dart';

class VideoGrid extends StatelessWidget {
  const VideoGrid({
    super.key,
    required this.videos,
    required this.onVideoTap,
    this.padding = const EdgeInsets.all(3),
  });

  final List<VideoItem> videos;
  final ValueChanged<int> onVideoTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        childAspectRatio: 0.68,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return GestureDetector(
          onTap: () => onVideoTap(index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoThumbnail(asset: video.asset),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xB8000000)],
                        stops: [0.55, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 5,
                  bottom: 6,
                  child: Text(
                    video.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
