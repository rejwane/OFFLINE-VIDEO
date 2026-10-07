import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../models/creator_profile.dart';
import '../models/video_item.dart';
import '../services/media_service.dart';
import 'action_rail.dart';
import 'progress_bar.dart';

typedef PlaybackProgressCallback = void Function(
  String videoId,
  Duration position, {
  bool? force,
});

class VideoPage extends StatefulWidget {
  const VideoPage({
    super.key,
    required this.item,
    required this.isActive,
    required this.isMuted,
    required this.isFavorite,
    required this.playbackSpeed,
    required this.resumePosition,
    required this.counterLabel,
    required this.isLimitedAccess,
    required this.creator,
    required this.onToggleMute,
    required this.onToggleFavorite,
    required this.onDoubleTapLike,
    required this.onSpeedChanged,
    required this.onPlaybackProgress,
    required this.onOpenProfile,
    required this.onOpenMenu,
    required this.onShare,
  });

  final VideoItem item;
  final bool isActive;
  final bool isMuted;
  final bool isFavorite;
  final double playbackSpeed;
  final Duration resumePosition;
  final String counterLabel;
  final bool isLimitedAccess;
  final CreatorProfile? creator;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDoubleTapLike;
  final ValueChanged<double> onSpeedChanged;
  final PlaybackProgressCallback onPlaybackProgress;
  final Future<void> Function() onOpenProfile;
  final VoidCallback onOpenMenu;
  final VoidCallback onShare;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  File? _cachedFile;
  Uint8List? _thumbnailBytes;
  String? _errorMessage;
  bool _isLoading = true;
  bool _userPaused = false;
  bool _appIsResumed = true;
  bool _resumeAfterLifecycle = false;
  bool _showHeart = false;

  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _heartScale = Tween<double>(begin: 0.35, end: 1.18).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.elasticOut),
    );
    _heartOpacity = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: 1),
        weight: 12,
      ),
      TweenSequenceItem<double>(tween: ConstantTween<double>(1), weight: 58),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 0),
        weight: 30,
      ),
    ]).animate(_heartController);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final asset = widget.item.asset;
      final isLocal = await asset.isLocallyAvailable();
      if (!mounted) return;

      if (!isLocal) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'This video is not stored on this device. Make it available locally to watch offline.';
        });
        return;
      }

      // Never request a thumbnail until the asset has been confirmed local.
      unawaited(_loadThumbnail());
      final file = await MediaService.getLocalVideoFile(asset);
      if (!mounted) {
        await _deleteTemporaryFile(file);
        return;
      }
      if (file == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'This video is not stored on this device. Make it available locally to watch offline.';
        });
        return;
      }

      _cachedFile = file;
      final controller = VideoPlayerController.file(file);
      _controller = controller;
      controller.addListener(_onControllerChanged);

      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(true);
      await controller.setVolume(widget.isMuted ? 0 : 1);
      await controller.setPlaybackSpeed(widget.playbackSpeed);

      final positionMs = widget.resumePosition.inMilliseconds;
      final maxResumeMs = controller.value.duration.inMilliseconds - 1000;
      if (widget.isActive && positionMs > 1000 && positionMs < maxResumeMs) {
        await controller.seekTo(Duration(milliseconds: positionMs));
      }
      if (!mounted) return;

      setState(() => _isLoading = false);
      _syncPlayback();
    } catch (error, stackTrace) {
      debugPrint('Could not open local video: $error\n$stackTrace');
      await _releaseMedia();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'This video could not be opened.';
      });
    }
  }

  Future<void> _loadThumbnail() async {
    try {
      final bytes = await widget.item.asset.thumbnailDataWithSize(
        const ThumbnailSize(720, 1280),
      );
      if (!mounted || bytes == null) return;
      setState(() => _thumbnailBytes = bytes);
    } catch (_) {
      // The video can still play if a thumbnail is unavailable.
    }
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (!mounted || !widget.isActive || controller == null) return;
    if (controller.value.isInitialized) {
      widget.onPlaybackProgress(widget.item.id, controller.value.position);
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isActive != widget.isActive) {
      // A newly selected page should autoplay, regardless of its previous state.
      _userPaused = false;
      _resumeAfterLifecycle = false;
      _syncPlayback();
    }
    if (oldWidget.isMuted != widget.isMuted) unawaited(_applyVolume());
    if (oldWidget.playbackSpeed != widget.playbackSpeed) {
      unawaited(_applyPlaybackSpeed());
    }
  }

  void _syncPlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || !_appIsResumed) {
      return;
    }

    if (!widget.isActive || _userPaused) {
      if (controller.value.isPlaying) unawaited(_pause());
    } else if (!controller.value.isPlaying) {
      unawaited(_play());
    }
  }

  Future<void> _play() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.play();
    } catch (_) {
      // Keep the feed responsive if a codec or file disappears mid-playback.
    }
  }

  Future<void> _pause() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.pause();
    } catch (_) {
      // The controller may already be disposing as its page leaves the cache.
    }
  }

  Future<void> _applyVolume() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setVolume(widget.isMuted ? 0 : 1);
    } catch (_) {
      // Ignore transient platform-player errors.
    }
  }

  Future<void> _applyPlaybackSpeed() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setPlaybackSpeed(widget.playbackSpeed);
    } catch (_) {
      // Ignore transient platform-player errors.
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (!widget.isActive || controller == null || !controller.value.isInitialized) {
      return;
    }

    final shouldPlay = !controller.value.isPlaying;
    setState(() => _userPaused = !shouldPlay);
    if (shouldPlay) {
      await _play();
    } else {
      await _pause();
    }
  }

  Future<void> _openProfile() async {
    final controller = _controller;
    final wasPlaying = controller?.value.isPlaying ?? false;
    if (wasPlaying) await _pause();
    try {
      await widget.onOpenProfile();
    } finally {
      if (mounted && widget.isActive && wasPlaying && !_userPaused) {
        await _play();
      }
    }
  }

  void _handleDoubleTap() {
    widget.onDoubleTapLike();
    setState(() => _showHeart = true);
    unawaited(_runHeartAnimation());
  }

  Future<void> _runHeartAnimation() async {
    try {
      await _heartController.forward(from: 0).orCancel;
    } catch (_) {
      // The animation can be cancelled if the page is disposed mid-flight.
    }
    if (mounted) setState(() => _showHeart = false);
  }

  Future<void> _seekTo(Duration requestedPosition) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final maximum = controller.value.duration.inMilliseconds;
    final milliseconds = requestedPosition.inMilliseconds.clamp(0, maximum).toInt();
    try {
      await controller.seekTo(Duration(milliseconds: milliseconds));
    } catch (_) {
      // A seek can fail if the file was removed while the page was open.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isActive) return;

    final controller = _controller;
    if (state == AppLifecycleState.resumed) {
      _appIsResumed = true;
      if (_resumeAfterLifecycle && !_userPaused) unawaited(_play());
      _resumeAfterLifecycle = false;
    } else {
      if (controller != null && controller.value.isInitialized) {
        widget.onPlaybackProgress(
          widget.item.id,
          controller.value.position,
          force: true,
        );
      }
      _appIsResumed = false;
      _resumeAfterLifecycle = controller?.value.isPlaying ?? false;
      if (_resumeAfterLifecycle) unawaited(_pause());
    }
  }

  Future<void> _releaseMedia() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onControllerChanged);
      try {
        await controller.dispose();
      } catch (_) {
        // Disposal is best-effort during page teardown.
      }
    }

    final file = _cachedFile;
    _cachedFile = null;
    await _deleteTemporaryFile(file);
  }

  Future<void> _deleteTemporaryFile(File? file) async {
    // photo_manager writes an app-container cache copy on iOS.
    if (!Platform.isIOS || file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A cache file may already have been removed by the OS.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    if (widget.isActive && controller != null && controller.value.isInitialized) {
      widget.onPlaybackProgress(
        widget.item.id,
        controller.value.position,
        force: true,
      );
    }
    _heartController.dispose();
    unawaited(_releaseMedia());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final value = controller != null &&
            controller.value.isInitialized &&
            _errorMessage == null
        ? controller.value
        : null;
    final isReady = value != null;
    final ratio = value?.aspectRatio ?? 9 / 16;

    return ColoredBox(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_togglePlayback()),
        onDoubleTap: _handleDoubleTap,
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0).abs() > 220) {
            unawaited(_openProfile());
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_thumbnailBytes != null && !isReady)
              Image.memory(
                _thumbnailBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
              ),
            if (isReady)
              Center(
                child: AspectRatio(
                  aspectRatio: ratio.isFinite && ratio > 0 ? ratio : 9 / 16,
                  child: VideoPlayer(controller!),
                ),
              ),
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x73000000),
                        Color(0x00000000),
                        Color(0x18000000),
                        Color(0xB8000000),
                      ],
                      stops: [0, 0.22, 0.58, 1],
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading && !isReady)
              const Positioned.fill(
                child: Center(
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF9AE7D5),
                    ),
                  ),
                ),
              ),
            if (_errorMessage != null) _buildErrorOverlay(),
            if (isReady) _buildPlaybackOverlay(value!.isPlaying),
            if (_showHeart)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: FadeTransition(
                      opacity: _heartOpacity,
                      child: ScaleTransition(
                        scale: _heartScale,
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFFF476F),
                          size: 112,
                          shadows: [
                            Shadow(color: Colors.black38, blurRadius: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            _buildHeader(),
            if (isReady) _buildFooter(value!),
            if (isReady)
              Positioned(
                right: 10,
                bottom: 136,
                child: ActionRail(
                  creator: widget.creator,
                  isFavorite: widget.isFavorite,
                  isMuted: widget.isMuted,
                  playbackSpeed: widget.playbackSpeed,
                  onOpenProfile: () => unawaited(_openProfile()),
                  onToggleFavorite: widget.onToggleFavorite,
                  onToggleMute: widget.onToggleMute,
                  onSpeedChanged: widget.onSpeedChanged,
                  onShare: widget.onShare,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 9),
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Color(0xFF9AE7D5),
                  size: 24,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MINITOK · LOCAL',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          widget.counterLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        if (widget.isLimitedAccess) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x44FFFFFF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'SELECTED MEDIA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Feed options, folders and search',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onOpenMenu,
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x55000000),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(VideoPlayerValue value) {
    return Positioned(
      left: 16,
      right: 86,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ON THIS DEVICE  ·  OFFLINE PLAYBACK',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              ProgressBar(
                position: value.position,
                duration: value.duration,
                onSeek: (position) => unawaited(_seekTo(position)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackOverlay(bool isPlaying) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedScale(
            scale: isPlaying ? 0.86 : 1,
            duration: const Duration(milliseconds: 180),
            child: AnimatedOpacity(
              opacity: isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              child: Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: Color(0x8A000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Positioned.fill(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 42),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Swipe to continue',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
