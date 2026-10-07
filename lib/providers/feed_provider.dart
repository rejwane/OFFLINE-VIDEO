import 'dart:async';
import 'dart:math';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';

import '../models/creator_profile.dart';
import '../models/video_item.dart';
import '../services/local_store.dart';
import '../services/media_service.dart';

class FeedProvider extends ChangeNotifier {
  FeedProvider(this._mediaService, this._localStore);

  final MediaService _mediaService;
  final LocalStore _localStore;
  final List<VideoItem> _videos = <VideoItem>[];

  List<VideoItem>? _allLocalVideosCache;
  Future<List<VideoItem>>? _allVideosLoadFuture;
  List<CreatorProfile> _profiles = <CreatorProfile>[];
  List<VideoFolder> _folders = <VideoFolder>[];
  Set<String> _favoriteIds = <String>{};
  Set<String> _hiddenIds = <String>{};

  bool _settingsLoaded = false;
  bool _resumeWasEvaluated = false;
  bool _hasAttemptedLoad = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasAccess = false;
  bool _hasLimitedAccess = false;
  bool _hasMore = false;
  bool _isMuted = true;
  bool _isShuffle = false;
  double _playbackSpeed = 1;
  int _currentIndex = 0;
  int _nextPage = 0;
  int _resumePositionMs = 0;
  String? _selectedFolderId;
  String? _resumeVideoId;
  String? _errorMessage;
  String? _paginationErrorMessage;
  DateTime? _lastResumeWriteAt;

  List<VideoItem> get videos => List<VideoItem>.unmodifiable(_videos);
  List<CreatorProfile> get profiles => List<CreatorProfile>.unmodifiable(_profiles);
  List<VideoFolder> get folders => List<VideoFolder>.unmodifiable(_folders);
  Set<String> get hiddenIds => Set<String>.unmodifiable(_hiddenIds);
  bool get hasAttemptedLoad => _hasAttemptedLoad;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasAccess => _hasAccess;
  bool get hasLimitedAccess => _hasLimitedAccess;
  bool get hasMore => _hasMore;
  bool get isMuted => _isMuted;
  bool get isShuffle => _isShuffle;
  double get playbackSpeed => _playbackSpeed;
  int get currentIndex => _currentIndex;
  int get resumePositionMs => _resumePositionMs;
  String? get resumeVideoId => _resumeVideoId;
  String? get selectedFolderId => _selectedFolderId;
  String? get errorMessage => _errorMessage;
  String? get paginationErrorMessage => _paginationErrorMessage;
  int get favoriteCount => _favoriteIds.length;
  int get hiddenCount => _hiddenIds.length;

  bool isFavorite(String videoId) => _favoriteIds.contains(videoId);

  CreatorProfile? profileForVideo(String videoId) {
    for (final profile in _profiles) {
      if (profile.videoIds.contains(videoId)) return profile;
    }
    return null;
  }

  CreatorProfile? profileById(String profileId) {
    for (final profile in _profiles) {
      if (profile.id == profileId) return profile;
    }
    return null;
  }

  VideoItem? videoById(String videoId) {
    for (final item in _videos) {
      if (item.id == videoId) return item;
    }
    for (final item in _allLocalVideosCache ?? const <VideoItem>[]) {
      if (item.id == videoId) return item;
    }
    return null;
  }

  Future<void> loadVideos({bool requestPermission = true}) async {
    if (_isLoading) return;

    _isLoading = true;
    _hasAttemptedLoad = true;
    _isLoadingMore = false;
    _hasMore = false;
    _currentIndex = 0;
    _nextPage = 0;
    _errorMessage = null;
    _paginationErrorMessage = null;
    _videos.clear();
    notifyListeners();

    try {
      if (!_settingsLoaded) {
        final saved = await _localStore.load();
        _profiles = saved.profiles;
        _favoriteIds = saved.favoriteIds;
        _hiddenIds = saved.hiddenIds;
        _isShuffle = saved.shuffle;
        _playbackSpeed = _validSpeed(saved.speed);
        _selectedFolderId = saved.folderId;
        _resumeVideoId = saved.resumeVideoId;
        _resumePositionMs = saved.resumePositionMs;
        _settingsLoaded = true;
      }

      if (requestPermission) {
        final permission = await _mediaService.requestLibraryAccess();
        _hasAccess = permission.hasAccess;
        _hasLimitedAccess = permission.hasAccess && !permission.isAuth;
      }
      if (!_hasAccess) return;

      final shouldRestoreLastVideo =
          !_resumeWasEvaluated && _selectedFolderId == null;
      _mediaService.reset();
      _folders = await _mediaService.loadVideoFolders();
      if (_selectedFolderId != null &&
          !_folders.any((folder) => folder.id == _selectedFolderId)) {
        _selectedFolderId = null;
        unawaited(_localStore.saveFolder(null));
      }

      // Skip pages containing only cloud-only or locally hidden items.
      _hasMore = true;
      while (_videos.isEmpty && _hasMore) {
        final result = await _mediaService.loadVideoPage(
          page: _nextPage,
          folderId: _selectedFolderId,
        );
        _nextPage += 1;
        _hasMore = result.hasMore;
        final visible = result.items
            .where((item) => !_hiddenIds.contains(item.id))
            .toList();
        if (_isShuffle) visible.shuffle(Random());
        _videos.addAll(visible);
      }

      if (shouldRestoreLastVideo &&
          _resumeVideoId != null &&
          !_hiddenIds.contains(_resumeVideoId)) {
        while (_hasMore && !_videos.any((item) => item.id == _resumeVideoId)) {
          final result = await _mediaService.loadVideoPage(
            page: _nextPage,
            folderId: _selectedFolderId,
          );
          _nextPage += 1;
          _hasMore = result.hasMore;
          final visible = result.items
              .where((item) => !_hiddenIds.contains(item.id))
              .toList();
          if (_isShuffle) visible.shuffle(Random());
          _videos.addAll(visible);
        }
      }

      while (_hasMore && _videos.length < 5) {
        final result = await _mediaService.loadVideoPage(
          page: _nextPage,
          folderId: _selectedFolderId,
        );
        _nextPage += 1;
        _hasMore = result.hasMore;
        final visible = result.items
            .where((item) => !_hiddenIds.contains(item.id))
            .toList();
        if (_isShuffle) visible.shuffle(Random());
        _videos.addAll(visible);
      }

      if (shouldRestoreLastVideo) {
        final resumeIndex = _videos.indexWhere((item) => item.id == _resumeVideoId);
        if (resumeIndex >= 0) {
          _currentIndex = resumeIndex;
        } else {
          _resumeVideoId = _videos.isEmpty ? null : _videos.first.id;
          _resumePositionMs = 0;
        }
      } else {
        _resumeVideoId = _videos.isEmpty ? null : _videos.first.id;
        _resumePositionMs = 0;
      }
      _resumeWasEvaluated = true;
      _allLocalVideosCache = null;
      _allVideosLoadFuture = null;
    } catch (error, stackTrace) {
      debugPrint('Video scan failed: $error\n$stackTrace');
      _errorMessage = 'Could not scan the video library. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCurrentIndex(int index) {
    if (_videos.isEmpty || index < 0 || index >= _videos.length) return;
    if (_currentIndex == index) return;

    _currentIndex = index;
    _resumeVideoId = _videos[index].id;
    _resumePositionMs = 0;
    _lastResumeWriteAt = DateTime.now();
    unawaited(_localStore.saveResume(_resumeVideoId, 0));
    notifyListeners();

    if (_hasMore &&
        !_isLoadingMore &&
        _paginationErrorMessage == null &&
        _currentIndex >= _videos.length - 5) {
      unawaited(loadNextPage());
    }
  }

  void markLastWatched(String videoId, {int positionMs = 0}) {
    _resumeVideoId = videoId;
    _resumePositionMs = positionMs < 0 ? 0 : positionMs;
    _lastResumeWriteAt = DateTime.now();
    unawaited(_localStore.saveResume(videoId, _resumePositionMs));
  }

  void recordPlaybackProgress(
    String videoId,
    Duration position, {
    bool force = false,
  }) {
    _resumeVideoId = videoId;
    _resumePositionMs = position.inMilliseconds < 0 ? 0 : position.inMilliseconds;
    final now = DateTime.now();
    if (!force &&
        _lastResumeWriteAt != null &&
        now.difference(_lastResumeWriteAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastResumeWriteAt = now;
    unawaited(_localStore.saveResume(videoId, _resumePositionMs));
  }

  Future<void> loadNextPage() async {
    if (!_hasAccess || _isLoading || _isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    _paginationErrorMessage = null;
    notifyListeners();

    try {
      var addedItems = 0;
      while (_hasMore && addedItems == 0) {
        final result = await _mediaService.loadVideoPage(
          page: _nextPage,
          folderId: _selectedFolderId,
        );
        _nextPage += 1;
        _hasMore = result.hasMore;
        final nextItems = result.items
            .where((item) => !_hiddenIds.contains(item.id))
            .toList();
        if (_isShuffle) nextItems.shuffle(Random());
        _videos.addAll(nextItems);
        addedItems = nextItems.length;
      }
    } catch (error, stackTrace) {
      debugPrint('Loading the next video page failed: $error\n$stackTrace');
      _paginationErrorMessage = 'Could not load more videos.';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> retryLoadNextPage() async {
    _paginationErrorMessage = null;
    notifyListeners();
    await loadNextPage();
  }

  Future<List<VideoItem>> loadAllLocalVideos() {
    final cached = _allLocalVideosCache;
    if (cached != null) return Future<List<VideoItem>>.value(_visibleLocalItems(cached));
    return _allVideosLoadFuture ??= _loadAllLocalVideos();
  }

  Future<List<VideoItem>> _loadAllLocalVideos() async {
    try {
      if (!_hasAccess) return const <VideoItem>[];
      final items = await _mediaService.loadAllLocalVideos();
      _allLocalVideosCache = items;
      return _visibleLocalItems(items);
    } finally {
      _allVideosLoadFuture = null;
    }
  }

  List<VideoItem> _visibleLocalItems(List<VideoItem> items) {
    return items
        .where((item) => !_hiddenIds.contains(item.id))
        .toList(growable: false);
  }

  Future<List<VideoItem>> profileVideos(String profileId) async {
    final profile = profileById(profileId);
    if (profile == null) return const <VideoItem>[];
    final allItems = await loadAllLocalVideos();
    final ids = profile.videoIds.toSet();
    return allItems
        .where((item) => ids.contains(item.id) && !_hiddenIds.contains(item.id))
        .toList(growable: false);
  }

  Future<List<VideoItem>> favoriteVideos() async {
    final allItems = await loadAllLocalVideos();
    return allItems
        .where((item) => _favoriteIds.contains(item.id) && !_hiddenIds.contains(item.id))
        .toList(growable: false);
  }

  Future<void> selectFolder(String? folderId) async {
    if (_selectedFolderId == folderId) return;
    _selectedFolderId = folderId;
    _resumeWasEvaluated = true;
    unawaited(_localStore.saveFolder(folderId));
    await loadVideos(requestPermission: false);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    final currentId = _videos.isEmpty ? null : _videos[_currentIndex].id;
    if (_isShuffle) {
      _videos.shuffle(Random());
    } else {
      _videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    if (currentId != null) {
      _currentIndex = _videos.indexWhere((item) => item.id == currentId);
      if (_currentIndex < 0) _currentIndex = 0;
    }
    unawaited(_localStore.saveShuffle(_isShuffle));
    notifyListeners();
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = _validSpeed(speed);
    unawaited(_localStore.saveSpeed(_playbackSpeed));
    notifyListeners();
  }

  double _validSpeed(double speed) {
    const allowed = <double>[0.5, 0.75, 1, 1.25, 1.5, 2];
    return allowed.contains(speed) ? speed : 1;
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
  }

  Future<void> toggleFavorite(String videoId) async {
    if (!_favoriteIds.add(videoId)) _favoriteIds.remove(videoId);
    await _localStore.saveFavorites(_favoriteIds);
    notifyListeners();
  }

  Future<void> setFavorite(String videoId, bool value) async {
    if (value) {
      _favoriteIds.add(videoId);
    } else {
      _favoriteIds.remove(videoId);
    }
    await _localStore.saveFavorites(_favoriteIds);
    notifyListeners();
  }

  Future<void> hideVideo(String videoId) async {
    if (!_hiddenIds.add(videoId)) return;
    final oldIndex = _currentIndex;
    final activeId = _videos.isEmpty ? null : _videos[_currentIndex].id;
    _videos.removeWhere((item) => item.id == videoId);
    if (_videos.isEmpty) {
      _currentIndex = 0;
      _resumeVideoId = null;
      _resumePositionMs = 0;
    } else if (activeId != videoId) {
      _currentIndex = _videos.indexWhere((item) => item.id == activeId);
      if (_currentIndex < 0) _currentIndex = min(oldIndex, _videos.length - 1).toInt();
    } else {
      _currentIndex = min(oldIndex, _videos.length - 1).toInt();
      _resumeVideoId = _videos[_currentIndex].id;
      _resumePositionMs = 0;
    }
    await _localStore.saveHidden(_hiddenIds);
    unawaited(_localStore.saveResume(_resumeVideoId, _resumePositionMs));
    notifyListeners();
  }

  Future<void> restoreHiddenVideo(String videoId) async {
    if (!_hiddenIds.remove(videoId)) return;
    await _localStore.saveHidden(_hiddenIds);
    await loadVideos(requestPermission: false);
  }

  Future<void> restoreAllHiddenVideos() async {
    if (_hiddenIds.isEmpty) return;
    _hiddenIds.clear();
    await _localStore.saveHidden(_hiddenIds);
    await loadVideos(requestPermission: false);
  }

  Future<String> copyProfileAvatar(XFile image) =>
      _localStore.copyAvatarToAppStorage(image);

  Future<void> saveProfile(CreatorProfile profile) async {
    final oldProfile = profileById(profile.id);
    final selectedVideoIds = profile.videoIds.toSet();

    // A video has one local creator profile at a time; assigning it again moves it.
    _profiles = _profiles.map((existing) {
      if (existing.id == profile.id) return existing;
      return existing.copyWith(
        videoIds: existing.videoIds
            .where((videoId) => !selectedVideoIds.contains(videoId))
            .toList(growable: false),
      );
    }).toList();

    final existingIndex = _profiles.indexWhere((item) => item.id == profile.id);
    if (existingIndex >= 0) {
      _profiles[existingIndex] = profile;
    } else {
      _profiles.add(profile);
    }

    await _localStore.saveProfiles(_profiles);
    final oldAvatarPath = oldProfile?.avatarPath;
    if (oldAvatarPath != null && oldAvatarPath != profile.avatarPath) {
      await _localStore.deleteAvatar(oldAvatarPath);
    }
    notifyListeners();
  }

  Future<void> assignVideoToProfile(String videoId, String profileId) async {
    final profile = profileById(profileId);
    if (profile == null || profile.videoIds.contains(videoId)) return;
    await saveProfile(
      profile.copyWith(videoIds: <String>[...profile.videoIds, videoId]),
    );
  }

  Future<void> deleteProfile(String profileId) async {
    final profile = profileById(profileId);
    if (profile == null) return;
    _profiles.removeWhere((item) => item.id == profileId);
    await _localStore.saveProfiles(_profiles);
    await _localStore.deleteAvatar(profile.avatarPath);
    notifyListeners();
  }
}
