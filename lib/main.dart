import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'data/video_repository.dart';
import 'screens/splash_screen.dart';
import 'services/playback_service.dart';
import 'state/shell_nav.dart';
import 'theme/crow_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // libmpv backend — must be initialized before any Player is created.
  MediaKit.ensureInitialized();

  if (!kIsWeb) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1360, 820),
      minimumSize: Size(900, 560),
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden, // we draw our own 3-button bar
      title: 'Crow Théatron',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final repo = await VideoRepository.create();

  runApp(CrowTheatronApp(repo: repo));
}

class CrowTheatronApp extends StatelessWidget {
  const CrowTheatronApp({super.key, required this.repo});

  final VideoRepository repo;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<VideoRepository>.value(value: repo),
        ChangeNotifierProvider<PlaybackService>(create: (_) => PlaybackService(repo)),
        ChangeNotifierProvider<ShellNavState>(create: (_) => ShellNavState()),
      ],
      child: MaterialApp(
        title: 'Crow Théatron',
        debugShowCheckedModeBanner: false,
        theme: CrowTheme.dark,
        darkTheme: CrowTheme.dark,
        themeMode: ThemeMode.dark,
        home: const SplashScreen(),
      ),
    );
  }
}
