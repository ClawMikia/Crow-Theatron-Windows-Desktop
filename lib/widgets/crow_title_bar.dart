import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/crow_colors.dart';

/// Frameless-window title bar: app icon (also used as the taskbar/title
/// bar icon via windows/runner/Runner.rc) + app name on the left, and
/// the three standard window buttons — minimize, maximize/restore,
/// close — on the right. No-ops gracefully on web.
class CrowTitleBar extends StatefulWidget implements PreferredSizeWidget {
  const CrowTitleBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(32);

  @override
  State<CrowTitleBar> createState() => _CrowTitleBarState();
}

class _CrowTitleBarState extends State<CrowTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      windowManager.addListener(this);
      windowManager.isMaximized().then((v) => setState(() => _isMaximized = v));
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    return Container(
      height: 32,
      color: CrowColors.surface,
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Image.asset('assets/icons/app_icon.png', width: 18, height: 18),
                  const SizedBox(width: 10),
                  const Text(
                    'Crow Théatron',
                    style: TextStyle(
                      color: CrowColors.accentYellow,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                ],
              ),
            ),
          ),
          _TitleBarButton(
            icon: Icons.remove,
            onTap: () => windowManager.minimize(),
          ),
          _TitleBarButton(
            icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
            iconSize: _isMaximized ? 13 : 14,
            onTap: () async {
              if (await windowManager.isMaximized()) {
                windowManager.unmaximize();
              } else {
                windowManager.maximize();
              }
            },
          ),
          _TitleBarButton(
            icon: Icons.close,
            hoverColor: CrowColors.accentRed,
            onTap: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  const _TitleBarButton({
    required this.icon,
    required this.onTap,
    this.hoverColor,
    this.iconSize = 14,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? hoverColor;
  final double iconSize;

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 32,
          color: _hover ? (widget.hoverColor ?? CrowColors.surfaceElevated) : Colors.transparent,
          alignment: Alignment.center,
          child: Icon(widget.icon, size: widget.iconSize, color: CrowColors.onBg),
        ),
      ),
    );
  }
}
