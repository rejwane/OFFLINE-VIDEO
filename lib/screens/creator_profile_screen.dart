import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/creator_profile.dart';
import '../models/video_item.dart';
import '../providers/feed_provider.dart';
import '../widgets/video_grid.dart';
import 'profile_editor_screen.dart';
import 'video_collection_screen.dart';

class CreatorProfileScreen extends StatefulWidget {
  const CreatorProfileScreen({super.key, required this.profileId});

  final String profileId;

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  late Future<List<VideoItem>> _videosFuture;

  @override
  void initState() {
    super.initState();
    _videosFuture = context.read<FeedProvider>().profileVideos(widget.profileId);
  }

  Future<void> _editProfile(CreatorProfile profile) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileEditorScreen(profile: profile),
      ),
    );
    if (!mounted) return;
    setState(() {
      _videosFuture = context.read<FeedProvider>().profileVideos(widget.profileId);
    });
  }

  void _openVideos(List<VideoItem> videos, int index, String name) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VideoCollectionScreen(
          videos: videos,
          initialIndex: index,
          collectionName: name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, feed, _) {
        final profile = feed.profileById(widget.profileId);
        if (profile == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF080A0E),
            appBar: AppBar(title: const Text('Profile')),
            body: const Center(child: Text('This profile no longer exists.')),
          );
        }

        final path = profile.avatarPath;
        final hasAvatar = path != null && File(path).existsSync();
        return Scaffold(
          backgroundColor: const Color(0xFF080A0E),
          appBar: AppBar(
            title: Text(profile.name),
            actions: [
              IconButton(
                tooltip: 'Edit profile',
                onPressed: () => _editProfile(profile),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: const Color(0xFF252A31),
                          backgroundImage: hasAvatar ? FileImage(File(path!)) : null,
                          child: hasAvatar
                              ? null
                              : const Icon(Icons.person_rounded, size: 40, color: Colors.white70),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${profile.videoIds.length} videos',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Local profile',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (profile.bio.isNotEmpty) ...[
                      const SizedBox(height: 15),
                      Text(
                        profile.bio,
                        style: const TextStyle(color: Colors.white, height: 1.45),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFF2A2F36)),
                    const SizedBox(height: 11),
                    const Row(
                      children: [
                        Icon(Icons.grid_on_rounded, size: 17, color: Color(0xFF9AE7D5)),
                        SizedBox(width: 7),
                        Text(
                          'VIDEOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<VideoItem>>(
                  future: _videosFuture,
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
                            'No videos assigned yet. Edit this profile and choose local videos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white60, height: 1.45),
                          ),
                        ),
                      );
                    }
                    return VideoGrid(
                      videos: videos,
                      onVideoTap: (index) => _openVideos(videos, index, profile.name),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
