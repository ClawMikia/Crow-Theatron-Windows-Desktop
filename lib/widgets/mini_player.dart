import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../screens/player_screen.dart';
import '../services/playback_service.dart';
import '../theme/crow_colors.dart';
import '../util/format_utils.dart';
import 'keyboard_accessible.dart';

/// Full-width bottom-docked playback bar — sits under the sidebar +
/// content area (like a desktop media player's transport bar), so
/// playback keeps going while browsing the rest of the app. Port of
/// `layout_mini_player.xml` + `ui/MiniPlayerHelper.kt`, restructured
/// for a wide desktop window instead of a phone-width floating card.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  VideoController? _controller;
  int? _controllerForVideoId;

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<PlaybackService>();
    final video = svc.currentVideo;

    if (video == null || svc.isPlayerScreenVisible) {
      return const SizedBox.shrink();
    }

    if (_controllerForVideoId != video.id) {
      _controller = VideoController(svc.player);
      _controllerForVideoId = video.id;
    }

    final playing = svc.player.state.playing;
    final pos = svc.player.state.position.inMilliseconds;
    final dur = svc.player.state.duration.inMilliseconds;

    return Container(
      height: 78,
      decoration: const BoxDecoration(
        color: CrowColors.surfaceElevated,
        border: Border(top: BorderSide(color: CrowColors.divider)),
      ),
      child: Row(
        children: [
          // ── Track info (click to reopen full player) ──
          Expanded(
            flex: 3,
            child: FocusableInkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(videoId: video.id))),
              semanticsLabel: 'Now playing: ${video.title}',
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: ColoredBox(
                          color: CrowColors.pureBlack,
                          child: _controller == null ? null : Video(controller: _controller!, controls: NoVideoControls),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            video.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: CrowColors.onBg, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(video.folderGroup, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CrowColors.onMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Transport + seek ──
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FocusableIconButton(icon: const Icon(Icons.skip_previous_rounded), onPressed: svc.playPrevious, tooltip: 'Previous', semanticsLabel: 'Previous track'),
                    FocusableIconButton(icon: const Icon(Icons.replay_10_rounded), onPressed: () => svc.seekRelative(-10000), tooltip: 'Rewind 10s', semanticsLabel: 'Rewind 10 seconds'),
                    FocusableIconButton(
                      icon: Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded),
                      onPressed: svc.togglePlayPause,
                      size: 30,
                      color: CrowColors.accentRed,
                      tooltip: playing ? 'Pause' : 'Play',
                      semanticsLabel: playing ? 'Pause' : 'Play',
                    ),
                    FocusableIconButton(icon: const Icon(Icons.forward_10_rounded), onPressed: () => svc.seekRelative(10000), tooltip: 'Forward 10s', semanticsLabel: 'Forward 10 seconds'),
                    FocusableIconButton(icon: const Icon(Icons.skip_next_rounded), onPressed: svc.playNext, tooltip: 'Next', semanticsLabel: 'Next track'),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 12),
                    Text(FormatUtils.formatDuration(pos), style: const TextStyle(color: CrowColors.onMuted, fontSize: 10)),
                    Expanded(
                      child: FocusableSlider(
                        value: pos.clamp(0, dur > 0 ? dur : 1).toDouble(),
                        min: 0,
                        max: (dur > 0 ? dur : 1).toDouble(),
                        onChanged: (v) => svc.seekTo(v.toInt()),
                        semanticsLabel: 'Playback position',
                        semanticsValue: FormatUtils.formatDuration(pos),
                      ),
                    ),
                    Text(FormatUtils.formatDuration(dur), style: const TextStyle(color: CrowColors.onMuted, fontSize: 10)),
                    const SizedBox(width: 12),
                  ],
                ),
              ],
            ),
          ),
          // ── Volume + close ──
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FocusableIconButton(
                  icon: const Icon(Icons.volume_up_rounded, size: 18, color: CrowColors.onMuted),
                  onPressed: () => svc.toggleMute(),
                  tooltip: 'Mute/Unmute',
                  semanticsLabel: 'Mute/Unmute',
                ),
                SizedBox(
                  width: 90,
                  child: FocusableSlider(
                    value: (video.volumeLevel * 100).clamp(0, 100),
                    min: 0,
                    max: 100,
                    onChanged: (v) => svc.player.setVolume(v),
                    semanticsLabel: 'Volume',
                    semanticsValue: '${(video.volumeLevel * 100).round()}%',
                  ),
                ),
                FocusableIconButton(icon: const Icon(Icons.close_rounded), onPressed: svc.close, tooltip: 'Close player', semanticsLabel: 'Close mini player'),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
