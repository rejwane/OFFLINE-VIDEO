import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feed_provider.dart';
import '../theme.dart';

class FolderDrawer extends StatelessWidget {
  const FolderDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FeedProvider>();
    final playing = f.currentFolderId;
    return Drawer(
      backgroundColor: kBg,
      width: MediaQuery.of(context).size.width * 0.82,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Folders',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _Tile(
                    icon: Icons.video_library_rounded,
                    name: 'All videos',
                    count: f.totalCount,
                    selected: f.filter == 'all',
                    playing: false,
                    onTap: () => _pick(context, f, 'all'),
                  ),
                  _Tile(
                    icon: Icons.favorite_rounded,
                    name: 'Favorites',
                    count: f.favCount,
                    selected: f.filter == 'fav',
                    playing: false,
                    iconColor: kAccent,
                    onTap: () => _pick(context, f, 'fav'),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
                    child: Text('GALLERY',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.4,
                            color: Colors.white38)),
                  ),
                  for (final d in f.folders)
                    _Tile(
                      icon: Icons.folder_rounded,
                      name: d.name,
                      count: d.count,
                      selected: f.filter == d.id,
                      playing: d.id == playing,
                      onTap: () => _pick(context, f, d.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pick(BuildContext context, FeedProvider f, String key) {
    f.setFilter(key);
    Navigator.pop(context);
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String name;
  final int count;
  final bool selected;
  final bool playing;
  final Color? iconColor;
  final VoidCallback onTap;
  const _Tile({
    required this.icon,
    required this.name,
    required this.count,
    required this.selected,
    required this.playing,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: playing
            ? const Color(0x33FE2C55)
            : (selected ? Colors.white10 : Colors.transparent),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: playing
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kAccent, width: 1.2),
                  )
                : null,
            child: Row(
              children: [
                Icon(icon,
                    color: playing ? kAccent : (iconColor ?? Colors.white70)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: (selected || playing)
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                      if (playing)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text('Playing now',
                              style: TextStyle(fontSize: 11, color: kAccent)),
                        ),
                    ],
                  ),
                ),
                Text('$count',
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.check_circle, size: 18, color: kAccent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
