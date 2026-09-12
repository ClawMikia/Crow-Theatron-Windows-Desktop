import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_prefs.dart';
import '../models/enhancement_mode.dart';
import '../theme/crow_colors.dart';
import '../widgets/section_header.dart';

/// Port of `activity_video_enhancement.xml` + `enhancement/VideoEnhancementActivity.kt`
/// + `enhancement/EnhancementListAdapter.kt`. Sets the default enhancement
/// applied to newly-imported videos (each video can still override it from
/// the Player screen's Visual Enhancement card). Embedded directly in
/// [AppShell]'s content area (Enhancement sidebar item).
class EnhancementScreen extends StatefulWidget {
  const EnhancementScreen({super.key});

  @override
  State<EnhancementScreen> createState() => _EnhancementScreenState();
}

class _EnhancementScreenState extends State<EnhancementScreen> {
  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPrefs>();
    return Column(
      children: [
        const SectionHeader(title: 'Video Enhancement', subtitle: 'Default look applied to newly-imported videos'),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              childAspectRatio: 2.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: EnhancementMode.values.length,
            itemBuilder: (context, i) {
              final mode = EnhancementMode.values[i];
              final selected = prefs.defaultEnhancement == mode;
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: selected ? CrowColors.accentPurple : CrowColors.divider, width: selected ? 1.6 : 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    prefs.defaultEnhancement = mode;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Default set to ${mode.displayName}')));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: selected ? CrowColors.accentPurple : CrowColors.onMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(mode.displayName, style: const TextStyle(color: CrowColors.onBg, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              Text(mode.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CrowColors.onMuted, fontSize: 11.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
