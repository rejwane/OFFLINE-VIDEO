import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/video_item.dart';
import '../providers/feed_provider.dart';
import '../widgets/video_grid.dart';
import 'video_collection_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<VideoItem>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _favoritesFuture = context.read<FeedProvider>().favoriteVideos();
  }

  void _reload() {
    setState(() => _favoritesFuture = context.read<FeedProvider>().favoriteVideos());
  }

  void _openVideo(List<VideoItem> videos, int index) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VideoCollectionScreen(
          videos: videos,
          initialIndex: index,
          collectionName: 'Favorites',
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0E),
      appBar: AppBar(title: const Text('Favorites')),
      body: FutureBuilder<List<VideoItem>>(
        future: _favoritesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF9AE7D5)),
            );
          }
          final videos = snapshot.data ?? const <VideoItem>[];
          if (videos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No favorites yet. Tap the heart on a video to save it here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, height: 1.45),
                ),
              ),
            );
          }
          return VideoGrid(videos: videos, onVideoTap: (index) => _openVideo(videos, index));
        },
      ),
    );
  }
}
