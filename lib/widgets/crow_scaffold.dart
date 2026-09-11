import 'package:flutter/material.dart';
import '../theme/crow_colors.dart';
import 'crow_title_bar.dart';
import 'mini_player.dart';

/// Chrome for screens pushed *on top of* [AppShell] as a standalone
/// route (folder picker, a playlist's drill-down video list) — window
/// title bar, an in-app toolbar with a back button, the body, and the
/// mini-player bar so playback stays visible/controllable. Primary
/// sidebar destinations don't use this — they render straight into
/// [AppShell]'s content area instead.
class CrowScaffold extends StatelessWidget {
  const CrowScaffold({
    super.key,
    required this.body,
    this.toolbar,
    this.floatingActionButton,
  });

  final Widget body;
  final Widget? toolbar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrowColors.bg,
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          const CrowTitleBar(),
          if (toolbar != null) toolbar!,
          Expanded(child: body),
          const MiniPlayer(),
        ],
      ),
    );
  }
}

/// Port of the repeated `MaterialToolbar` styling used across
/// `activity_*.xml` (crow_surface bg, back button, yellow title).
class CrowToolbar extends StatelessWidget implements PreferredSizeWidget {
  const CrowToolbar({
    super.key,
    this.title,
    this.showBack = true,
    this.actions,
    this.titleColor = CrowColors.onBg,
  });

  final String? title;
  final bool showBack;
  final List<Widget>? actions;
  final Color titleColor;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: CrowColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: CrowColors.onBg),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: 12),
          if (title != null)
            Expanded(
              child: Text(
                title!,
                style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            )
          else
            const Spacer(),
          ...?actions,
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
