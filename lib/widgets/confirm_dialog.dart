import 'package:flutter/material.dart';
import '../theme/crow_colors.dart';

/// Standard "are you sure?" modal for anything destructive. Returns true
/// only if the user explicitly confirms. Focus starts on Cancel so a
/// stray Enter / Space press can't delete something by accident.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: CrowColors.surfaceElevated,
      title: Text(title, style: const TextStyle(color: CrowColors.onBg)),
      content: Text(message, style: const TextStyle(color: CrowColors.onMuted)),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: const TextStyle(color: CrowColors.accentRed)),
        ),
      ],
    ),
  );
  return result == true;
}
