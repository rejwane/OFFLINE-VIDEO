import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/creator_profile.dart';

class LocalAppData {
  const LocalAppData({
    required this.profiles,
    required this.favoriteIds,
    required this.hiddenIds,
    required this.shuffle,
    required this.speed,
    required this.folderId,
    required this.resumeVideoId,
    required this.resumePositionMs,
  });

  final List<CreatorProfile> profiles;
  final Set<String> favoriteIds;
  final Set<String> hiddenIds;
  final bool shuffle;
  final double speed;
  final String? folderId;
  final String? resumeVideoId;
  final int resumePositionMs;
}

/// Small local-only persistence for feed state and creator profiles.
class LocalStore {
  static const String _profilesKey = 'creator_profiles_v1';
  static const String _favoritesKey = 'favorite_video_ids_v1';
  static const String _hiddenKey = 'hidden_video_ids_v1';
  static const String _shuffleKey = 'shuffle_enabled_v1';
  static const String _speedKey = 'playback_speed_v1';
  static const String _folderKey = 'selected_folder_id_v1';
  static const String _resumeIdKey = 'resume_video_id_v1';
  static const String _resumePositionKey = 'resume_position_ms_v1';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<LocalAppData> load() async {
    final rawProfiles = await _preferences.getString(_profilesKey);
    final rawFavorites = await _preferences.getString(_favoritesKey);
    final rawHidden = await _preferences.getString(_hiddenKey);

    return LocalAppData(
      profiles: _decodeProfiles(rawProfiles),
      favoriteIds: _decodeStringSet(rawFavorites),
      hiddenIds: _decodeStringSet(rawHidden),
      shuffle: await _preferences.getBool(_shuffleKey) ?? false,
      speed: await _preferences.getDouble(_speedKey) ?? 1,
      folderId: await _preferences.getString(_folderKey),
      resumeVideoId: await _preferences.getString(_resumeIdKey),
      resumePositionMs: await _preferences.getInt(_resumePositionKey) ?? 0,
    );
  }

  Future<void> saveProfiles(List<CreatorProfile> profiles) async {
    await _preferences.setString(
      _profilesKey,
      jsonEncode(profiles.map((profile) => profile.toJson()).toList()),
    );
  }

  Future<void> saveFavorites(Set<String> ids) async {
    await _preferences.setString(_favoritesKey, jsonEncode(ids.toList()));
  }

  Future<void> saveHidden(Set<String> ids) async {
    await _preferences.setString(_hiddenKey, jsonEncode(ids.toList()));
  }

  Future<void> saveShuffle(bool value) => _preferences.setBool(_shuffleKey, value);

  Future<void> saveSpeed(double value) => _preferences.setDouble(_speedKey, value);

  Future<void> saveFolder(String? id) async {
    if (id == null) {
      await _preferences.remove(_folderKey);
    } else {
      await _preferences.setString(_folderKey, id);
    }
  }

  Future<void> saveResume(String? videoId, int positionMs) async {
    if (videoId == null) {
      await _preferences.remove(_resumeIdKey);
      await _preferences.remove(_resumePositionKey);
      return;
    }
    await _preferences.setString(_resumeIdKey, videoId);
    await _preferences.setInt(_resumePositionKey, positionMs);
  }

  Future<String> copyAvatarToAppStorage(XFile pickedFile) async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final sourcePath = pickedFile.path;
    final extension = sourcePath.contains('.')
        ? '.${sourcePath.split('.').last.toLowerCase()}'
        : '.jpg';
    final destination = File(
      '${directory.path}${Platform.pathSeparator}avatar_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await File(sourcePath).copy(destination.path);
    return destination.path;
  }

  Future<void> deleteAvatar(String? avatarPath) async {
    if (avatarPath == null) return;
    try {
      final directory = await getApplicationSupportDirectory();
      final prefix = '${directory.path}${Platform.pathSeparator}';
      if (!avatarPath.startsWith(prefix)) return;
      final file = File(avatarPath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A missing cached avatar should not block a profile update.
    }
  }

  List<CreatorProfile> _decodeProfiles(String? raw) {
    if (raw == null || raw.isEmpty) return const <CreatorProfile>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return const <CreatorProfile>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(CreatorProfile.fromJson)
          .where((profile) => profile.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <CreatorProfile>[];
    }
  }

  Set<String> _decodeStringSet(String? raw) {
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return <String>{};
      return decoded.whereType<String>().toSet();
    } catch (_) {
      return <String>{};
    }
  }
}
