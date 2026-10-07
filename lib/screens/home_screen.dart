import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feed_provider.dart';
import '../theme.dart';
import '../widgets/folder_drawer.dart';
import '../widgets/video_page.dart';
import 'package:photo_manager/photo_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _key = GlobalKey<ScaffoldState>();
  final _sc = TextEditingController();
  PageController? _pc;
  int _ver = -1;
  bool _searching = false;

  PageController _controllerFor(FeedProvider f) {
    if (_pc == null || _ver != f.listVersion) {
      final old = _pc;
      _pc = PageController(initialPage: f.current);
      _ver = f.listVersion;
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    }
    return _pc!;
  }

  @override
  void dispose() {
    _pc?.dispose();
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FeedProvider>();
    return Scaffold(
      key: _key,
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      drawer: const FolderDrawer(),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) _key.currentState?.openDrawer();
        },
        child: Stack(
          children: [
            Positioned.fill(child: _content(f)),
            if (!f.loading && !f.denied) _topBar(f),
          ],
        ),
      ),
    );
  }

  Widget _content(FeedProvider f) {
    if (f.loading) return const Center(child: CircularProgressIndicator());
    if (f.denied) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 12),
            const Text('Gallery permission lagbe'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => PhotoManager.openSetting(),
              child: const Text('Open settings'),
            ),
            TextButton(onPressed: f.load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (f.videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.video_library_outlined, size: 56, color: Colors.white38),
            const SizedBox(height: 12),
            const Text('Kono video paoa jay nai', style: TextStyle(color: Colors.white54)),
            TextButton(onPressed: f.load, child: const Text('Refresh')),
          ],
        ),
      );
    }
    return PageView.builder(
      key: ValueKey(f.listVersion),
      controller: _controllerFor(f),
      scrollDirection: Axis.vertical,
      itemCount: f.videos.length,
      onPageChanged: f.setCurrent,
      itemBuilder: (_, i) => VideoPage(
        key: ValueKey(f.videos[i].id),
        asset: f.videos[i],
        index: i,
      ),
    );
  }

  Widget _topBar(FeedProvider f) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xB0000000), Color(0x00000000)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.folder_open_rounded),
                  onPressed: () => _key.currentState?.openDrawer(),
                ),
                Expanded(
                  child: _searching
                      ? TextField(
                          controller: _sc,
                          autofocus: true,
                          onChanged: f.setQuery,
                          decoration: const InputDecoration(
                            hintText: 'Video search...',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.filterName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${f.videos.length} videos',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white60),
                            ),
                          ],
                        ),
                ),
                IconButton(
                  icon: Icon(Icons.shuffle_rounded,
                      color: f.shuffle ? kAccent : Colors.white),
                  onPressed: f.toggleShuffle,
                ),
                IconButton(
                  icon: Icon(_searching ? Icons.close : Icons.search_rounded),
                  onPressed: () {
                    setState(() => _searching = !_searching);
                    if (!_searching) {
                      _sc.clear();
                      f.setQuery('');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
