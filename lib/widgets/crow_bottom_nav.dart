import 'package:flutter/material.dart';
import '../theme/crow_colors.dart';
import '../screens/explore_screen.dart';
import '../screens/library_screen.dart';
import '../screens/main_screen.dart';
import '../screens/playback_memory_screen.dart';
import 'keyboard_accessible.dart';

enum CrowNavTab { home, library, favorites, memory, explore }

/// Port of `menu/menu_bottom_nav.xml` + `ui/BottomNavHelper.kt`.
class CrowBottomNav extends StatelessWidget {
  const CrowBottomNav({super.key, required this.current});

  final CrowNavTab current;

  void _go(BuildContext context, CrowNavTab tab) {
    if (tab == current) return;
    Widget page;
    switch (tab) {
      case CrowNavTab.home:
        page = const MainScreen();
        break;
      case CrowNavTab.library:
        page = const LibraryScreen(mode: LibraryMode.all);
        break;
      case CrowNavTab.favorites:
        page = const LibraryScreen(mode: LibraryMode.favorites);
        break;
      case CrowNavTab.memory:
        page = const PlaybackMemoryScreen();
        break;
      case CrowNavTab.explore:
        page = const ExploreScreen();
        break;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CrowColors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: current == CrowNavTab.home,
                onTap: () => _go(context, CrowNavTab.home),
              ),
              _NavItem(
                icon: Icons.video_library_rounded,
                label: 'Library',
                selected: current == CrowNavTab.library,
                onTap: () => _go(context, CrowNavTab.library),
              ),
              _NavItem(
                icon: Icons.star_rounded,
                label: 'Favorites',
                selected: current == CrowNavTab.favorites,
                onTap: () => _go(context, CrowNavTab.favorites),
              ),
              _NavItem(
                icon: Icons.history_rounded,
                label: 'Memory',
                selected: current == CrowNavTab.memory,
                onTap: () => _go(context, CrowNavTab.memory),
              ),
              _NavItem(
                icon: Icons.search_rounded,
                label: 'Explore',
                selected: current == CrowNavTab.explore,
                onTap: () => _go(context, CrowNavTab.explore),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? CrowColors.accentYellow : CrowColors.onBg;
    return Expanded(
      child: FocusableInkWell(
        onTap: onTap,
        semanticsLabel: label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
