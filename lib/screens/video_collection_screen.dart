import 'dart:async';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/video_item.dart';
import '../providers/feed_provider.dart';
import '../services/share_service.dart';
import '../widgets/video_page.dart';
import 'creator_profile_screen.dart';
import 'profile_editor_screen.dart';

class VideoCollectionScreen extends StatefulWidget {
  const VideoCollectionScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
    required this.collectionName,
  });

  final List<VideoItem> videos;
  final int initialIndex;
  final String collectionName;

  @override
  State<VideoCollectionScreen> createState() => _VideoCollectionScreenState();
}

class _VideoCollectionScreenState extends State<VideoCollectionScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.videos.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.videos.length - 1).toInt();
    _pageController = PageController(initialPage: _currentIndex);
    if (widget.videos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<FeedProvider>().markLastWatched(
              widget.videos[_currentIndex].id,
            );
      });
    }
  }

  Future<void> _shareVideo(VideoItem item) async {
    final size = MediaQuery.sizeOf(context);
    final origin = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
    try {
      final didShare = await ShareService.shareVideo(
        item,
        sharePositionOrigin: origin,
      );
      if (!mounted || didShare) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This video is not available locally to share.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share this video.')),
      );
    }
  }

  Future<void> _hideVideo(VideoItem item) async {
    final shouldHide = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hide this video?'),
        content: const Text(
          'It will be hidden from this app and its profiles. The original gallery file will stay on your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hide video'),
          ),
        ],
      ),
    );
    if (shouldHide != true || !mounted) return;
    await context.read<FeedProvider>().hideVideo(item.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openCreator(VideoItem item) async {
    final feed = context.read<FeedProvider>();
    final creator = feed.profileForVideo(item.id);
    if (creator != null) {
      await _pushCreator(creator.id);
      return;
    }

    if (feed.profiles.isEmpty) {
      await _createProfileForVideo(item);
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF171A20),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('No profile is assigned to this video'),
              subtitle: Text('Choose one to assign it, or create a new profile.'),
            ),
            ...feed.profiles.map(
              (profile) => ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF282D34),
                  child: Icon(Icons.person_rounded, color: Colors.white70),
                ),
                title: Text(profile.name),
                onTap: () => Navigator.pop(sheetContext, profile.id),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Create a profile for this video'),
              onTap: () => Navigator.pop(sheetContext, '__create__'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == '__create__') {
      await _createProfileForVideo(item);
      return;
    }

    await feed.assignVideoToProfile(item.id, selected);
    if (mounted) await _pushCreator(selected);
  }

  Future<void> _createProfileForVideo(VideoItem item) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileEditorScreen(initialVideoId: item.id),
      ),
    );
    if (!mounted || created != true) return;
    final profile = context.read<FeedProvider>().profileForVideo(item.id);
    if (profile != null) await _pushCreator(profile.id);
  }

  Future<void> _pushCreator(String profileId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CreatorProfileScreen(profileId: profileId),
      ),
    );
  }

  void _openVideoMenu(VideoItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF171A20),
      builder: (sheetContext) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.visibility_off_outlined),
          title: const Text('Hide from this app'),
          subtitle: const Text('The original video stays in your gallery'),
          onTap: () {
            Navigator.pop(sheetContext);
            unawaited(_hideVideo(item));
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF080A0E),
        appBar: AppBar(title: Text(widget.collectionName)),
        body: const Center(child: Text('No videos here.')),
      );
    }

    return Consumer<FeedProvider>(
      builder: (context, feed, _) => Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: widget.videos.length,
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
            feed.markLastWatched(widget.videos[index].id);
          },
          itemBuilder: (context, index) {
            final item = widget.videos[index];
            final creator = feed.profileForVideo(item.id);
            return VideoPage(
              key: ValueKey<String>('collection-${item.id}'),
              item: item,
              isActive: index == _currentIndex,
              isMuted: feed.isMuted,
              isFavorite: feed.isFavorite(item.id),
              playbackSpeed: feed.playbackSpeed,
              resumePosition: feed.resumeVideoId == item.id
                  ? Duration(milliseconds: feed.resumePositionMs)
                  : Duration.zero,
              counterLabel: '${index + 1} / ${widget.videos.length}',
              isLimitedAccess: feed.hasLimitedAccess,
              creator: creator,
              onToggleMute: feed.toggleMute,
              onToggleFavorite: () => unawaited(feed.toggleFavorite(item.id)),
              onDoubleTapLike: () => unawaited(feed.setFavorite(item.id, true)),
              onSpeedChanged: feed.setPlaybackSpeed,
              onPlaybackProgress: (id, position, {bool? force}) =>
                  feed.recordPlaybackProgress(id, position, force: force ?? false),
              onOpenProfile: () => _openCreator(item),
              onOpenMenu: () => _openVideoMenu(item),
              onShare: () => unawaited(_shareVideo(item)),
            );
          },
        ),
      ),
    );
  }
}
