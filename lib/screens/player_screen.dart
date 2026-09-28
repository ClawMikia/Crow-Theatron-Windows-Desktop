import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../data/app_prefs.dart';
import '../data/video_repository.dart';
import '../models/chapter_marker.dart';
import '../models/enhancement_mode.dart';
import '../models/timeline_skip.dart';
import '../models/video_entity.dart';
import '../services/playback_service.dart';
import '../shortcuts/app_shortcuts.dart';
import '../theme/crow_colors.dart';
import '../util/format_utils.dart';
import '../util/seek_icons.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/crow_title_bar.dart';
import '../widgets/player_dialogs.dart';
import 'main_screen.dart';
import '../widgets/keyboard_accessible.dart';

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

  /// The id of the video that is actually playing right now. Differs from
  /// `widget.videoId` after auto-advance / Next / Previous, so everything
  /// (chapters, skips, refresh-from-db) follows the CURRENT video.
  int get _videoId => _video?.id ?? widget.videoId;

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
    final updated = await _repo!.getById(_videoId);
    if (updated != null && mounted && updated != _video) {
      setState(() => _video = updated);
    }
  }

  Future<void> _reloadChaptersAndSkips() async {
    final chapters = await _repo!.listChapters(_videoId);
    final skips = await _repo!.listSkips(_videoId);
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
    // Volume is owned by PlaybackService (its changes are saved a moment
    // after they happen) — never let an unrelated edit write back a stale
    // volume.
    final live = _svc?.currentVideo;
    if (live != null && live.id == updated.id) {
      updated = updated.copyWith(volumeLevel: live.volumeLevel);
    }
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
    final svc = _svc;
    final shortcuts = svc == null
        ? const <AppShortcut>[]
        : [
            ...buildTransportShortcuts(svc),
            ...buildPlayerOnlyShortcuts(
              _playerShortcutCallbacks(video),
              onShowHelp: () => showShortcutsHelp(context, [
                ...buildTransportShortcuts(svc),
                ...buildPlayerOnlyShortcuts(_playerShortcutCallbacks(video), onShowHelp: () {}),
              ]),
            ),
          ];

    return AppShortcutsScope(
      shortcuts: shortcuts,
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

  /// Bundles this screen's helper methods into the shared
  /// [PlayerShortcutCallbacks] bag consumed by
  /// `shortcuts/app_shortcuts.dart`'s `buildPlayerOnlyShortcuts`. Kept
  /// as the single place that wires "what a key does" to "how the
  /// player actually does it".
  PlayerShortcutCallbacks _playerShortcutCallbacks(VideoEntity video) {
    return PlayerShortcutCallbacks(
      toggleFullscreen: () => setState(() => _fullscreen = !_fullscreen),
      exitOrBack: () {
        if (_fullscreen) {
          setState(() => _fullscreen = false);
        } else {
          Navigator.of(context).maybePop();
        }
      },
      restart: () => _svc?.restart(),
      addChapterAtCurrentPosition: _addChapterAtCurrentPosition,
      openAddSkipDialog: _openAddSkipDialogAtCurrentPosition,
      manageSkips: _manageSkips,
      nextChapter: _seekToNextChapter,
      previousChapter: _seekToPreviousChapter,
      seekToPercent: (percent) {
        final dur = _svc?.player.state.duration.inMilliseconds ?? 0;
        if (dur > 0) _svc?.seekTo((dur * percent / 100).round());
      },
      seekToStart: () => _svc?.seekTo(0),
      seekToEnd: () {
        final dur = _svc?.player.state.duration.inMilliseconds ?? 0;
        if (dur > 0) _svc?.seekTo(dur);
      },
      pitchDown: () => _adjustPitch(video, -_prefs.defaultPitchStepSemitones),
      pitchUp: () => _adjustPitch(video, _prefs.defaultPitchStepSemitones),
      resetPitch: () => _setPitch(video, 0),
      speedDown: () => _adjustSpeed(video, -_prefs.defaultSpeedStep),
      speedUp: () => _adjustSpeed(video, _prefs.defaultSpeedStep),
      resetSpeed: () => _setSpeed(video, 1.0),
      toggleAutoplay: () =>
          _saveVideo(video.copyWith(autoPlayNext: !video.autoPlayNext)),
      toggleLoop: () =>
          _saveVideo(video.copyWith(loopPlayback: !video.loopPlayback)),
      toggleShuffle: () => _saveVideo(
          video.copyWith(shufflePlaylist: !video.shufflePlaylist)),
      toggleFavorite: () async {
        await repoOf(context).setFavorite(video.id, !video.favorite);
        _saveVideo(video.copyWith(favorite: !video.favorite));
      },
    );
  }

  Future<void> _openAddSkipDialogAtCurrentPosition() async {
    final pos = _svc?.player.state.position.inMilliseconds ?? 0;
    final result = await showAddSkipDialog(context,
        initialStartMs: pos, initialEndMs: pos + 10000);
    if (result == null) return;
    await repoOf(context)
        .addSkip(_videoId, result.$1, result.$2, label: result.$3);
    _reloadChaptersAndSkips();
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
    // Every keyboard shortcut for this screen is bound once, at the
    // Scaffold root, via AppShortcutsScope in build() (see
    // shortcuts/app_shortcuts.dart) — this Focus node just gives the
    // video surface a sensible default focus target (for mouse-click
    // focusing and so the shortcuts above have *something* focused to
    // bubble key events up from) without handling keys itself.
    return FocusScope(
      autofocus: true,
      child: Focus(
        focusNode: _playerFocusNode,
        autofocus: true,
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
    await repoOf(context).addChapter(_videoId, posMs, label);
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
    final seekSec = context.watch<AppPrefs>().defaultSeekJumpSec;
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
              icon: Icon(seekIcon(seekSec, forward: false)),
              onPressed: () => svc.seekRelative(-svc.seekStepMs),
              tooltip: 'Rewind ${seekSec}s',
              semanticsLabel: 'Rewind $seekSec seconds'),
          FocusableIconButton(
            icon: Icon(playing
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_filled_rounded),
            tooltip: playing ? 'Pause' : 'Play',
            size: 46,
            color: CrowColors.accentRed,
            onPressed: () => _playPause(svc, video),
            semanticsLabel: playing ? 'Pause' : 'Play',
          ),
          FocusableIconButton(
              icon: Icon(seekIcon(seekSec, forward: true)),
              onPressed: () => svc.seekRelative(svc.seekStepMs),
              tooltip: 'Forward ${seekSec}s',
              semanticsLabel: 'Forward $seekSec seconds'),
          FocusableIconButton(
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: svc.playNext,
              tooltip: 'Next',
              semanticsLabel: 'Next video'),
          FocusableIconButton(
              icon: const Icon(Icons.stop_rounded),
              // Stop = pause + back to the start. The video stays loaded,
              // so every other button keeps working afterwards.
              onPressed: svc.stop,
              tooltip: 'Stop',
              semanticsLabel: 'Stop playback'),
        ],
      ),
    );
  }

  /// Play/Pause that also recovers if nothing is loaded in the engine.
  void _playPause(PlaybackService svc, VideoEntity video) {
    if (svc.currentVideo == null) {
      svc.play(video, siblings: widget.siblingQueue);
    } else {
      svc.togglePlayPause();
    }
  }

  AppPrefs get _prefs => context.read<AppPrefs>();

  // ── Volume card ──────────────────────────────────────────────────────

  Widget _buildVolumeCard(VideoEntity video) {
    final svc = context.watch<PlaybackService>();
    final step = context.watch<AppPrefs>().defaultVolumeStepPercent;
    final muted = svc.isMuted;
    // Show the live level (0 while muted). The level from BEFORE the mute
    // is remembered by the service, so Unmute restores exactly that.
    final volume = muted ? 0.0 : svc.player.state.volume.clamp(0, 100).toDouble();
    return _Card(
      accent: CrowColors.accentCyan,
      title: 'Volume',
      valueLabel: '${volume.round()}%',
      child: Column(
        children: [
          FocusableSlider(
            value: volume,
            min: 0,
            max: 100,
            onChanged: (v) => svc.setVolumePercent(v),
            onKeyEvent: _handlePlayerSliderKeyEvent,
            semanticsLabel: 'Volume',
            semanticsValue: '${volume.round()}%',
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FocusableIconButton(
                  icon: const Icon(Icons.remove_rounded),
                  onPressed: () => svc.adjustVolume(-step.toDouble()),
                  tooltip: 'Decrease volume',
                  semanticsLabel: 'Decrease volume by $step%'),
              FocusableIconButton(
                  icon: Icon(muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      color: muted ? CrowColors.accentRed : null),
                  onPressed: svc.toggleMute,
                  tooltip: muted ? 'Unmute' : 'Mute',
                  semanticsLabel: muted ? 'Unmute' : 'Mute'),
              FocusableIconButton(
                  icon: const Icon(Icons.restart_alt_rounded),
                  onPressed: () => svc.setVolumePercent(100),
                  tooltip: 'Max volume',
                  semanticsLabel: 'Set volume to 100%'),
              FocusableIconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => svc.adjustVolume(step.toDouble()),
                  tooltip: 'Increase volume',
                  semanticsLabel: 'Increase volume by $step%'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Pitch card ───────────────────────────────────────────────────────

  Widget _buildPitchCard(VideoEntity video) {
    final step = context.watch<AppPrefs>().defaultPitchStepSemitones;
    final label = '${video.pitchSemitones > 0 ? '+' : ''}${_fmtNum(video.pitchSemitones)} st';
    return _Card(
      accent: CrowColors.accentGreen,
      title: 'Pitch',
      valueLabel: label,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FocusableIconButton(
              icon: const Icon(Icons.remove_rounded),
              onPressed: () => _adjustPitch(video, -step),
              tooltip: 'Decrease pitch',
              semanticsLabel: 'Decrease pitch by ${_fmtNum(step)} semitone'),
          Expanded(
            child: FocusableSlider(
              value: video.pitchSemitones.clamp(-12.0, 12.0),
              min: -12,
              max: 12,
              // Snaps to the pitch step from Settings.
              divisions: (24 / step).round().clamp(1, 480),
              onChanged: (v) => _setPitch(video, v),
              onKeyEvent: _handlePlayerSliderKeyEvent,
              semanticsLabel: 'Pitch',
              semanticsValue: label,
            ),
          ),
          FocusableIconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _adjustPitch(video, step),
              tooltip: 'Increase pitch',
              semanticsLabel: 'Increase pitch by ${_fmtNum(step)} semitone'),
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
    final step = context.watch<AppPrefs>().defaultSpeedStep;
    return _Card(
      accent: CrowColors.accentOrange,
      title: 'Speed',
      valueLabel: '${video.playbackSpeed.toStringAsFixed(2)}x',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FocusableIconButton(
              icon: const Icon(Icons.remove_rounded),
              onPressed: () => _adjustSpeed(video, -step),
              tooltip: 'Decrease speed',
              semanticsLabel: 'Decrease speed by ${_fmtNum(step)}x'),
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
              onPressed: () => _adjustSpeed(video, step),
              tooltip: 'Increase speed',
              semanticsLabel: 'Increase speed by ${_fmtNum(step)}x'),
          FocusableIconButton(
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: () => _setSpeed(video, 1.0),
              tooltip: 'Reset speed',
              semanticsLabel: 'Reset speed to 1.0x'),
        ],
      ),
    );
  }

  /// 1.0 → "1", 0.5 → "0.5" (no trailing zeros).
  String _fmtNum(double v) {
    var t = v.toStringAsFixed(2);
    if (t.contains('.')) {
      t = t.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return t;
  }

  // ── Trim card ────────────────────────────────────────────────────────

  Widget _buildTrimCard(VideoEntity video) {
    final svc = context.watch<PlaybackService>();
    final dur = svc.player.state.duration.inMilliseconds > 0
        ? svc.player.state.duration.inMilliseconds
        : video.durationMs;
    final end = video.trimEndMs > 0 ? video.trimEndMs : dur;
    // The trim sliders snap to the "Trim step" from Settings.
    final trimStepMs = context.watch<AppPrefs>().defaultTrimStepMs;
    final trimDivisions = dur > 0 ? (dur / trimStepMs).round().clamp(1, 2000) : null;
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
            divisions: trimDivisions,
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
            divisions: trimDivisions,
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
                        _videoId, result.$1, result.$2,
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
                  trailing: FocusableIconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: CrowColors.accentRed),
                    tooltip: 'Delete skip',
                    semanticsLabel: 'Delete skip ${s.label}',
                    onPressed: () async {
                      final ok = await confirmDestructive(
                        context,
                        title: 'Delete skip?',
                        message: 'Delete the timeline skip "${s.label}" '
                            '(${FormatUtils.formatDuration(s.startMs)} – ${FormatUtils.formatDuration(s.endMs)})?',
                      );
                      if (!ok || !mounted) return;
                      await repoOf(context).deleteSkip(s.id);
                      if (ctx.mounted) Navigator.pop(ctx);
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
                            final ok = await confirmDestructive(
                              context,
                              title: 'Delete chapter?',
                              message: 'Delete the chapter "${c.label}" at ${FormatUtils.formatDuration(c.positionMs)}?',
                            );
                            if (!ok || !mounted) return;
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

  double _round2(double v) => (v * 100).round() / 100;

  void _adjustPitch(VideoEntity video, double delta) =>
      _setPitch(video, video.pitchSemitones + delta);

  void _setPitch(VideoEntity video, double semitones) {
    final st = _round2(semitones.clamp(-12.0, 12.0));
    final svc = context.read<PlaybackService>();
    svc.player.setPitch(pow(2, st / 12).toDouble());
    _saveVideo(video.copyWith(pitchSemitones: st));
  }

  void _adjustSpeed(VideoEntity video, double delta) =>
      _setSpeed(video, video.playbackSpeed + delta);

  void _setSpeed(VideoEntity video, double speed) {
    final sp = _round2(speed.clamp(0.25, 3.0));
    final svc = context.read<PlaybackService>();
    svc.player.setRate(sp);
    _saveVideo(video.copyWith(playbackSpeed: sp));
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
