import 'package:flutter/material.dart';
import '../models/video_entity.dart';
import '../theme/crow_colors.dart';
import '../util/format_utils.dart';
import 'keyboard_accessible.dart';

/// Responsive grid delegate used by every wide desktop video grid —
/// column count grows with window width instead of the phone app's
/// fixed 2-column grid.
const SliverGridDelegateWithMaxCrossAxisExtent crowVideoGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 240,
  childAspectRatio: 0.78,
  crossAxisSpacing: 4,
  mainAxisSpacing: 4,
);

/// Placeholder art tile — desktop has no cheap video-frame thumbnailer
/// wired up here, so we render a folder-tinted gradient with a play glyph,
/// matching the card's shape/role from `item_video_card.xml`.
class _ThumbArt extends StatelessWidget {
  const _ThumbArt({required this.seed, this.iconSize = 44});
  final String seed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final hues = [
      CrowColors.accentCyan,
      CrowColors.accentPurple,
      CrowColors.accentBlue,
      CrowColors.accentOrange,
    ];
    final color = hues[seed.hashCode.abs() % hues.length];
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.22), CrowColors.surfaceElevated],
            ),
          ),
        ),
        Center(
          child: Icon(Icons.play_circle_fill_rounded, size: iconSize, color: CrowColors.accentRed.withValues(alpha: 0.92)),
        ),
      ],
    );
  }
}

/// Port of `item_library_header.xml` — section header with a yellow tick.
class LibrarySectionHeader extends StatelessWidget {
  const LibrarySectionHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 3, height: 32, color: CrowColors.accentYellow),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: CrowColors.accentYellow,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Port of `item_video_card.xml` — grid tile with thumbnail, title, meta.
class VideoGridCard extends StatelessWidget {
  const VideoGridCard({
    super.key,
    required this.video,
    required this.onTap,
    this.onRemove,
  });

  final VideoEntity video;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return FocusableInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      semanticsLabel: video.title,
      child: Card(
        margin: const EdgeInsets.all(6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: CrowColors.accentCyan, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ThumbArt(seed: video.uriString),
                  if (onRemove != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: FocusableIconButton(
                        icon: const Icon(Icons.close_rounded, size: 16, color: CrowColors.accentRed),
                        onPressed: onRemove!,
                        tooltip: 'Remove',
                        semanticsLabel: 'Remove ${video.title}',
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: CrowColors.onBg, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${FormatUtils.formatDuration(video.durationMs)} · ${FormatUtils.formatSize(video.sizeBytes)}',
                    style: const TextStyle(color: CrowColors.onMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Port of `item_video_list_row.xml` — horizontal list row variant.
class VideoListRow extends StatelessWidget {
  const VideoListRow({
    super.key,
    required this.video,
    required this.onTap,
    this.onRemove,
  });

  final VideoEntity video;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return FocusableInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      semanticsLabel: video.title,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: CrowColors.accentCyan, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(width: 80, height: 64, child: _ThumbArt(seed: video.uriString, iconSize: 28)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: CrowColors.onBg, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${FormatUtils.formatDuration(video.durationMs)} · ${FormatUtils.formatSize(video.sizeBytes)}',
                      style: const TextStyle(color: CrowColors.onMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            if (onRemove != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FocusableIconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: CrowColors.accentRed),
                  onPressed: onRemove!,
                  tooltip: 'Remove',
                  semanticsLabel: 'Remove ${video.title}',
                  padding: const EdgeInsets.all(8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
