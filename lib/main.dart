import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/feed_provider.dart';
import 'screens/home_screen.dart';
import 'services/local_store.dart';
import 'services/media_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    ChangeNotifierProvider(
      create: (_) => FeedProvider(MediaService(), LocalStore())..loadVideos(),
      child: const OfflineVideoFeedApp(),
    ),
  );
}

class OfflineVideoFeedApp extends StatelessWidget {
  const OfflineVideoFeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF9AE7D5);

    return MaterialApp(
      title: 'MiniTok',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF080A0E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
