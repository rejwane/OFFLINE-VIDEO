import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/video_item.dart';
import '../providers/feed_provider.dart';
import '../widgets/video_grid.dart';
import 'video_collection_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  late final Future<List<VideoItem>> _videosFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _videosFuture = context.read<FeedProvider>().loadAllLocalVideos();
  }

  void _openSearchResults(List<VideoItem> videos, int index) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VideoCollectionScreen(
          videos: videos,
          initialIndex: index,
          collectionName: 'Search results',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0E),
      appBar: AppBar(
        titleSpacing: 8,
        title: TextField(
          controller: _queryController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search local video names',
            border: InputBorder.none,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _queryController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
      ),
      body: FutureBuilder<List<VideoItem>>(
        future: _videosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF9AE7D5)),
            );
          }
          final allVideos = snapshot.data ?? const <VideoItem>[];
          final results = _query.isEmpty
              ? allVideos
              : allVideos
                  .where((video) => video.displayName.toLowerCase().contains(_query))
                  .toList(growable: false);
          if (allVideos.isEmpty) {
            return const Center(
              child: Text('No local videos available.', style: TextStyle(color: Colors.white60)),
            );
          }
          if (results.isEmpty) {
            return const Center(
              child: Text('No matching file names.', style: TextStyle(color: Colors.white60)),
            );
          }
          return VideoGrid(
            videos: results,
            onVideoTap: (index) => _openSearchResults(results, index),
          );
        },
      ),
    );
  }
}
