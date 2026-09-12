import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../data/video_repository.dart';
import '../models/chapter_marker.dart';
import '../models/enhancement_mode.dart';
import '../models/timeline_skip.dart';
import '../models/video_entity.dart';
import '../services/playback_service.dart';
import '../theme/crow_colors.dart';
import '../util/format_utils.dart';
import '../widgets/crow_title_bar.dart';
import '../widgets/player_dialogs.dart';
import 'main_screen.dart';
import '../widgets/keyboard_accessible.dart';

/// Standard video player keyboard shortcuts (matching YouTube, VLC, MPV, etc.)
class _VideoPlayerShortcuts {
  static const Duration _seekShort = Duration(seconds: 5);
  static const Duration _seekMedium = Duration(seconds: 10);
  static const Duration _seekLong = Duration(seconds: 30);
  static const Duration _seekFrame =
      Duration(milliseconds: 100); // ~1 frame at 30fps
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
    required VoidCallback onExit,
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
        svc.player
            .setVolume((svc.player.state.volume + _volumeStep).clamp(0, 100));
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowDown:
        svc.player
            .setVolume((svc.player.state.volume - _volumeStep).clamp(0, 100));
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
        onExit();
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  static bool _isDigitKey(LogicalKeyboardKey key) {
    return key.keyId >= LogicalKeyboardKey.digit0.keyId &&
        key.keyId <= LogicalKeyboardKey.digit9.keyId;
  }

  static int? _digitKeyToInt(LogicalKeyboardKey key) {
    if (!_isDigitKey(key)) return null;
    return key.keyId - LogicalKeyboardKey.digit0.keyId;
  }

  static void _adjustSpeed(
      PlaybackService svc, VideoEntity video, double delta) {
    final newSpeed = (video.playbackSpeed + delta).clamp(0.25, 4.0);
    svc.player.setRate(newSpeed);
  }
}

/// Port of `player/PlayerActivity.kt` + `activity_player.xml` — the full
/// per-video control surface: transport, volume/pitch/speed, trim,
/// timeline skips, chapters, visual enhancement, and playback options.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.videoId, this.siblingQueue});

  final int videoId;
  final List<VideoEntity>? siblingQueue;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoEntity? _video;
  List<ChapterMarker> _chapters = [];
  List<TimelineSkip> _skips = [];
  bool _fullscreen = false;
  late VideoController _controller;
  PlaybackService? _svc;
  VideoRepository? _repo;
  final FocusNode _playerFocusNode =
      FocusNode(debugLabel: 'player keyboard focus');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final svc = context.read<PlaybackService>();
    _svc = svc;
    _repo = repoOf(context);
    _repo!.addListener(_onRepoChanged);
    svc.addListener(_onPlaybackServiceChanged);
    svc.setPlayerScreenVisible(true);
    final video = await _repo!.getById(widget.videoId);
    if (video == null || !mounted) return;
    setState(() => _video = video);
    _playerFocusNode.requestFocus();
    _controller = VideoController(svc.player);
    if (svc.currentVideo?.id != video.id) {
      await svc.play(video, siblings: widget.siblingQueue);
    }
    await _reloadChaptersAndSkips();
  }

  void _onRepoChanged() {
    if (!mounted) return;
    _reloadChaptersAndSkips();
    _refreshVideo();
  }

  void _onPlaybackServiceChanged() {
    if (!mounted || _video == null) return;
    final current = _svc?.currentVideo;
    if (current != null && current.id != _video!.id) {
      setState(() => _video = current);
      _reloadChaptersAndSkips();
    }
  }

  Future<void> _refreshVideo() async {
    final updated = await _repo!.getById(widget.videoId);
    if (updated != null && mounted && updated != _video) {
      setState(() => _video = updated);
    }
  }

  Future<void> _reloadChaptersAndSkips() async {
    final chapters = await _repo!.listChapters(widget.videoId);
    final skips = await _repo!.listSkips(widget.videoId);
    if (mounted) {
      setState(() {
        _chapters = chapters;
        _skips = skips;
      });
    }
  }

  @override
  void dispose() {
    _repo?.removeListener(_onRepoChanged);
    _svc?.removeListener(_onPlaybackServiceChanged);
    _playerFocusNode.dispose();
    _svc?.setPlayerScreenVisible(false);
    super.dispose();
  }

  Future<void> _saveVideo(VideoEntity updated) async {
    setState(() => _video = updated);
    await _repo!.savePreferences(updated);
    if (_svc?.currentVideo?.id == updated.id) {
      _svc!.currentVideo = updated;
      await _svc!.applyVideoFilters(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    if (video == null) {
      return const Scaffold(
        backgroundColor: CrowColors.bg,
        body: Center(
            child: CircularProgressIndicator(color: CrowColors.accentYellow)),
      );
    }
    return CallbackShortcuts(
      bindings: _playerShortcuts(video),
      child: Scaffold(
        backgroundColor: CrowColors.bg,
        body: Column(
          children: [
            if (!_fullscreen) const CrowTitleBar(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildVideoSurface(video)),
                  if (!_fullscreen) _buildSidePanel(video),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _playerShortcuts(VideoEntity video) {
    final shortcuts = <ShortcutActivator, VoidCallback>{};

    void bind(LogicalKeyboardKey key, VoidCallback action,
        {bool shift = false}) {
      shortcuts[SingleActivator(key, control: true, alt: true, shift: shift)] =
          action;
    }

    void bindShift(LogicalKeyboardKey key, VoidCallback action) {
      shortcuts[SingleActivator(key, control: true, shift: true)] = action;
    }

    bind(LogicalKeyboardKey.keyB, () => Navigator.of(context).maybePop());
    bind(LogicalKeyboardKey.keyC, _addChapterAtCurrentPosition);
    bind(LogicalKeyboardKey.keyF,
        () => setState(() => _fullscreen = !_fullscreen));
    bind(LogicalKeyboardKey.keyR, () => _svc?.restart());
    bind(LogicalKeyboardKey.keyP, () => _svc?.playPrevious());
    bind(LogicalKeyboardKey.keyN, () => _svc?.playNext());
    bind(LogicalKeyboardKey.keyW,
        () => _svc?.seekRelative(-video.seekJumpSec * 1000));
    bind(LogicalKeyboardKey.keyE,
        () => _svc?.seekRelative(video.seekJumpSec * 1000));
    bind(LogicalKeyboardKey.keyX, () => _svc?.close());

    bind(LogicalKeyboardKey.keyV,
        () => _setVolume(video, video.volumeLevel * 100));
    bind(LogicalKeyboardKey.minus, () => _adjustVolume(video, -5));
    bind(LogicalKeyboardKey.keyM, () => _setVolume(video, 0));
    bind(LogicalKeyboardKey.equal, () => _adjustVolume(video, 5));
    bind(LogicalKeyboardKey.keyD, () => _setVolume(video, 100));

    bind(LogicalKeyboardKey.keyA, () => _adjustPitch(video, -1));
    bind(LogicalKeyboardKey.keyS, () => _adjustPitch(video, 1));
    bind(LogicalKeyboardKey.keyZ, () => _setPitch(video, 0));
    bind(LogicalKeyboardKey.keyT, () => _adjustSpeed(video, -0.1));
    bind(LogicalKeyboardKey.keyY, () => _adjustSpeed(video, 0.1));
    bind(LogicalKeyboardKey.keyU, () => _setSpeed(video, 1.0));
    bind(LogicalKeyboardKey.keyI,
        () => _saveVideo(video.copyWith(trimStartMs: 0, trimEndMs: 0)));
    bind(LogicalKeyboardKey.keyK, _manageSkips);
    bind(LogicalKeyboardKey.keyL, _addChapterAtCurrentPosition);
    bind(LogicalKeyboardKey.keyG,
        () => _saveVideo(video.copyWith(autoPlayNext: !video.autoPlayNext)));
    bind(LogicalKeyboardKey.keyH,
        () => _saveVideo(video.copyWith(loopPlayback: !video.loopPlayback)));
    bind(
        LogicalKeyboardKey.keyJ,
        () => _saveVideo(
            video.copyWith(shufflePlaylist: !video.shufflePlaylist)));
    bind(LogicalKeyboardKey.keyQ, () async {
      final pos = _svc?.player.state.position.inMilliseconds ?? 0;
      final result = await showAddSkipDialog(context,
          initialStartMs: pos, initialEndMs: pos + 10000);
      if (result == null) return;
      await repoOf(context)
          .addSkip(widget.videoId, result.$1, result.$2, label: result.$3);
      _reloadChaptersAndSkips();
    });
    bind(LogicalKeyboardKey.keyO, () async {
      await repoOf(context).setFavorite(video.id, !video.favorite);
      _saveVideo(video.copyWith(favorite: !video.favorite));
    });
    bind(LogicalKeyboardKey.keyR, () => _resetVideo(video), shift: true);
    bindShift(LogicalKeyboardKey.keyV, () => _setVolume(video, 50));
    bindShift(LogicalKeyboardKey.keyP, () => _setPitch(video, 0));
    bindShift(LogicalKeyboardKey.keyS, () => _setSpeed(video, 1.0));
    bindShift(LogicalKeyboardKey.keyT,
        () => _saveVideo(video.copyWith(trimStartMs: 0)));
    bindShift(LogicalKeyboardKey.keyE,
        () => _saveVideo(video.copyWith(trimEndMs: 0)));
    bindShift(LogicalKeyboardKey.keyA, () => _openEnhancementMenu(video));
    bindShift(LogicalKeyboardKey.keyD, _manageSkips);
    bindShift(LogicalKeyboardKey.keyG,
        () => _saveVideo(video.copyWith(shufflePlaylist: false)));
    bindShift(LogicalKeyboardKey.keyH,
        () => _saveVideo(video.copyWith(shufflePlaylist: true)));
    bindShift(LogicalKeyboardKey.keyO,
        () => _saveVideo(video.copyWith(autoPlayNext: true)));
    bindShift(LogicalKeyboardKey.keyL,
        () => _saveVideo(video.copyWith(loopPlayback: false)));
    bindShift(LogicalKeyboardKey.keyM,
        () => _saveVideo(video.copyWith(loopPlayback: true)));

    return shortcuts;
  }

  Future<void> _resetVideo(VideoEntity video) => _saveVideo(VideoEntity(
        id: video.id,
        uriString: video.uriString,
        sourceUriString: video.sourceUriString,
        title: video.title,
        folderGroup: video.folderGroup,
        durationMs: video.durationMs,
        sizeBytes: video.sizeBytes,
      ));

  void _openEnhancementMenu(VideoEntity video) {
    final nextIndex = (EnhancementMode.values.indexOf(video.enhancement) + 1) %
        EnhancementMode.values.length;
    _saveVideo(video.copyWith(enhancement: EnhancementMode.values[nextIndex]));
  }

  /// Fixed-width scrollable control panel beside the video — desktop
  /// layout, as opposed to the phone app's video-on-top / cards-below
  /// single scrolling column.
  Widget _buildSidePanel(VideoEntity video) {
    return Container(
      width: 400,
      decoration: const BoxDecoration(
        color: CrowColors.surface,
        border: Border(left: BorderSide(color: CrowColors.divider)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: CrowColors.onBg,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildTransportCard(video),
            const SizedBox(height: 10),
            _buildVolumeCard(video),
            const SizedBox(height: 10),
            _buildPitchCard(video),
            const SizedBox(height: 10),
            _buildSpeedCard(video),
            const SizedBox(height: 10),
            _buildTrimCard(video),
            const SizedBox(height: 10),
            _buildSkipsCard(video),
            const SizedBox(height: 10),
            _buildChaptersCard(video),
            const SizedBox(height: 10),
            _buildEnhancementCard(video),
            const SizedBox(height: 10),
            _buildPlaybackOptionsCard(video),
            const SizedBox(height: 10),
            _buildActionsCard(video),
          ],
        ),
      ),
    );
  }

  // ── Video surface + overlay ──────────────────────────────────────────

  Widget _buildVideoSurface(VideoEntity video) {
    final svc = context.watch<PlaybackService>();

    return FocusScope(
      autofocus: true,
      child: Focus(
        focusNode: _playerFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          return _VideoPlayerShortcuts.handleKeyEvent(
            event,
            svc,
            video,
            onFullscreen: () => setState(() => _fullscreen = !_fullscreen),
            onAddChapter: _addChapterAtCurrentPosition,
            onAddSkip: () async {
              final pos = svc.player.state.position.inMilliseconds;
              final result = await showAddSkipDialog(context,
                  initialStartMs: pos, initialEndMs: pos + 10000);
              if (result == null) return;
              await repoOf(context).addSkip(
                  widget.videoId, result.$1, result.$2,
                  label: result.$3);
              _reloadChaptersAndSkips();
            },
            onNextChapter: _seekToNextChapter,
            onPreviousChapter: _seekToPreviousChapter,
            onExit: () => Navigator.of(context).maybePop(),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: CrowColors.pureBlack,
              child: Video(
                  controller: _controller,
                  fit: video.cropMode.boxFit,
                  controls: NoVideoControls),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  FocusableIconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                      semanticsLabel: 'Back to library'),
                  const Spacer(),
                  FocusableIconButton(
                      icon: const Icon(Icons.bookmark_add_outlined),
                      onPressed: () => _addChapterAtCurrentPosition(),
                      tooltip: 'Add chapter',
                      semanticsLabel: 'Add chapter at current position'),
                  FocusableIconButton(
                    icon: Icon(_fullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded),
                    onPressed: () => setState(() => _fullscreen = !_fullscreen),
                    tooltip:
                        _fullscreen ? 'Exit fullscreen' : 'Enter fullscreen',
                    semanticsLabel:
                        _fullscreen ? 'Exit fullscreen' : 'Enter fullscreen',
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildSeekOverlay(video),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekOverlay(VideoEntity video) {
    final svc = context.watch<PlaybackService>();
    final pos = svc.player.state.position.inMilliseconds;
    final dur = svc.player.state.duration.inMilliseconds;
    final end = video.trimEndMs > 0 ? video.trimEndMs : dur;
    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          Text(FormatUtils.formatDuration(pos),
              style: const TextStyle(color: Colors.white, fontSize: 11)),
          Expanded(
            child: FocusableSlider(
              value: pos.clamp(0, max(dur, 1)).toDouble(),
              min: 0,
              max: max(dur, 1).toDouble(),
              onChanged: (v) => svc.seekTo(v.toInt()),
              onKeyEvent: _handlePlayerSliderKeyEvent,
              semanticsLabel: 'Playback position',
              semanticsValue: FormatUtils.formatDuration(pos),
            ),
          ),
          Text(FormatUtils.formatDuration(end > 0 ? end : dur),
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  KeyEventResult _handlePlayerSliderKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isControl = HardwareKeyboard.instance.isControlPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    var seekMs = 0;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      seekMs = isControl
          ? -30000
          : isShift
              ? -100
              : isAlt
                  ? -5000
                  : -10000;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      seekMs = isControl
          ? 30000
          : isShift
              ? 100
              : isAlt
                  ? 5000
                  : 10000;
    } else {
      return KeyEventResult.ignored;
    }

    context.read<PlaybackService>().seekRelative(seekMs);
    return KeyEventResult.handled;
  }

  Future<void> _addChapterAtCurrentPosition() async {
    final svc = context.read<PlaybackService>();
    final posMs = svc.player.state.position.inMilliseconds;
    final label = await showAddChapterDialog(context, posMs);
    if (label == null) return;
    await repoOf(context).addChapter(widget.videoId, posMs, label);
    _reloadChaptersAndSkips();
  }

  void _seekToNextChapter() {
    final svc = context.read<PlaybackService>();
    final pos = svc.player.state.position.inMilliseconds;
    final nextChapters = _chapters.where((c) => c.positionMs > pos).toList();
    if (nextChapters.isNotEmpty) {
      nextChapters.sort((a, b) => a.positionMs.compareTo(b.positionMs));
      svc.seekTo(nextChapters.first.positionMs);
    }
  }

  void _seekToPreviousChapter() {
    final svc = context.read<PlaybackService>();
    final pos = svc.player.state.position.inMilliseconds;
    final prevChapters = _chapters.where((c) => c.positionMs < pos).toList();
    if (prevChapters.isNotEmpty) {
      prevChapters.sort((a, b) => b.positionMs.compareTo(a.positionMs));
      svc.seekTo(prevChapters.first.positionMs);
    } else if (_chapters.isNotEmpty) {
      // Wrap to last chapter
      _chapters.sort((a, b) => b.positionMs.compareTo(a.positionMs));
      svc.seekTo(_chapters.first.positionMs);
    }
  }

  // ── Transport / seek card ────────────────────────────────────────────

  Widget _buildTransportCard(VideoEntity video) {
    final svc = context.watch<PlaybackService>();
    final playing = svc.player.state.playing;
    return _Card(
      accent: CrowColors.accentRed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FocusableIconButton(
              icon: const Icon(Icons.replay_rounded),
              onPressed: svc.restart,
              tooltip: 'Restart',
              semanticsLabel: 'Restart video'),
          FocusableIconButton(
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: svc.playPrevious,
              tooltip: 'Previous',
              semanticsLabel: 'Previous video'),
          FocusableIconButton(
              icon: const Icon(Icons.replay_10_rounded),
              onPressed: () => svc.seekRelative(-video.seekJumpSec * 1000),
              tooltip: 'Rewind',
              semanticsLabel: 'Rewind ${video.seekJumpSec} seconds'),
          FocusableIconButton(
            icon: Icon(playing
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_filled_rounded),
            tooltip: playing ? 'Pause' : 'Play',
            size: 46,
            color: CrowColors.accentRed,
            onPressed: svc.togglePlayPause,
            semanticsLabel: playing ? 'Pause' : 'Play',
          ),
          FocusableIconButton(
              icon: const Icon(Icons.forward_10_rounded),
              onPressed: () => svc.seekRelative(video.seekJumpSec * 1000),
              tooltip: 'Forward',
              semanticsLabel: 'Forward ${video.seekJumpSec} seconds'),
          FocusableIconButton(
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: svc.playNext,
              tooltip: 'Next',
              semanticsLabel: 'Next video'),
          FocusableIconButton(
              icon: const Icon(Icons.stop_rounded),
              onPressed: () => svc.close(),
              tooltip: 'Stop',
              semanticsLabel: 'Stop playback'),
        ],
      ),
    );
  }

  // ── Volume card ──────────────────────────────────────────────────────

  Widget _buildVolumeCard(VideoEntity video) {
    return _Card(
      accent: CrowColors.accentCyan,
      title: 'Volume',
      valueLabel: '${(video.volumeLevel * 100).round()}%',
      child: Column(
        children: [
          FocusableSlider(
            value: (video.volumeLevel * 100).clamp(0, 100),
            min: 0,
            max: 100,
            onChanged: (v) => _setVolume(video, v),
            onKeyEvent: _handlePlayerSliderKeyEvent,
            semanticsLabel: 'Volume',
            semanticsValue: '${(video.volumeLevel * 100).round()}%',
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FocusableIconButton(
                  icon: const Icon(Icons.remove_rounded),
                  onPressed: () => _adjustVolume(video, -5),
                  tooltip: 'Decrease volume',
                  semanticsLabel: 'Decrease volume by 5%'),
              FocusableIconButton(
                  icon: const Icon(Icons.volume_off_rounded),
                  onPressed: () => _setVolume(video, 0),
                  tooltip: 'Mute',
                  semanticsLabel: 'Mute'),
              FocusableIconButton(
                  icon: const Icon(Icons.restart_alt_rounded),
                  onPressed: () => _setVolume(video, 100),
                  tooltip: 'Max volume',
                  semanticsLabel: 'Set volume to 100%'),
              FocusableIconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _adjustVolume(video, 5),
                  tooltip: 'Increase volume',
                  semanticsLabel: 'Increase volume by 5%'),
            ],
          ),
        ],
      ),
    );
  }

  void _adjustVolume(VideoEntity video, int deltaPercent) {
    final next = ((video.volumeLevel * 100) + deltaPercent).clamp(0, 100);
    _setVolume(video, next.toDouble());
  }

  void _setVolume(VideoEntity video, double percent) {
    final svc = context.read<PlaybackService>();
    svc.player.setVolume(percent);
    _saveVideo(video.copyWith(volumeLevel: percent / 100));
  }

  // ── Pitch card ───────────────────────────────────────────────────────

  Widget _buildPitchCard(VideoEntity video) {
    return _Card(
      accent: CrowColors.accentGreen,
      title: 'Pitch',
      valueLabel:
          '${video.pitchSemitones > 0 ? '+' : ''}${video.pitchSemitones} st',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FocusableIconButton(
              icon: const Icon(Icons.remove_rounded),
              onPressed: () => _adjustPitch(video, -1),
              tooltip: 'Decrease pitch',
              semanticsLabel: 'Decrease pitch by 1 semitone'),
          Expanded(
            child: FocusableSlider(
              value: video.pitchSemitones.clamp(-12, 12).toDouble(),
              min: -12,
              max: 12,
              divisions: 24,
              onChanged: (v) => _setPitch(video, v.round()),
              onKeyEvent: _handlePlayerSliderKeyEvent,
              semanticsLabel: 'Pitch',
              semanticsValue:
                  '${video.pitchSemitones > 0 ? '+' : ''}${video.pitchSemitones} st',
            ),
          ),
          FocusableIconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _adjustPitch(video, 1),
              tooltip: 'Increase pitch',
              semanticsLabel: 'Increase pitch by 1 semitone'),
          FocusableIconButton(
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: () => _setPitch(video, 0),
              tooltip: 'Reset pitch',
              semanticsLabel: 'Reset pitch to 0'),
        ],
      ),
    );
  }

  // ── Speed card ───────────────────────────────────────────────────────

  Widget _buildSpeedCard(VideoEntity video) {
    return _Card(
      accent: CrowColors.accentOrange,
      title: 'Speed',
      valueLabel: '${video.playbackSpeed.toStringAsFixed(2)}x',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FocusableIconButton(
              icon: const Icon(Icons.remove_rounded),
              onPressed: () => _adjustSpeed(video, -0.1),
              tooltip: 'Decrease speed',
              semanticsLabel: 'Decrease speed by 0.1x'),
          Expanded(
            child: FocusableSlider(
              value: video.playbackSpeed.clamp(0.25, 3.0),
              min: 0.25,
              max: 3.0,
              onChanged: (v) => _setSpeed(video, v),
              onKeyEvent: _handlePlayerSliderKeyEvent,
              semanticsLabel: 'Playback speed',
              semanticsValue: '${video.playbackSpeed.toStringAsFixed(2)}x',
            ),
          ),
          FocusableIconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _adjustSpeed(video, 0.1),
              tooltip: 'Increase speed',
              semanticsLabel: 'Increase speed by 0.1x'),
          FocusableIconButton(
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: () => _setSpeed(video, 1.0),
              tooltip: 'Reset speed',
              semanticsLabel: 'Reset speed to 1.0x'),
        ],
      ),
    );
  }

  // ── Trim card ────────────────────────────────────────────────────────

  Widget _buildTrimCard(VideoEntity video) {
    final svc = context.watch<PlaybackService>();
    final dur = svc.player.state.duration.inMilliseconds > 0
        ? svc.player.state.duration.inMilliseconds
        : video.durationMs;
    final end = video.trimEndMs > 0 ? video.trimEndMs : dur;
    return _Card(
      accent: CrowColors.accentOrange,
      title: 'Trim',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Start: ${FormatUtils.formatDuration(video.trimStartMs)}',
              style: const TextStyle(color: CrowColors.onMuted, fontSize: 12)),
          FocusableSlider(
            value: video.trimStartMs.clamp(0, max(dur, 1)).toDouble(),
            min: 0,
            max: max(dur, 1).toDouble(),
            onChanged: (v) => _saveVideo(
                video.copyWith(trimStartMs: min(v.toInt(), end - 1000))),
            onKeyEvent: _handlePlayerSliderKeyEvent,
            semanticsLabel: 'Trim start',
            semanticsValue: FormatUtils.formatDuration(video.trimStartMs),
          ),
          Text('End: ${FormatUtils.formatDuration(end)}',
              style: const TextStyle(color: CrowColors.onMuted, fontSize: 12)),
          FocusableSlider(
            value: end.clamp(0, max(dur, 1)).toDouble(),
            min: 0,
            max: max(dur, 1).toDouble(),
            onChanged: (v) => _saveVideo(video.copyWith(
                trimEndMs: max(v.toInt(), video.trimStartMs + 1000))),
            onKeyEvent: _handlePlayerSliderKeyEvent,
            semanticsLabel: 'Trim end',
            semanticsValue: FormatUtils.formatDuration(end),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FocusableInkWell(
              onTap: () =>
                  _saveVideo(video.copyWith(trimStartMs: 0, trimEndMs: 0)),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restart_alt_rounded,
                      size: 16, color: CrowColors.accentOrange),
                  const SizedBox(width: 4),
                  Text('Reset trim',
                      style: TextStyle(color: CrowColors.accentOrange)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Timeline skips card ─────────────────────────────────────────────

  Widget _buildSkipsCard(VideoEntity video) {
    final svc = context.read<PlaybackService>();
    return _Card(
      accent: CrowColors.accentPink,
      title: 'Timeline Skips',
      valueLabel: '${_skips.length}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _skips.isEmpty
                ? 'No skip segments defined.'
                : _skips
                    .map((s) =>
                        '${s.label}: ${FormatUtils.formatDuration(s.startMs)}\u2013${FormatUtils.formatDuration(s.endMs)}')
                    .join('\n'),
            style: const TextStyle(color: CrowColors.onMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: CrowColors.accentPink,
                      side: const BorderSide(color: CrowColors.accentPink)),
                  onPressed: () async {
                    final pos = svc.player.state.position.inMilliseconds;
                    final result = await showAddSkipDialog(context,
                        initialStartMs: pos, initialEndMs: pos + 10000);
                    if (result == null) return;
                    await repoOf(context).addSkip(
                        widget.videoId, result.$1, result.$2,
                        label: result.$3);
                    _reloadChaptersAndSkips();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add skip'),
                ),
              ),
              const SizedBox(width: 8),
              if (_skips.isNotEmpty)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: CrowColors.onMuted,
                      side: const BorderSide(color: CrowColors.divider)),
                  onPressed: () => _manageSkips(),
                  child: const Text('Manage'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _manageSkips() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: CrowColors.surfaceElevated,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: _skips
            .map((s) => ListTile(
                  title: Text(s.label,
                      style: const TextStyle(color: CrowColors.onBg)),
                  subtitle: Text(
                      '${FormatUtils.formatDuration(s.startMs)} \u2013 ${FormatUtils.formatDuration(s.endMs)}',
                      style: const TextStyle(color: CrowColors.onMuted)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: CrowColors.accentRed),
                    onPressed: () async {
                      await repoOf(context).deleteSkip(s.id);
                      Navigator.pop(ctx);
                      _reloadChaptersAndSkips();
                    },
                  ),
                ))
            .toList(),
      ),
    );
  }

// ── Chapters card ────────────────────────────────────────────────────

  Widget _buildChaptersCard(VideoEntity video) {
    final svc = context.read<PlaybackService>();
    return _Card(
      accent: CrowColors.accentBlue,
      title: 'Chapters',
      valueLabel: '${_chapters.length}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_chapters.isEmpty)
            const Text('No chapters yet.',
                style: TextStyle(color: CrowColors.onMuted, fontSize: 12))
          else
            ..._chapters.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: FocusableInkWell(
                    onTap: () => svc.seekTo(c.positionMs),
                    borderRadius: BorderRadius.circular(8),
                    semanticsLabel:
                        'Chapter: ${c.label} at ${FormatUtils.formatDuration(c.positionMs)}',
                    child: Row(
                      children: [
                        const Icon(Icons.bookmark_rounded,
                            size: 16, color: CrowColors.accentBlue),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(c.label,
                                style: const TextStyle(
                                    color: CrowColors.onBg, fontSize: 13))),
                        Text(FormatUtils.formatDuration(c.positionMs),
                            style: const TextStyle(
                                color: CrowColors.onMuted, fontSize: 12)),
                        FocusableIconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 16, color: CrowColors.onMuted),
                          onPressed: () async {
                            await repoOf(context).deleteChapter(c.id);
                            _reloadChaptersAndSkips();
                          },
                          tooltip: 'Delete chapter',
                          semanticsLabel: 'Delete chapter ${c.label}',
                          padding: const EdgeInsets.all(8),
                        ),
                      ],
                    ),
                  ),
                )),
          Align(
            alignment: Alignment.centerRight,
            child: FocusableInkWell(
              onTap: _addChapterAtCurrentPosition,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded,
                      size: 16, color: CrowColors.accentBlue),
                  const SizedBox(width: 4),
                  Text('Add chapter here',
                      style: TextStyle(color: CrowColors.accentBlue)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Enhancement card ─────────────────────────────────────────────────

  Widget _buildEnhancementCard(VideoEntity video) {
    return _Card(
      accent: CrowColors.accentPurple,
      title: 'Visual Enhancement',
      child: DropdownButtonFormField<EnhancementMode>(
        initialValue: video.enhancement,
        dropdownColor: CrowColors.surfaceElevated,
        style: const TextStyle(color: CrowColors.onBg),
        decoration: const InputDecoration(border: OutlineInputBorder()),
        items: EnhancementMode.values
            .map((m) => DropdownMenuItem(value: m, child: Text(m.displayName)))
            .toList(),
        onChanged: (m) {
          if (m == null) return;
          _saveVideo(video.copyWith(enhancement: m));
        },
      ),
    );
  }

  // ── Playback options card ────────────────────────────────────────────

  Widget _buildPlaybackOptionsCard(VideoEntity video) {
    return _Card(
      accent: CrowColors.accentYellow,
      title: 'Playback Options',
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-play next',
                style: TextStyle(color: CrowColors.onBg)),
            value: video.autoPlayNext,
            onChanged: (v) => _saveVideo(video.copyWith(autoPlayNext: v)),
          ),
          if (video.autoPlayNext)
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sequential',
                        style: TextStyle(color: CrowColors.onBg, fontSize: 13)),
                    value: false,
                    groupValue: video.shufflePlaylist,
                    onChanged: (v) =>
                        _saveVideo(video.copyWith(shufflePlaylist: v!)),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Random',
                        style: TextStyle(color: CrowColors.onBg, fontSize: 13)),
                    value: true,
                    groupValue: video.shufflePlaylist,
                    onChanged: (v) =>
                        _saveVideo(video.copyWith(shufflePlaylist: v!)),
                  ),
                ),
              ],
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Loop this video',
                style: TextStyle(color: CrowColors.onBg)),
            value: video.loopPlayback,
            onChanged: (v) => _saveVideo(video.copyWith(loopPlayback: v)),
          ),
        ],
      ),
    );
  }

  // ── Actions card ─────────────────────────────────────────────────────

  Widget _buildActionsCard(VideoEntity video) {
    return _Card(
      accent: CrowColors.onMuted,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: video.favorite
                    ? CrowColors.accentYellow
                    : CrowColors.onMuted,
                side: BorderSide(
                    color: video.favorite
                        ? CrowColors.accentYellow
                        : CrowColors.divider),
              ),
              onPressed: () async {
                await repoOf(context).setFavorite(video.id, !video.favorite);
                _saveVideo(video.copyWith(favorite: !video.favorite));
              },
              icon: Icon(video.favorite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded),
              label: Text(video.favorite ? 'Favorited' : 'Favorite'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: CrowColors.accentRed,
                  side: const BorderSide(color: CrowColors.accentRed)),
              onPressed: () => _saveVideo(VideoEntity(
                id: video.id,
                uriString: video.uriString,
                sourceUriString: video.sourceUriString,
                title: video.title,
                folderGroup: video.folderGroup,
                durationMs: video.durationMs,
                sizeBytes: video.sizeBytes,
              )),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reset all'),
            ),
          ),
        ],
      ),
    );
  }

  void _adjustPitch(VideoEntity video, int delta) =>
      _setPitch(video, (video.pitchSemitones + delta).clamp(-12, 12));

  void _setPitch(VideoEntity video, int semitones) {
    final svc = context.read<PlaybackService>();
    svc.player.setPitch(pow(2, semitones / 12).toDouble());
    _saveVideo(video.copyWith(pitchSemitones: semitones));
  }

  void _adjustSpeed(VideoEntity video, double delta) =>
      _setSpeed(video, (video.playbackSpeed + delta).clamp(0.25, 3.0));

  void _setSpeed(VideoEntity video, double speed) {
    final svc = context.read<PlaybackService>();
    svc.player.setRate(speed);
    _saveVideo(video.copyWith(playbackSpeed: speed));
  }
}

// ── Small shared widgets ───────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card(
      {required this.child,
      this.title,
      this.valueLabel,
      this.accent = CrowColors.accentCyan});
  final Widget child;
  final String? title;
  final String? valueLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CrowColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title!,
                        style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.6)),
                  ),
                  if (valueLabel != null)
                    Text(valueLabel!,
                        style: TextStyle(
                            color: accent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}
