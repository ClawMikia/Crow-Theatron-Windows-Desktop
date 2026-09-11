/// Port of `util/FormatUtils.kt`.
class FormatUtils {
  FormatUtils._();

  static String formatDuration(int ms) {
    final absMs = ms < 0 ? 0 : ms;
    final s = absMs ~/ 1000;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  static String formatSize(int bytes) {
    if (bytes <= 0) return '—';
    final kb = bytes / 1024.0;
    final mb = kb / 1024.0;
    final gb = mb / 1024.0;
    if (gb >= 1.0) return '${gb.toStringAsFixed(2)} GB';
    if (mb >= 1.0) return '${mb.toStringAsFixed(1)} MB';
    return '${kb.toStringAsFixed(0)} KB';
  }
}
