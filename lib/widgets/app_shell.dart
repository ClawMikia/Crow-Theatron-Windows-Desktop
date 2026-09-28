import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../screens/enhancement_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/library_screen.dart';
import '../screens/main_screen.dart';
import '../screens/playlist_list_screen.dart';
import '../screens/settings_screen.dart';
import '../shortcuts/app_shortcuts.dart';
import '../state/shell_nav.dart';
import '../theme/crow_colors.dart';
import 'crow_sidebar.dart';
import 'crow_title_bar.dart';
import 'mini_player.dart';

/// The persistent desktop frame: window title bar on top, a left
/// sidebar for primary navigation, a switched content area that keeps
/// every destination's scroll/search state alive via [IndexedStack],
/// and a full-width mini-player docked at the bottom.
///
/// Every keyboard shortcut in the app while browsing (outside the full
/// PlayerScreen) is bound exactly once here, from the single canonical
/// table in `shortcuts/app_shortcuts.dart` — see that file for the
/// full scheme and for why the old per-widget shortcut handling
/// (three separate, overlapping binding tables) was removed.
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

  Future<void> _quit() async {
    if (!kIsWeb) {
      await windowManager.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<ShellNavState>();
    final index = _order.indexOf(nav.current);

    return Builder(
      builder: (shortcutsContext) {
        final shortcuts = globalShortcutsFor(
          shortcutsContext,
          onQuit: _quit,
          onShowHelp: () => showShortcutsHelp(
            shortcutsContext,
            globalShortcutsFor(shortcutsContext, onQuit: _quit, onShowHelp: () {}),
          ),
        );
        return AppShortcutsScope(
          shortcuts: shortcuts,
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
      },
    );
  }
}
