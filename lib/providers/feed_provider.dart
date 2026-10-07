import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FolderInfo {
  final String id;
  final String name;
  final int count;
  FolderInfo(this.id, this.name, this.count);
}

class FeedProvider extends ChangeNotifier {
  static const speeds = [0.5, 1.0, 1.5, 2.0];

  SharedPreferences? _prefs;
  List<AssetEntity> _all = [];
  final Map<String, Set<String>> _albumIds = {};
  final Map<String, String> _albumNames = {};
  final Map<String, String> _folderOf = {}; // asset id -> album id

  List<AssetEntity> videos = [];
  Set<String> favs = {};
  String filter = 'all'; // all | fav | <album id>
  String query = '';
  bool shuffle = false;
  bool muted = false;
  bool loading = true;
  bool denied = false;
  double speed = 1.0;
  int current = 0;
  int listVersion = 0;

  AssetEntity? get currentAsset =>
      (videos.isEmpty || current >= videos.length) ? null : videos[current];

  List<FolderInfo> get folders {
    final l = _albumIds.entries
        .map((e) => FolderInfo(e.key, _albumNames[e.key] ?? '?', e.value.length))
        .where((f) => f.count > 0)
        .toList();
    l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return l;
  }

  int get totalCount => _all.length;
  int get favCount => _all.where((e) => favs.contains(e.id)).length;

  String get filterName {
    if (filter == 'all') return 'All videos';
    if (filter == 'fav') return 'Favorites';
    return _albumNames[filter] ?? 'Folder';
  }

  String? get currentFolderId {
    final a = currentAsset;
    return a == null ? null : _folderOf[a.id];
  }

  String folderNameOf(String assetId) =>
      _albumNames[_folderOf[assetId]] ?? '';

  bool isFav(String id) => favs.contains(id);

  Future<void> load() async {
    loading = true;
    denied = false;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    favs = (_prefs!.getStringList('favs') ?? []).toSet();
    muted = _prefs!.getBool('muted') ?? false;

    final p = await PhotoManager.requestPermissionExtend();
    if (!p.hasAccess) {
      denied = true;
      loading = false;
      notifyListeners();
      return;
    }
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: false,
    );
    _all = [];
    _albumIds.clear();
    _albumNames.clear();
    _folderOf.clear();
    final union = <String, AssetEntity>{};
    List<AssetEntity>? allList;
    for (final a in albums) {
      final n = await a.assetCountAsync;
      if (n == 0) continue;
      final list = await a.getAssetListRange(start: 0, end: n);
      if (a.isAll) {
        allList = list;
      } else {
        _albumIds[a.id] = list.map((e) => e.id).toSet();
        _albumNames[a.id] = a.name;
        for (final e in list) {
          union[e.id] = e;
          _folderOf[e.id] = a.id;
        }
      }
    }
    _all = allList ?? union.values.toList();
    loading = false;
    _apply(keepId: _prefs!.getString('last'));
  }

  List<AssetEntity> _base() {
    Iterable<AssetEntity> l = _all;
    if (filter == 'fav') {
      l = l.where((e) => favs.contains(e.id));
    } else if (filter != 'all') {
      final ids = _albumIds[filter];
      l = l.where((e) => ids?.contains(e.id) ?? false);
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      l = l.where((e) => (e.title ?? '').toLowerCase().contains(q));
    }
    return l.toList();
  }

  void _apply({String? keepId, int? index}) {
    final l = _base();
    if (shuffle) {
      l.shuffle(Random());
      if (keepId != null) {
        final i = l.indexWhere((e) => e.id == keepId);
        if (i > 0) l.insert(0, l.removeAt(i));
      }
    }
    videos = l;
    var cur = 0;
    if (index != null) {
      cur = index.clamp(0, max(0, l.length - 1));
    } else if (keepId != null) {
      final i = l.indexWhere((e) => e.id == keepId);
      cur = i < 0 ? 0 : i;
    }
    current = cur;
    listVersion++;
    notifyListeners();
  }

  void setFilter(String key) {
    filter = key;
    _apply();
  }

  void setQuery(String q) {
    query = q;
    _apply();
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    _apply(keepId: currentAsset?.id);
  }

  void setCurrent(int i) {
    current = i;
    if (i < videos.length) _prefs?.setString('last', videos[i].id);
    notifyListeners();
  }

  void toggleMute() {
    muted = !muted;
    _prefs?.setBool('muted', muted);
    notifyListeners();
  }

  void cycleSpeed() {
    final i = speeds.indexOf(speed);
    speed = speeds[(i + 1) % speeds.length];
    notifyListeners();
  }

  void _saveFavs() => _prefs?.setStringList('favs', favs.toList());

  void toggleFav(String id) {
    favs.contains(id) ? favs.remove(id) : favs.add(id);
    _saveFavs();
    notifyListeners();
  }

  void like(String id) {
    if (favs.add(id)) {
      _saveFavs();
      notifyListeners();
    }
  }

  Future<bool> deleteAsset(AssetEntity a) async {
    final done = await PhotoManager.editor.deleteWithIds([a.id]);
    if (done.isEmpty) return false;
    _all.removeWhere((e) => e.id == a.id);
    for (final s in _albumIds.values) {
      s.remove(a.id);
    }
    _folderOf.remove(a.id);
    favs.remove(a.id);
    _saveFavs();
    _apply(index: current);
    return true;
  }
}
