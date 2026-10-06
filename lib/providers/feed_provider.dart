import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

class FeedProvider extends ChangeNotifier {
  List<AssetEntity> videos = [];
  bool loading = true;
  bool denied = false;
  bool muted = false;
  int current = 0;

  Future<void> load() async {
    loading = true;
    denied = false;
    notifyListeners();
    final p = await PhotoManager.requestPermissionExtend();
    if (!p.hasAccess) {
      denied = true;
      loading = false;
      notifyListeners();
      return;
    }
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: true,
    );
    if (albums.isNotEmpty) {
      final count = await albums.first.assetCountAsync;
      videos = await albums.first.getAssetListRange(start: 0, end: count);
    }
    loading = false;
    notifyListeners();
  }

  void setCurrent(int i) {
    current = i;
    notifyListeners();
  }

  void toggleMute() {
    muted = !muted;
    notifyListeners();
  }
}
