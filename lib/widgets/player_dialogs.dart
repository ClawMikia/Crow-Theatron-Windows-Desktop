import 'package:flutter/material.dart';
import '../theme/crow_colors.dart';
import '../util/format_utils.dart';

/// Port of `dialog_add_chapter.xml`.
Future<String?> showAddChapterDialog(BuildContext context, int positionMs) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: CrowColors.surfaceElevated,
      title: const Text('Add Chapter', style: TextStyle(color: CrowColors.onBg)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('At ${FormatUtils.formatDuration(positionMs)}', style: const TextStyle(color: CrowColors.accentCyan)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: CrowColors.onBg),
            decoration: const InputDecoration(hintText: 'Chapter label', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim().isEmpty ? 'Chapter' : controller.text.trim()),
          child: const Text('Add', style: TextStyle(color: CrowColors.accentCyan)),
        ),
      ],
    ),
  );
}

/// Port of `dialog_add_skip.xml`. Returns (startMs, endMs, label) or null.
Future<(int, int, String)?> showAddSkipDialog(BuildContext context, {required int initialStartMs, required int initialEndMs}) {
  final startCtrl = TextEditingController(text: FormatUtils.formatDuration(initialStartMs));
  final endCtrl = TextEditingController(text: FormatUtils.formatDuration(initialEndMs));
  final labelCtrl = TextEditingController(text: 'Skip');

  int? _parse(String text) {
    final parts = text.split(':').map((e) => int.tryParse(e.trim())).toList();
    if (parts.any((e) => e == null)) return null;
    if (parts.length == 3) return ((parts[0]! * 3600) + (parts[1]! * 60) + parts[2]!) * 1000;
    if (parts.length == 2) return ((parts[0]! * 60) + parts[1]!) * 1000;
    return null;
  }

  return showDialog<(int, int, String)>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: CrowColors.surfaceElevated,
      title: const Text('Add Timeline Skip', style: TextStyle(color: CrowColors.onBg)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: startCtrl,
            style: const TextStyle(color: CrowColors.onBg),
            decoration: const InputDecoration(labelText: 'Start (m:ss)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: endCtrl,
            style: const TextStyle(color: CrowColors.onBg),
            decoration: const InputDecoration(labelText: 'End (m:ss)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: labelCtrl,
            style: const TextStyle(color: CrowColors.onBg),
            decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final s = _parse(startCtrl.text);
            final e = _parse(endCtrl.text);
            if (s == null || e == null || e <= s) return;
            Navigator.pop(ctx, (s, e, labelCtrl.text.trim().isEmpty ? 'Skip' : labelCtrl.text.trim()));
          },
          child: const Text('Add', style: TextStyle(color: CrowColors.accentPink)),
        ),
      ],
    ),
  );
}
