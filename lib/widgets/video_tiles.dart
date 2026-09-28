import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/video_repository.dart';
import '../models/video_entity.dart';
import '../theme/crow_colors.dart';
import '../util/format_utils.dart';
import 'keyboard_accessible.dart';

/// Responsive grid delegate used by every wide desktop video grid —
/// column count grows with window width instead of the phone app's
/// fixed 2-column grid.
///
/// A fixed row height (rather than an aspect ratio) is used on purpose:
/// the card's text block has a fixed height and the thumbnail simply
/// fills whatever is left, so there is never an empty gap at the bottom
/// of a card.
const SliverGridDelegateWithMaxCrossAxisExtent crowVideoGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 240,
  mainAxisExtent: 226,
  crossAxisSpacing: 4,
  mainAxisSpacing: 4,
);

/// Placeholder art — folder-tinted gradient with a play glyph. Shown
/// until (or instead of, if generation fails) the real preview frame.
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

/// A video's preview frame, loaded from the repository's thumbnail cache
/// (generated in the background by `ThumbnailService`). Falls back to the
/// placeholder art until one exists, and swaps itself in the moment the
/// thumbnail is ready — no library reload needed.
class VideoThumbnail extends StatefulWidget {
  const VideoThumbnail({super.key, required this.video, this.iconSize = 44});
  final VideoEntity video;
  final double iconSize;

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  late final VideoRepository _repo;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _repo = context.read<VideoRepository>();
    _bytes = _repo.cachedThumbnail(widget.video.id);
    _repo.thumbnailRevision.addListener(_refresh);
    if (_bytes == null) _refresh();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnail old) {
    super.didUpdateWidget(old);
    if (old.video.id != widget.video.id) {
      _bytes = _repo.cachedThumbnail(widget.video.id);
      _refresh();
    }
  }

  @override
  void dispose() {
    _repo.thumbnailRevision.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final id = widget.video.id;
    final bytes = await _repo.loadThumbnail(id);
    if (!mounted || widget.video.id != id) return;
    if (bytes != null && !identical(bytes, _bytes)) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return _ThumbArt(seed: widget.video.uriString, iconSize: widget.iconSize);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: 480,
          errorBuilder: (_, __, ___) => _ThumbArt(seed: widget.video.uriString, iconSize: widget.iconSize),
        ),
        Center(
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.35)),
            child: Icon(Icons.play_arrow_rounded, size: widget.iconSize * 0.7, color: Colors.white.withValues(alpha: 0.92)),
          ),
        ),
      ],
    );
  }
}

/// Round tick shown top-left of a tile while selecting.
class _SelectMark extends StatelessWidget {
  const _SelectMark({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? CrowColors.accentYellow : Colors.black.withValues(alpha: 0.45),
        border: Border.all(color: selected ? CrowColors.accentYellow : Colors.white70, width: 2),
      ),
      child: selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.black) : null,
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
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
  });

  final VideoEntity video;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return FocusableInkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      semanticsLabel: selectionMode ? '${selected ? 'Deselect' : 'Select'} ${video.title}' : video.title,
      child: Card(
        margin: const EdgeInsets.all(6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? CrowColors.accentYellow : CrowColors.accentCyan,
            width: selected ? 2.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The thumbnail takes ALL remaining height, so the card is
            // always exactly filled — no empty strip under the text.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoThumbnail(video: video),
                  if (selectionMode)
                    Positioned(top: 8, left: 8, child: _SelectMark(selected: selected))
                  else if (onRemove != null)
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
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 38,
                    child: Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: CrowColors.onBg, fontSize: 14, height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${FormatUtils.formatDuration(video.durationMs)} · ${FormatUtils.formatSize(video.sizeBytes)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
  });

  final VideoEntity video;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return FocusableInkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      semanticsLabel: selectionMode ? '${selected ? 'Deselect' : 'Select'} ${video.title}' : video.title,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? CrowColors.accentYellow : CrowColors.accentCyan,
            width: selected ? 2.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 104,
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoThumbnail(video: video, iconSize: 28),
                  if (selectionMode) Positioned(top: 6, left: 6, child: _SelectMark(selected: selected)),
                ],
              ),
            ),
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
            if (!selectionMode && onRemove != null)
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
