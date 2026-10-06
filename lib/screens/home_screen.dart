import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../providers/feed_provider.dart';
import '../widgets/video_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FeedProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: _body(context, f),
    );
  }

  Widget _body(BuildContext context, FeedProvider f) {
    if (f.loading) return const Center(child: CircularProgressIndicator());
    if (f.denied) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Gallery permission lagbe'),
            const SizedBox(height: 12),
            ElevatedButton(
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
        child: TextButton(onPressed: f.load, child: const Text('Kono video nai. Refresh')),
      );
    }
    return PageView.builder(
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
}
