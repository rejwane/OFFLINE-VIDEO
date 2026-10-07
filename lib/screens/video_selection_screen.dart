import 'package:flutter/material.dart';

import '../models/video_item.dart';
import '../widgets/video_thumbnail.dart';

class VideoSelectionScreen extends StatefulWidget {
  const VideoSelectionScreen({
    super.key,
    required this.videos,
    required this.initialSelection,
  });

  final List<VideoItem> videos;
  final Set<String> initialSelection;

  @override
  State<VideoSelectionScreen> createState() => _VideoSelectionScreenState();
}

class _VideoSelectionScreenState extends State<VideoSelectionScreen> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.of(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0E),
      appBar: AppBar(
        title: Text('Choose videos (${_selectedIds.length})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selectedIds),
            child: const Text('Done'),
          ),
        ],
      ),
      body: widget.videos.isEmpty
          ? const Center(
              child: Text(
                'No local videos are available to select.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(3),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
                childAspectRatio: 0.68,
              ),
              itemCount: widget.videos.length,
              itemBuilder: (context, index) {
                final video = widget.videos[index];
                final selected = _selectedIds.contains(video.id);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedIds.remove(video.id);
                      } else {
                        _selectedIds.add(video.id);
                      }
                    });
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoThumbnail(asset: video.asset, selected: selected),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(6, 20, 6, 5),
                          child: Text(
                            video.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
