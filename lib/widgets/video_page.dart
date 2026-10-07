import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../providers/feed_provider.dart';
import '../theme.dart';

class VideoPage extends StatefulWidget {
  final AssetEntity asset;
  final int index;
  const VideoPage({super.key, required this.asset, required this.index});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  VideoPlayerController? _c;
  File? _file;
  Uint8List? _thumb;
  bool _userPaused = false;
  bool _error = false;
  bool? _lastActive;
  bool? _lastMuted;
  double? _lastSpeed;
  bool _pop = false;
  Offset _heartPos = Offset.zero;
  late final AnimationController _heart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThumb();
    _init();
  }

  Future<void> _loadThumb() async {
    final t = await widget.asset
        .thumbnailDataWithSize(const ThumbnailSize(360, 640));
    if (mounted) setState(() => _thumb = t);
  }

  Future<void> _init() async {
    try {
      final file = await widget.asset.originFile;
      if (file == null) {
        if (mounted) setState(() => _error = true);
        return;
      }
      final c = VideoPlayerController.file(file);
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      await c.setLooping(true);
      _file = file;
      _c = c;
      c.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() {});
      _sync();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  bool get _active => context.read<FeedProvider>().current == widget.index;

  void _sync() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    final f = context.read<FeedProvider>();
    c.setVolume(f.muted ? 0 : 1);
    c.setPlaybackSpeed(f.speed);
    if (_active && !_userPaused) {
      c.play();
    } else {
      c.pause();
      if (!_active) {
        c.seekTo(Duration.zero);
        _userPaused = false;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) {
      _c?.pause();
    } else {
      _sync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heart.dispose();
    _c?.dispose();
    super.dispose();
  }

  String _fmtSpeed(double s) =>
      '${s.toString().replaceAll(RegExp(r'\.0$'), '')}x';

  String _fmtDur(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  Future<void> _share() async {
    final file = _file ?? await widget.asset.originFile;
    if (file == null) return;
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _delete() async {
    final f = context.read<FeedProvider>();
    final msg = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete video?'),
        content: const Text('Phone theke permanent delete hobe.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: kAccent))),
        ],
      ),
    );
    if (ok != true) return;
    final done = await f.deleteAsset(widget.asset);
    msg.showSnackBar(SnackBar(
        content: Text(done ? 'Deleted' : 'Delete hoy nai'),
        duration: const Duration(seconds: 1)));
  }

  void _likePop() {
    setState(() => _pop = true);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _pop = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FeedProvider>();
    final active = f.current == widget.index;
    if (_lastActive != active ||
        _lastMuted != f.muted ||
        _lastSpeed != f.speed) {
      _lastActive = active;
      _lastMuted = f.muted;
      _lastSpeed = f.speed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync();
      });
    }

    final c = _c;
    final ready = c != null && c.value.isInitialized;
    final fav = f.isFav(widget.asset.id);
    final pb = MediaQuery.of(context).padding.bottom;
    final folder = f.folderNameOf(widget.asset.id);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_thumb != null) Image.memory(_thumb!, fit: BoxFit.cover),
        if (_error) const Center(child: Text('Video load hoy nai')),
        if (ready)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _userPaused = c.value.isPlaying);
              _sync();
            },
            onDoubleTapDown: (d) => _heartPos = d.localPosition,
            onDoubleTap: () {
              f.like(widget.asset.id);
              _heart.forward(from: 0);
            },
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              ),
            ),
          )
        else if (!_error)
          const Center(child: CircularProgressIndicator()),

        // bottom gradient
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 280,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),

        if (ready && !c.value.isPlaying && active)
          const IgnorePointer(
            child: Center(
              child: Icon(Icons.play_arrow_rounded,
                  size: 96, color: Colors.white54),
            ),
          ),

        // heart burst
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _heart,
              builder: (_, __) {
                if (_heart.isDismissed) return const SizedBox.shrink();
                final t = _heart.value;
                final scale = t < 0.3 ? 0.4 + (t / 0.3) * 1.0 : 1.4 - (t - 0.3) * 0.4;
                return Stack(children: [
                  Positioned(
                    left: _heartPos.dx - 55,
                    top: _heartPos.dy - 55 - 60 * t,
                    child: Opacity(
                      opacity: (1 - t * t).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: scale,
                        child: const Icon(Icons.favorite,
                            size: 110, color: kAccent),
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ),

        // right actions
        Positioned(
          right: 8,
          bottom: 56 + pb,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Action(
                onTap: () {
                  f.toggleFav(widget.asset.id);
                  _likePop();
                },
                label: fav ? 'Liked' : 'Like',
                child: AnimatedScale(
                  scale: _pop ? 1.35 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    fav ? Icons.favorite : Icons.favorite_border,
                    size: 34,
                    color: fav ? kAccent : Colors.white,
                  ),
                ),
              ),
              _Action(
                onTap: _share,
                label: 'Share',
                child: const Icon(Icons.share_rounded, size: 30),
              ),
              _Action(
                onTap: f.cycleSpeed,
                label: 'Speed',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_fmtSpeed(f.speed),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
              _Action(
                onTap: f.toggleMute,
                label: f.muted ? 'Muted' : 'Sound',
                child: Icon(
                  f.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  size: 30,
                ),
              ),
              PopupMenuButton<String>(
                color: const Color(0xFF222222),
                icon: const Icon(Icons.more_horiz_rounded, size: 30),
                onSelected: (v) {
                  if (v == 'delete') _delete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, color: kAccent),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),

        // bottom info
        Positioned(
          left: 14,
          right: 84,
          bottom: 26 + pb,
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (folder.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x55000000),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.folder_rounded,
                          size: 14, color: kAccent),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(folder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ]),
                  ),
                const SizedBox(height: 8),
                Text(
                  widget.asset.title ?? 'Video',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fmtDur(widget.asset.videoDuration),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),

        if (ready)
          Positioned(
            left: 0,
            right: 0,
            bottom: pb,
            child: VideoProgressIndicator(
              c,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 10),
              colors: const VideoProgressColors(
                playedColor: kAccent,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final Widget child;
  final String label;
  final VoidCallback onTap;
  const _Action(
      {required this.child, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DefaultTextStyle.merge(
              style: const TextStyle(
                shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
              ),
              child: IconTheme.merge(
                data: const IconThemeData(
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                ),
                child: child,
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                  fontSize: 11,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                )),
          ],
        ),
      ),
    );
  }
}
