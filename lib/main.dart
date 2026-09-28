import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'data/app_prefs.dart';
import 'data/video_repository.dart';
import 'screens/splash_screen.dart';
import 'services/playback_service.dart';
import 'services/thumbnail_service.dart';
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
      // Explicit, even though window_manager already defaults to a
      // resizable window: makes the "the window can be dragged bigger
      // /smaller while not maximized" behavior a deliberate, documented
      // choice rather than an assumption. minimumSize above still
      // applies; no maximumSize is set, so there's no upper bound.
      await windowManager.setResizable(true);
      // Open maximized by default. Maximizing before show() (rather
      // than after) avoids a visible "small window snaps to full
      // screen" flash on launch.
      await windowManager.maximize();
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
        ChangeNotifierProvider<AppPrefs>.value(value: repo.prefs),
        ChangeNotifierProvider<VideoRepository>.value(value: repo),
        ChangeNotifierProvider<PlaybackService>(create: (_) => PlaybackService(repo)),
        ChangeNotifierProvider<ShellNavState>(create: (_) => ShellNavState()),
        // Background preview-frame generator for library thumbnails.
        // `lazy: false` so it starts working as soon as the app opens.
        Provider<ThumbnailService>(
          lazy: false,
          create: (ctx) => ThumbnailService(repo, ctx.read<PlaybackService>())..start(),
          dispose: (_, s) => s.dispose(),
        ),
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
