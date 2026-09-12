import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/shell_nav.dart';
import '../theme/crow_colors.dart';
import 'keyboard_accessible.dart';

/// Left-hand desktop navigation rail. Replaces `BottomNavHelper.kt` /
/// `menu_bottom_nav.xml` for the Windows/Web shell — primary
/// destinations up top, utility destinations pinned to the bottom.
class CrowSidebar extends StatelessWidget {
  const CrowSidebar({super.key});

  static const _primary = [
    (SidebarDestination.home, Icons.home_rounded, 'Home'),
    (SidebarDestination.library, Icons.video_library_rounded, 'Library'),
    (SidebarDestination.favorites, Icons.star_rounded, 'Favorites'),
    (SidebarDestination.memory, Icons.history_rounded, 'Memory'),
    (SidebarDestination.explore, Icons.search_rounded, 'Explore'),
    (SidebarDestination.playlists, Icons.playlist_play_rounded, 'Playlists'),
  ];

  static const _utility = [
    (SidebarDestination.enhancement, Icons.auto_awesome_rounded, 'Enhancement'),
    (SidebarDestination.settings, Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<ShellNavState>();
    return Container(
      width: 216,
      color: CrowColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Row(
              children: [
                Image.asset('assets/icons/app_icon.png', width: 26, height: 26),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Crow Théatron',
                    style: TextStyle(
                      color: CrowColors.accentYellow,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Orbitron',
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          for (final item in _primary)
            _SidebarItem(
              icon: item.$2,
              label: item.$3,
              selected: nav.current == item.$1,
              onTap: () => nav.goTo(item.$1),
            ),
          const Spacer(),
          const Divider(color: CrowColors.divider, height: 1),
          const SizedBox(height: 6),
          for (final item in _utility)
            _SidebarItem(
              icon: item.$2,
              label: item.$3,
              selected: nav.current == item.$1,
              onTap: () => nav.goTo(item.$1),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? CrowColors.accentYellow : CrowColors.onBg;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: FocusableInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        semanticsLabel: label,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? CrowColors.accentYellow.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: selected ? CrowColors.accentYellow : Colors.transparent, width: 3)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 14),
              Text(label, style: TextStyle(color: color, fontSize: 13.5, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}
