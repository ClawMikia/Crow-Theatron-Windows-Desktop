import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/enhancement_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/library_screen.dart';
import '../screens/main_screen.dart';
import '../screens/playlist_list_screen.dart';
import '../screens/settings_screen.dart';
import '../services/playback_service.dart';
import '../state/shell_nav.dart';
import '../theme/crow_colors.dart';
import 'crow_sidebar.dart';
import 'crow_title_bar.dart';
import 'mini_player.dart';
import 'keyboard_accessible.dart';

/// The persistent desktop frame: window title bar on top, a left
/// sidebar for primary navigation, a switched content area that keeps
/// every destination's scroll/search state alive via [IndexedStack],
/// and a full-width mini-player docked at the bottom. Replaces the
/// old per-screen `CrowScaffold(currentTab: ...)` bottom-nav pattern.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _order = [
    SidebarDestination.home,
    SidebarDestination.library,
    SidebarDestination.favorites,
    SidebarDestination.memory,
    SidebarDestination.explore,
    SidebarDestination.playlists,
    SidebarDestination.enhancement,
    SidebarDestination.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<ShellNavState>();
    final index = _order.indexOf(nav.current);
    final svc = context.watch<PlaybackService>();

    return KeyboardActions(
      onPlayPause: svc.togglePlayPause,
      onFullscreen: () {
        // Find the PlayerScreen and toggle fullscreen
        // This is handled by the PlayerScreen itself
      },
      onMute: () => svc.toggleMute(),
      onSeekForward: () => svc.seekRelative(10000),
      onSeekBackward: () => svc.seekRelative(-10000),
      onSeekForwardLarge: () => svc.seekRelative(30000),
      onSeekBackwardLarge: () => svc.seekRelative(-30000),
      onVolumeUp: () => svc.player.setVolume((svc.player.state.volume + 10).clamp(0, 100)),
      onVolumeDown: () => svc.player.setVolume((svc.player.state.volume - 10).clamp(0, 100)),
      onNextTrack: svc.playNext,
      onPreviousTrack: svc.playPrevious,
      onEscape: () {
        if (svc.isPlayerScreenVisible) {
          Navigator.of(context).maybePop();
        }
      },
      onNavigateHome: () => nav.goTo(SidebarDestination.home),
      onNavigateLibrary: () => nav.goTo(SidebarDestination.library),
      onNavigateFavorites: () => nav.goTo(SidebarDestination.favorites),
      onOpenSettings: () => nav.goTo(SidebarDestination.settings),
      onAddChapter: () {
        // Handled by PlayerScreen
      },
      onAddSkip: () {
        // Handled by PlayerScreen
      },
      child: Scaffold(
        backgroundColor: CrowColors.bg,
        body: Column(
          children: [
            const CrowTitleBar(),
            Expanded(
              child: Row(
                children: [
                  const CrowSidebar(),
                  const VerticalDivider(width: 1, color: CrowColors.divider),
                  Expanded(
                    child: IndexedStack(
                      index: index,
                      children: const [
                        MainScreen(),
                        LibraryScreen(mode: LibraryMode.all),
                        LibraryScreen(mode: LibraryMode.favorites),
                        LibraryScreen(mode: LibraryMode.continueWatching),
                        ExploreScreen(),
                        PlaylistListScreen(),
                        EnhancementScreen(),
                        SettingsScreen(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }
}
