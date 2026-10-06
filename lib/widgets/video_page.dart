import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/feed_provider.dart';

class VideoPage extends StatefulWidget {
  final AssetEntity asset;
  final int index;
  const VideoPage({super.key, required this.asset, required this.index});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> with WidgetsBindingObserver {
  VideoPlayerController? _c;
  Uint8List? _thumb;
  bool _userPaused = false;
  bool _error = false;
  bool? _lastActive;
  bool? _lastMuted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThumb();
    _init();
  }

  Future<void> _loadThumb() async {
    final t = await widget.asset.thumbnailDataWithSize(const ThumbnailSize(360, 640));
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
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FeedProvider>();
    final active = f.current == widget.index;
    if (_lastActive != active || _lastMuted != f.muted) {
      _lastActive = active;
      _lastMuted = f.muted;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync();
      });
    }

    final c = _c;
    final ready = c != null && c.value.isInitialized;

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
        if (ready && !c.value.isPlaying && active)
          const IgnorePointer(
            child: Center(child: Icon(Icons.play_arrow, size: 90, color: Colors.white70)),
          ),
        Positioned(
          right: 12,
          bottom: 60,
          child: IconButton(
            iconSize: 30,
            onPressed: f.toggleMute,
            icon: Icon(f.muted ? Icons.volume_off : Icons.volume_up),
          ),
        ),
        if (ready)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: VideoProgressIndicator(
                  c,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
