import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../models/video_entity.dart';
import '../screens/player_screen.dart';
import '../services/playback_service.dart';
import '../theme/crow_colors.dart';
import '../util/format_utils.dart';
import 'keyboard_accessible.dart';

/// Standard video player keyboard shortcuts (matching YouTube, VLC, MPV, etc.)
class _VideoPlayerShortcuts {
  static const Duration _seekShort = Duration(seconds: 5);
  static const Duration _seekMedium = Duration(seconds: 10);
  static const Duration _seekLong = Duration(seconds: 30);
  static const Duration _seekFrame = Duration(milliseconds: 100); // ~1 frame at 30fps
  static const double _volumeStep = 5.0;
  static const double _speedStep = 0.25;

  static KeyEventResult handleKeyEvent(
    KeyEvent event,
    PlaybackService svc,
    VideoEntity video, {
    required VoidCallback onFullscreen,
    required VoidCallback onAddChapter,
    required VoidCallback onAddSkip,
    required VoidCallback onNextChapter,
    required VoidCallback onPreviousChapter,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final logicalKey = event.logicalKey;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isControl = HardwareKeyboard.instance.isControlPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;

    // Handle number keys 0-9 for seeking to percentage
    if (_isDigitKey(logicalKey)) {
      final digit = _digitKeyToInt(logicalKey);
      if (digit != null) {
        final percent = digit * 10;
        final duration = svc.player.state.duration.inMilliseconds;
        if (duration > 0) {
          svc.seekTo((duration * percent / 100).round());
        }
      }
      return KeyEventResult.handled;
    }

    switch (logicalKey) {
      // Play/Pause - Space or K
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.keyK:
        svc.togglePlayPause();
        return KeyEventResult.handled;

      // Fullscreen - F
      case LogicalKeyboardKey.keyF:
        onFullscreen();
        return KeyEventResult.handled;

      // Mute - M
      case LogicalKeyboardKey.keyM:
        svc.toggleMute();
        return KeyEventResult.handled;

      // Seek backward/forward - Arrow keys
      case LogicalKeyboardKey.arrowLeft:
        if (isControl) {
          svc.seekRelative(-_seekLong.inMilliseconds); // Ctrl+←: -30s
        } else if (isShift) {
          svc.seekRelative(-_seekFrame.inMilliseconds); // Shift+←: -1 frame
        } else if (isAlt) {
          svc.seekRelative(-_seekShort.inMilliseconds); // Alt+←: -5s
        } else {
          svc.seekRelative(-_seekMedium.inMilliseconds); // ←: -10s
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowRight:
        if (isControl) {
          svc.seekRelative(_seekLong.inMilliseconds); // Ctrl+→: +30s
        } else if (isShift) {
          svc.seekRelative(_seekFrame.inMilliseconds); // Shift+→: +1 frame
        } else if (isAlt) {
          svc.seekRelative(_seekShort.inMilliseconds); // Alt+→: +5s
        } else {
          svc.seekRelative(_seekMedium.inMilliseconds); // →: +10s
        }
        return KeyEventResult.handled;

      // J/L for 10s seek (YouTube style)
      case LogicalKeyboardKey.keyJ:
        svc.seekRelative(-_seekMedium.inMilliseconds);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyL:
        svc.seekRelative(_seekMedium.inMilliseconds);
        return KeyEventResult.handled;

      // Volume - Arrow Up/Down
      case LogicalKeyboardKey.arrowUp:
        svc.player.setVolume((svc.player.state.volume + _volumeStep).clamp(0, 100));
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowDown:
        svc.player.setVolume((svc.player.state.volume - _volumeStep).clamp(0, 100));
        return KeyEventResult.handled;

      // Home/End - Beginning/End
      case LogicalKeyboardKey.home:
        svc.seekTo(0);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.end:
        final dur = svc.player.state.duration.inMilliseconds;
        if (dur > 0) svc.seekTo(dur);
        return KeyEventResult.handled;

      // Speed control - >/< or ./,
      case LogicalKeyboardKey.period:
      case LogicalKeyboardKey.keyE: // E for faster
        if (isShift) {
          _adjustSpeed(svc, video, _speedStep);
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.comma:
      case LogicalKeyboardKey.keyW: // W for slower
        if (isShift) {
          _adjustSpeed(svc, video, -_speedStep);
        }
        return KeyEventResult.handled;

      // Reset speed - Ctrl+R
      case LogicalKeyboardKey.keyR:
        if (isControl) {
          svc.player.setRate(1.0);
        }
        return KeyEventResult.handled;

      // Next/Previous track - Shift+N / Shift+P
      case LogicalKeyboardKey.keyN:
        if (isShift) {
          svc.playNext();
        } else {
          onNextChapter();
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyP:
        if (isShift) {
          svc.playPrevious();
        } else {
          onPreviousChapter();
        }
        return KeyEventResult.handled;

      // Add chapter - C
      case LogicalKeyboardKey.keyC:
        onAddChapter();
        return KeyEventResult.handled;

      // Add skip - Ctrl+K
      case LogicalKeyboardKey.keyK:
        if (isControl) onAddSkip();
        return KeyEventResult.handled;

      // Escape - exit fullscreen or close
      case LogicalKeyboardKey.escape:
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  static bool _isDigitKey(LogicalKeyboardKey key) {
    return key.keyId >= LogicalKeyboardKey.digit0.keyId && key.keyId <= LogicalKeyboardKey.digit9.keyId;
  }

  static int? _digitKeyToInt(LogicalKeyboardKey key) {
    if (!_isDigitKey(key)) return null;
    return key.keyId - LogicalKeyboardKey.digit0.keyId;
  }

  static void _adjustSpeed(PlaybackService svc, VideoEntity video, double delta) {
    final newSpeed = (video.playbackSpeed + delta).clamp(0.25, 4.0);
    svc.player.setRate(newSpeed);
  }
}

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

    final focusNode = FocusNode();

    return Focus(
      focusNode: focusNode,
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        return _VideoPlayerShortcuts.handleKeyEvent(
          event,
          svc,
          video,
          onFullscreen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(videoId: video.id))),
          onAddChapter: () {},
          onAddSkip: () {},
          onNextChapter: () {},
          onPreviousChapter: () {},
        );
      },
      child: Container(
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
    ),
  );
  }
}
