import 'package:flutter/material.dart';
import '../theme/crow_colors.dart';

/// In-content header for screens living inside [AppShell] (as opposed to
/// pushed standalone routes, which use `CrowToolbar` with a back button).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.actions});

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: CrowColors.onBg, fontSize: 22, fontWeight: FontWeight.bold)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: const TextStyle(color: CrowColors.onMuted, fontSize: 13)),
                ],
              ],
            ),
          ),
          ...?actions,
        ],
      ),
    );
  }
}
