import 'dart:async';
import 'dart:io';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../models/creator_profile.dart';
import '../models/video_item.dart';
import '../providers/feed_provider.dart';
import '../screens/creator_profile_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/profile_editor_screen.dart';
import '../screens/profiles_screen.dart';
import '../screens/search_screen.dart';
import '../services/share_service.dart';
import '../widgets/video_page.dart';
import 'permission_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  PageController? _pageController;
  bool _wentToBackground = false;

  PageController _controllerFor(int initialPage) {
    return _pageController ??= PageController(initialPage: initialPage);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _wentToBackground = true;
      return;
    }

    if (!_wentToBackground) return;
    _wentToBackground = false;

    final feed = context.read<FeedProvider>();
    if (feed.hasAttemptedLoad && !feed.hasAccess && !feed.isLoading) {
      unawaited(feed.loadVideos());
    }
  }

  Future<void> _openSettings() async {
    await PhotoManager.openSetting();
  }

  Future<void> _manageLimitedSelection() async {
    try {
      await PhotoManager.presentLimited(type: RequestType.video);
    } catch (_) {
      // Available only for limited-access states on supported OS versions.
    }
    if (mounted) await context.read<FeedProvider>().loadVideos();
  }

  void _jumpToFirstPage() {
    if (_pageController?.hasClients ?? false) {
      _pageController!.jumpToPage(0);
    }
  }

  Future<void> _rescan(FeedProvider feed) async {
    _jumpToFirstPage();
    await feed.loadVideos();
  }

  Future<void> _selectFolder(FeedProvider feed, String? folderId) async {
    _jumpToFirstPage();
    await feed.selectFolder(folderId);
  }

  Future<void> _toggleShuffle(FeedProvider feed) async {
    feed.toggleShuffle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController?.hasClients ?? false) {
        _pageController!.jumpToPage(feed.currentIndex);
      }
    });
  }

  Future<void> _hideVideo(FeedProvider feed, VideoItem item) async {
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

    await feed.hideVideo(item.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if ((_pageController?.hasClients ?? false) && feed.videos.isNotEmpty) {
        _pageController!.jumpToPage(feed.currentIndex);
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Hidden from this app. The original file is unchanged.'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            _jumpToFirstPage();
            unawaited(feed.restoreHiddenVideo(item.id));
          },
        ),
      ),
    );
  }

  Future<void> _restoreAllHidden(FeedProvider feed) async {
    await feed.restoreAllHiddenVideos();
    _jumpToFirstPage();
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

  Future<void> _openCreator(FeedProvider feed, VideoItem item) async {
    final existing = feed.profileForVideo(item.id);
    if (existing != null) {
      await _pushCreator(existing.id);
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
                leading: _ProfileAvatar(profile: profile, radius: 20),
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

  Future<void> _openMenu(FeedProvider feed, VideoItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF171A20),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('For You settings'),
                subtitle: Text('Local-only feed controls'),
              ),
              ListTile(
                leading: const Icon(Icons.search_rounded),
                title: const Text('Search video names'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_alt_outlined),
                title: const Text('Local profiles'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const ProfilesScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite_border_rounded),
                title: const Text('Favorites'),
                trailing: Text('${feed.favoriteCount}'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()),
                  );
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.shuffle_rounded),
                title: const Text('Shuffle feed'),
                value: feed.isShuffle,
                onChanged: (_) {
                  Navigator.pop(sheetContext);
                  unawaited(_toggleShuffle(feed));
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.folder_outlined, color: Colors.white70),
                    const SizedBox(width: 14),
                    const Expanded(child: Text('Video folder')),
                    DropdownButton<String?>(
                      value: feed.selectedFolderId,
                      underline: const SizedBox.shrink(),
                      dropdownColor: const Color(0xFF22262D),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All videos'),
                        ),
                        ...feed.folders.map(
                          (folder) => DropdownMenuItem<String?>(
                            value: folder.id,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Text(folder.name, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (folderId) {
                        Navigator.pop(sheetContext);
                        unawaited(_selectFolder(feed, folderId));
                      },
                    ),
                  ],
                ),
              ),
              if (feed.hiddenCount > 0)
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: Text('Restore hidden videos (${feed.hiddenCount})'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_restoreAllHidden(feed));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Hide this video from the app'),
                subtitle: const Text('Original gallery file will not be deleted'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_hideVideo(feed, item));
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Rescan local library'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_rescan(feed));
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, feed, _) {
        final videos = feed.videos;

        if (!feed.hasAttemptedLoad || (feed.isLoading && videos.isEmpty)) {
          return const _LoadingScreen();
        }
        if (feed.errorMessage != null && videos.isEmpty) {
          return _ScanErrorScreen(onRetry: () => unawaited(feed.loadVideos()));
        }
        if (!feed.hasAccess) {
          return PermissionScreen(
            isLoading: feed.isLoading,
            onRequestAccess: () => unawaited(feed.loadVideos()),
            onOpenSettings: () => unawaited(_openSettings()),
          );
        }
        if (videos.isEmpty) {
          return _EmptyVideosScreen(
            isLimitedAccess: feed.hasLimitedAccess,
            hiddenCount: feed.hiddenCount,
            onRescan: () => unawaited(feed.loadVideos()),
            onManageSelection: feed.hasLimitedAccess
                ? () => unawaited(_manageLimitedSelection())
                : null,
            onRestoreHidden: feed.hiddenCount > 0
                ? () => unawaited(_restoreAllHidden(feed))
                : null,
          );
        }

        final pageController = _controllerFor(feed.currentIndex);
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              PageView.builder(
                controller: pageController,
                scrollDirection: Axis.vertical,
                itemCount: videos.length,
                onPageChanged: feed.setCurrentIndex,
                itemBuilder: (context, index) {
                  final item = videos[index];
                  final creator = feed.profileForVideo(item.id);
                  return VideoPage(
                    key: ValueKey<String>(item.id),
                    item: item,
                    isActive: index == feed.currentIndex,
                    isMuted: feed.isMuted,
                    isFavorite: feed.isFavorite(item.id),
                    playbackSpeed: feed.playbackSpeed,
                    resumePosition: feed.resumeVideoId == item.id
                        ? Duration(milliseconds: feed.resumePositionMs)
                        : Duration.zero,
                    isLimitedAccess: feed.hasLimitedAccess,
                    creator: creator,
                    counterLabel:
                        '${index + 1} / ${videos.length}${feed.hasMore ? '+' : ''}',
                    onToggleMute: feed.toggleMute,
                    onToggleFavorite: () => unawaited(feed.toggleFavorite(item.id)),
                    onDoubleTapLike: () => unawaited(feed.setFavorite(item.id, true)),
                    onSpeedChanged: feed.setPlaybackSpeed,
                    onPlaybackProgress: (id, position, {bool? force}) =>
                        feed.recordPlaybackProgress(id, position, force: force ?? false),
                    onOpenProfile: () => _openCreator(feed, item),
                    onOpenMenu: () => unawaited(_openMenu(feed, item)),
                    onShare: () => unawaited(_shareVideo(item)),
                  );
                },
              ),
              if (feed.isLoadingMore)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 82,
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF9AE7D5),
                      ),
                    ),
                  ),
                ),
              if (feed.paginationErrorMessage != null)
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 76,
                  child: Material(
                    color: const Color(0xE61A1D22),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 7, 7, 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              feed.paginationErrorMessage!,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          TextButton(
                            onPressed: () => unawaited(feed.retryLoadNextPage()),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile, required this.radius});

  final CreatorProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = profile.avatarPath;
    final hasAvatar = path != null && File(path).existsSync();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF252A31),
      backgroundImage: hasAvatar ? FileImage(File(path!)) : null,
      child: hasAvatar ? null : const Icon(Icons.person_rounded, color: Colors.white70),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF080A0E),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF9AE7D5),
              ),
            ),
            SizedBox(height: 18),
            Text(
              'Scanning videos on this device…',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanErrorScreen extends StatelessWidget {
  const _ScanErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 44, color: Colors.white70),
              const SizedBox(height: 16),
              const Text(
                'Could not scan the video library.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check gallery access, then try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyVideosScreen extends StatelessWidget {
  const _EmptyVideosScreen({
    required this.isLimitedAccess,
    required this.hiddenCount,
    required this.onRescan,
    required this.onManageSelection,
    required this.onRestoreHidden,
  });

  final bool isLimitedAccess;
  final int hiddenCount;
  final VoidCallback onRescan;
  final VoidCallback? onManageSelection;
  final VoidCallback? onRestoreHidden;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: const BoxDecoration(
                    color: Color(0x0FFFFFFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.video_library_outlined,
                    color: Colors.white70,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'No videos found',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 9),
                Text(
                  hiddenCount > 0
                      ? '$hiddenCount video(s) are hidden in this app. Restore them, or add a video to the device gallery.'
                      : isLimitedAccess
                          ? 'Your gallery access is limited. Select videos, or add a video to the device, then scan again.'
                          : 'Add a video to your device gallery and it will appear here. Cloud-only videos are not streamed.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 22),
                if (onManageSelection != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onManageSelection,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Choose accessible videos'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (onRestoreHidden != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onRestoreHidden,
                      icon: const Icon(Icons.visibility_outlined),
                      label: Text('Restore $hiddenCount hidden video(s)'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: onRescan,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Scan again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
