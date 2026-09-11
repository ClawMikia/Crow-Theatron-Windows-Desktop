import 'dart:math';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final svc = context.read<PlaybackService>();
    _svc = svc;
    svc.setPlayerScreenVisible(true);
    final repo = repoOf(context);
    final video = await repo.getById(widget.videoId);
    if (video == null || !mounted) return;
    setState(() => _video = video);
    _controller = VideoController(svc.player);
    if (svc.currentVideo?.id != video.id) {
      await svc.play(video, siblings: widget.siblingQueue);
    }
    await _reloadChaptersAndSkips();
  }

  Future<void> _reloadChaptersAndSkips() async {
    final repo = repoOf(context);
    final chapters = await repo.listChapters(widget.videoId);
    final skips = await repo.listSkips(widget.videoId);
    if (mounted) setState(() { _chapters = chapters; _skips = skips; });
  }

  @override
  void dispose() {
    _svc?.setPlayerScreenVisible(false);
    super.dispose();
  }

  Future<void> _saveVideo(VideoEntity updated) async {
    setState(() => _video = updated);
    await repoOf(context).savePreferences(updated);
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
        body: Center(child: CircularProgressIndicator(color: CrowColors.accentYellow)),
      );
    }
    return Scaffold(
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
    );
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
                style: const TextStyle(color: CrowColors.onBg, fontSize: 16, fontWeight: FontWeight.bold)),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: CrowColors.pureBlack,
          child: Video(controller: _controller, fit: video.cropMode.boxFit, controls: NoVideoControls),
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Row(
            children: [
              _OverlayIconBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
              const Spacer(),
              _OverlayIconBtn(icon: Icons.bookmark_add_outlined, onTap: () => _addChapterAtCurrentPosition()),
              _OverlayIconBtn(
                icon: _fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                onTap: () => setState(() => _fullscreen = !_fullscreen),
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
          Text(FormatUtils.formatDuration(pos), style: const TextStyle(color: Colors.white, fontSize: 11)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 3),
              child: Slider(
                value: pos.clamp(0, max(dur, 1)).toDouble(),
                min: 0,
                max: max(dur, 1).toDouble(),
                onChanged: (v) => svc.seekTo(v.toInt()),
              ),
            ),
          ),
          Text(FormatUtils.formatDuration(end > 0 ? end : dur), style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _addChapterAtCurrentPosition() async {
    final svc = context.read<PlaybackService>();
    final posMs = svc.player.state.position.inMilliseconds;
    final label = await showAddChapterDialog(context, posMs);
    if (label == null) return;
    await repoOf(context).addChapter(widget.videoId, posMs, label);
    _reloadChaptersAndSkips();
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
          _TransportBtn(icon: Icons.replay_rounded, tooltip: 'Restart', onTap: svc.restart),
          _TransportBtn(icon: Icons.skip_previous_rounded, tooltip: 'Previous', onTap: svc.playPrevious),
          _TransportBtn(icon: Icons.replay_10_rounded, tooltip: 'Rewind', onTap: () => svc.seekRelative(-video.seekJumpSec * 1000)),
          _TransportBtn(
            icon: playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
            tooltip: playing ? 'Pause' : 'Play',
            size: 46,
            color: CrowColors.accentRed,
            onTap: svc.togglePlayPause,
          ),
          _TransportBtn(icon: Icons.forward_10_rounded, tooltip: 'Forward', onTap: () => svc.seekRelative(video.seekJumpSec * 1000)),
          _TransportBtn(icon: Icons.skip_next_rounded, tooltip: 'Next', onTap: svc.playNext),
          _TransportBtn(icon: Icons.stop_rounded, tooltip: 'Stop', onTap: () => svc.close()),
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
          Slider(
            value: (video.volumeLevel * 100).clamp(0, 100),
            min: 0,
            max: 100,
            onChanged: (v) => _setVolume(video, v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepBtn(icon: Icons.remove_rounded, onTap: () => _adjustVolume(video, -5)),
              _StepBtn(icon: Icons.volume_off_rounded, onTap: () => _setVolume(video, 0)),
              _StepBtn(icon: Icons.restart_alt_rounded, onTap: () => _setVolume(video, 100)),
              _StepBtn(icon: Icons.add_rounded, onTap: () => _adjustVolume(video, 5)),
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
      valueLabel: '${video.pitchSemitones > 0 ? '+' : ''}${video.pitchSemitones} st',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepBtn(icon: Icons.remove_rounded, onTap: () => _adjustPitch(video, -1)),
          Expanded(
            child: Slider(
              value: video.pitchSemitones.clamp(-12, 12).toDouble(),
              min: -12,
              max: 12,
              divisions: 24,
              onChanged: (v) => _setPitch(video, v.round()),
            ),
          ),
          _StepBtn(icon: Icons.add_rounded, onTap: () => _adjustPitch(video, 1)),
          _StepBtn(icon: Icons.restart_alt_rounded, onTap: () => _setPitch(video, 0)),
        ],
      ),
    );
  }

  void _adjustPitch(VideoEntity video, int delta) => _setPitch(video, (video.pitchSemitones + delta).clamp(-12, 12));

  void _setPitch(VideoEntity video, int semitones) {
    final svc = context.read<PlaybackService>();
    svc.player.setPitch(pow(2, semitones / 12).toDouble());
    _saveVideo(video.copyWith(pitchSemitones: semitones));
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
          _StepBtn(icon: Icons.remove_rounded, onTap: () => _adjustSpeed(video, -0.1)),
          Expanded(
            child: Slider(
              value: video.playbackSpeed.clamp(0.25, 3.0),
              min: 0.25,
              max: 3.0,
              onChanged: (v) => _setSpeed(video, v),
            ),
          ),
          _StepBtn(icon: Icons.add_rounded, onTap: () => _adjustSpeed(video, 0.1)),
          _StepBtn(icon: Icons.restart_alt_rounded, onTap: () => _setSpeed(video, 1.0)),
        ],
      ),
    );
  }

  void _adjustSpeed(VideoEntity video, double delta) => _setSpeed(video, (video.playbackSpeed + delta).clamp(0.25, 3.0));

  void _setSpeed(VideoEntity video, double speed) {
    final svc = context.read<PlaybackService>();
    svc.player.setRate(speed);
    _saveVideo(video.copyWith(playbackSpeed: speed));
  }

  // ── Trim card ────────────────────────────────────────────────────────

  Widget _buildTrimCard(VideoEntity video) {
    final svc = context.watch<PlaybackService>();
    final dur = svc.player.state.duration.inMilliseconds > 0 ? svc.player.state.duration.inMilliseconds : video.durationMs;
    final end = video.trimEndMs > 0 ? video.trimEndMs : dur;
    return _Card(
      accent: CrowColors.accentOrange,
      title: 'Trim',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Start: ${FormatUtils.formatDuration(video.trimStartMs)}', style: const TextStyle(color: CrowColors.onMuted, fontSize: 12)),
          Slider(
            value: video.trimStartMs.clamp(0, max(dur, 1)).toDouble(),
            min: 0,
            max: max(dur, 1).toDouble(),
            onChanged: (v) => _saveVideo(video.copyWith(trimStartMs: min(v.toInt(), end - 1000))),
          ),
          Text('End: ${FormatUtils.formatDuration(end)}', style: const TextStyle(color: CrowColors.onMuted, fontSize: 12)),
          Slider(
            value: end.clamp(0, max(dur, 1)).toDouble(),
            min: 0,
            max: max(dur, 1).toDouble(),
            onChanged: (v) => _saveVideo(video.copyWith(trimEndMs: max(v.toInt(), video.trimStartMs + 1000))),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _saveVideo(video.copyWith(trimStartMs: 0, trimEndMs: 0)),
              icon: const Icon(Icons.restart_alt_rounded, size: 16, color: CrowColors.accentOrange),
              label: const Text('Reset trim', style: TextStyle(color: CrowColors.accentOrange)),
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
                : _skips.map((s) => '${s.label}: ${FormatUtils.formatDuration(s.startMs)}\u2013${FormatUtils.formatDuration(s.endMs)}').join('\n'),
            style: const TextStyle(color: CrowColors.onMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: CrowColors.accentPink, side: const BorderSide(color: CrowColors.accentPink)),
                  onPressed: () async {
                    final pos = svc.player.state.position.inMilliseconds;
                    final result = await showAddSkipDialog(context, initialStartMs: pos, initialEndMs: pos + 10000);
                    if (result == null) return;
                    await repoOf(context).addSkip(widget.videoId, result.$1, result.$2, label: result.$3);
                    _reloadChaptersAndSkips();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add skip'),
                ),
              ),
              const SizedBox(width: 8),
              if (_skips.isNotEmpty)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: CrowColors.onMuted, side: const BorderSide(color: CrowColors.divider)),
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
                  title: Text(s.label, style: const TextStyle(color: CrowColors.onBg)),
                  subtitle: Text('${FormatUtils.formatDuration(s.startMs)} \u2013 ${FormatUtils.formatDuration(s.endMs)}',
                      style: const TextStyle(color: CrowColors.onMuted)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: CrowColors.accentRed),
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
            const Text('No chapters yet.', style: TextStyle(color: CrowColors.onMuted, fontSize: 12))
          else
            ..._chapters.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: InkWell(
                    onTap: () => svc.seekTo(c.positionMs),
                    child: Row(
                      children: [
                        const Icon(Icons.bookmark_rounded, size: 16, color: CrowColors.accentBlue),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.label, style: const TextStyle(color: CrowColors.onBg, fontSize: 13))),
                        Text(FormatUtils.formatDuration(c.positionMs), style: const TextStyle(color: CrowColors.onMuted, fontSize: 12)),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: CrowColors.onMuted),
                          onPressed: () async {
                            await repoOf(context).deleteChapter(c.id);
                            _reloadChaptersAndSkips();
                          },
                        ),
                      ],
                    ),
                  ),
                )),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _addChapterAtCurrentPosition,
              icon: const Icon(Icons.add_rounded, size: 16, color: CrowColors.accentBlue),
              label: const Text('Add chapter here', style: TextStyle(color: CrowColors.accentBlue)),
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
        items: EnhancementMode.values.map((m) => DropdownMenuItem(value: m, child: Text(m.displayName))).toList(),
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
            title: const Text('Auto-play next', style: TextStyle(color: CrowColors.onBg)),
            value: video.autoPlayNext,
            onChanged: (v) => _saveVideo(video.copyWith(autoPlayNext: v)),
          ),
          if (video.autoPlayNext)
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sequential', style: TextStyle(color: CrowColors.onBg, fontSize: 13)),
                    value: false,
                    groupValue: video.shufflePlaylist,
                    onChanged: (v) => _saveVideo(video.copyWith(shufflePlaylist: v!)),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Random', style: TextStyle(color: CrowColors.onBg, fontSize: 13)),
                    value: true,
                    groupValue: video.shufflePlaylist,
                    onChanged: (v) => _saveVideo(video.copyWith(shufflePlaylist: v!)),
                  ),
                ),
              ],
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Loop this video', style: TextStyle(color: CrowColors.onBg)),
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
                foregroundColor: video.favorite ? CrowColors.accentYellow : CrowColors.onMuted,
                side: BorderSide(color: video.favorite ? CrowColors.accentYellow : CrowColors.divider),
              ),
              onPressed: () async {
                await repoOf(context).setFavorite(video.id, !video.favorite);
                _saveVideo(video.copyWith(favorite: !video.favorite));
              },
              icon: Icon(video.favorite ? Icons.star_rounded : Icons.star_border_rounded),
              label: Text(video.favorite ? 'Favorited' : 'Favorite'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: CrowColors.accentRed, side: const BorderSide(color: CrowColors.accentRed)),
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
}

// ── Small shared widgets ───────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child, this.title, this.valueLabel, this.accent = CrowColors.accentCyan});
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
                    child: Text(title!, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.6)),
                  ),
                  if (valueLabel != null) Text(valueLabel!, style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _TransportBtn extends StatelessWidget {
  const _TransportBtn({required this.icon, required this.onTap, this.tooltip, this.size = 30, this.color = CrowColors.onBg});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(tooltip: tooltip, iconSize: size, icon: Icon(icon, color: color), onPressed: onTap);
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18, color: CrowColors.onBg),
      onPressed: onTap,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: CrowColors.divider)),
      ),
    );
  }
}

class _OverlayIconBtn extends StatelessWidget {
  const _OverlayIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, color: Colors.white, size: 20), onPressed: onTap),
    );
  }
}
