import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../screens/player_screen.dart';
import '../services/playback_service.dart';
import '../theme/crow_colors.dart';
import '../util/format_utils.dart';

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
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(videoId: video.id))),
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
                    _Btn(icon: Icons.skip_previous_rounded, onTap: svc.playPrevious),
                    _Btn(icon: Icons.replay_10_rounded, onTap: () => svc.seekRelative(-10000)),
                    _Btn(
                      icon: playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                      size: 30,
                      color: CrowColors.accentRed,
                      onTap: svc.togglePlayPause,
                    ),
                    _Btn(icon: Icons.forward_10_rounded, onTap: () => svc.seekRelative(10000)),
                    _Btn(icon: Icons.skip_next_rounded, onTap: svc.playNext),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 12),
                    Text(FormatUtils.formatDuration(pos), style: const TextStyle(color: CrowColors.onMuted, fontSize: 10)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        ),
                        child: Slider(
                          value: pos.clamp(0, dur > 0 ? dur : 1).toDouble(),
                          min: 0,
                          max: (dur > 0 ? dur : 1).toDouble(),
                          onChanged: (v) => svc.seekTo(v.toInt()),
                        ),
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
                const Icon(Icons.volume_up_rounded, size: 18, color: CrowColors.onMuted),
                SizedBox(
                  width: 90,
                  child: Slider(
                    value: (video.volumeLevel * 100).clamp(0, 100),
                    min: 0,
                    max: 100,
                    onChanged: (v) => svc.player.setVolume(v),
                  ),
                ),
                _Btn(icon: Icons.close_rounded, onTap: svc.close),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.onTap, this.size = 20, this.color = CrowColors.onBg});
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: Icon(icon, color: color, size: size), onPressed: onTap, splashRadius: 20);
  }
}
