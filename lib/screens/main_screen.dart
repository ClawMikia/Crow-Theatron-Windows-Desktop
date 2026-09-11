import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/crow_database.dart';
import '../data/video_repository.dart';
import '../models/video_entity.dart';
import '../state/shell_nav.dart';
import '../theme/crow_colors.dart';
import '../widgets/section_header.dart';
import '../widgets/video_tiles.dart';
import 'folder_select_screen.dart';
import 'player_screen.dart';

/// Port of `activity_main.xml` + `main/MainActivity.kt`, restructured
/// as a desktop dashboard: quick actions + horizontal shelves for
/// Continue Watching / Favorites, instead of the phone app's stacked
/// list of buttons. Lives inside [AppShell]'s content area.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<VideoEntity> _continueWatching = [];
  List<VideoEntity> _favorites = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = repoOf(context);
    final cw = await repo.listContinueWatching();
    final favs = await repo.listFavorites();
    if (mounted) setState(() { _continueWatching = cw; _favorites = favs; _loaded = true; });
  }

  Future<void> _resetLibrary() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CrowColors.surfaceElevated,
        title: const Text('Reset library?', style: TextStyle(color: CrowColors.onBg)),
        content: const Text(
          'This will delete all videos from the library, including playback history, '
          'chapters and preferences. This cannot be undone.',
          style: TextStyle(color: CrowColors.onMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset', style: TextStyle(color: CrowColors.accentRed))),
        ],
      ),
    );
    if (confirmed != true) return;
    final db = await CrowDatabase.instance.database;
    await db.delete('videos');
    await db.delete('chapter_markers');
    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FolderSelectScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SectionHeader(title: 'Home', subtitle: 'Local video theater — folders, memory, and playback tuned for you.'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FolderSelectScreen())),
                style: FilledButton.styleFrom(backgroundColor: CrowColors.accentYellow, foregroundColor: CrowColors.bg),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Select video folder'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.read<ShellNavState>().goTo(SidebarDestination.library),
                style: OutlinedButton.styleFrom(foregroundColor: CrowColors.accentCyan, side: const BorderSide(color: CrowColors.accentCyan)),
                icon: const Icon(Icons.video_library_rounded),
                label: const Text('Browse library'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.read<ShellNavState>().goTo(SidebarDestination.playlists),
                style: OutlinedButton.styleFrom(foregroundColor: CrowColors.accentYellow, side: const BorderSide(color: CrowColors.accentYellow)),
                icon: const Icon(Icons.playlist_play_rounded),
                label: const Text('My playlists'),
              ),
              OutlinedButton.icon(
                onPressed: _resetLibrary,
                style: OutlinedButton.styleFrom(foregroundColor: CrowColors.accentRed, side: const BorderSide(color: CrowColors.accentRed)),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Reset library'),
              ),
            ],
          ),
        ),
        if (_loaded && _continueWatching.isNotEmpty) _Shelf(title: 'Continue Watching', videos: _continueWatching),
        if (_loaded && _favorites.isNotEmpty) _Shelf(title: 'Favorites', videos: _favorites),
        if (_loaded && _continueWatching.isEmpty && _favorites.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Text(
              'Nothing here yet — select a folder to build your library, then come back for quick access to what you were watching.',
              style: TextStyle(color: CrowColors.onMuted),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.title, required this.videos});
  final String title;
  final List<VideoEntity> videos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(title.toUpperCase(),
              style: const TextStyle(color: CrowColors.accentYellow, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: videos.length,
            itemBuilder: (context, i) => SizedBox(
              width: 190,
              child: VideoGridCard(
                video: videos[i],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PlayerScreen(videoId: videos[i].id, siblingQueue: videos)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Convenience accessor used by screens that only need the repository.
VideoRepository repoOf(BuildContext context) => context.read<VideoRepository>();
