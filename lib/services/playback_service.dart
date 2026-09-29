import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../data/app_prefs.dart';
import '../data/video_repository.dart';
import '../models/timeline_skip.dart';
import '../models/video_entity.dart';
import 'media_session/media_session_service.dart';

/// Global playback engine + state holder. Port of the combined
/// responsibilities of `service/PlaybackService.kt` and
/// `ui/MiniPlayerHelper.kt`: one libmpv-backed [Player] that both the
/// full [PlayerScreen] and the mini-player bar attach to, so playback
/// keeps going while browsing the rest of the app.
class PlaybackService extends ChangeNotifier {
  PlaybackService(this._repo) {
    _player = Player(
      configuration: const PlayerConfiguration(
        // Pitch-shifting is opt-in in media_kit (adds an audio filter
        // with a small CPU cost) — the Player screen's Pitch card
        // needs this enabled to have any effect.
        pitch: true,
      ),
    );
    _player.stream.playing.listen((playing) {
      notifyListeners();
      _mediaSession.updatePlaybackState(
        playing: playing,
        position: _player.state.position,
        duration: _player.state.duration,
      );
      if (playing) {
        _startTicker();
      } else {
        _stopTicker();
      }
    });
    _player.stream.completed.listen((completed) {
      if (completed) _onCompleted();
    });
    _player.stream.position.listen((position) {
      notifyListeners();
      _mediaSession.updatePlaybackState(
        playing: _player.state.playing,
        position: position,
        duration: _player.state.duration,
      );
      _enforceTrimAndSkips(position);
    });
    _initMediaSession();
  }

  final VideoRepository _repo;
  late final Player _player;
  Player get player => _player;

  /// User's Settings → Display & Playback values. Read live (never
  /// cached) so a change made in Settings applies to the very next
  /// action, without reopening the video.
  AppPrefs get prefs => _repo.prefs;
  int get seekStepMs => _repo.prefs.defaultSeekJumpSec * 1000;

  /// OS/browser media-control bridge (Windows SMTC / Web Media Session
  /// API) — see services/media_session/media_session_service.dart.
  /// This is the primary path for earbud/hardware Play, Pause, Next
  /// and Previous button presses; `LogicalKeyboardKey.media*` bindings
  /// in shortcuts/app_shortcuts.dart are the fallback for platforms/
  /// situations where the OS instead delivers those as ordinary key
  /// events.
  final MediaSessionService _mediaSession = MediaSessionService();
  StreamSubscription<MediaSessionAction>? _mediaSessionSub;

  Future<void> _initMediaSession() async {
    await _mediaSession.initialize();
    _mediaSessionSub = _mediaSession.actions.listen((action) {
      switch (action) {
        case MediaSessionAction.play:
        case MediaSessionAction.pause:
          togglePlayPause();
          break;
        case MediaSessionAction.next:
          playNext();
          break;
        case MediaSessionAction.previous:
          playPrevious();
          break;
        case MediaSessionAction.stop:
          stop();
          break;
        case MediaSessionAction.seekForward:
          seekRelative(10000);
          break;
        case MediaSessionAction.seekBackward:
          seekRelative(-10000);
          break;
      }
    });
  }

  /// Timeline skips for the CURRENTLY LOADED video, used to actually
  /// jump over them during normal playback (see [_enforceTrimAndSkips]).
  /// Loaded whenever a video opens; call [refreshSkips] after
  /// adding/editing/deleting one so the change takes effect without
  /// reopening the video.
  List<TimelineSkip> _skips = [];
  bool _enforcing = false;

  Future<void> refreshSkips() async {
    final v = currentVideo;
    _skips = v == null ? [] : await _repo.listSkips(v.id);
  }

  /// Makes Trim and Timeline Skips actually DO something during normal
  /// playback, not just clamp manual seeks: jumps straight past any
  /// skip segment the position enters, and treats reaching the trim end
  /// the same as reaching the real end of the file (loop / autoplay /
  /// stop, whichever the video's Playback Options say).
  void _enforceTrimAndSkips(Duration position) {
    if (_enforcing || !_player.state.playing) return;
    final v = currentVideo;
    if (v == null) return;
    final posMs = position.inMilliseconds;

    for (final skip in _skips) {
      if (posMs >= skip.startMs && posMs < skip.endMs) {
        _enforcing = true;
        _player.seek(Duration(milliseconds: skip.endMs)).whenComplete(() => _enforcing = false);
        return;
      }
    }

    final end = trimEndMs;
    if (end > 0 && v.durationMs > 0 && posMs >= end && posMs < v.durationMs - 250) {
      _enforcing = true;
      _onCompleted();
      // Give the seek/pause/next a moment to land before re-arming, so
      // one crossing doesn't fire this repeatedly on the next few ticks.
      Future.delayed(const Duration(milliseconds: 500), () => _enforcing = false);
    }
  }

  VideoEntity? _currentVideo;
  VideoEntity? get currentVideo => _currentVideo;

  set currentVideo(VideoEntity? v) {
    if (_currentVideo == v) return;
    _currentVideo = v;
    notifyListeners();
  }

  List<VideoEntity> queue = [];
  int queueIndex = -1;

  /// True while the full PlayerScreen is on top — hides the mini-player.
  bool isPlayerScreenVisible = false;

  /// Volume before muting, used for mute toggle.
  double _volumeBeforeMute = 100.0;

  /// Whether currently muted - more reliable than checking volume.
  bool _isMuted = false;

  Timer? _ticker;
  Timer? _saveTimer;

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  int get trimStartMs => currentVideo?.trimStartMs ?? 0;
  int get trimEndMs {
    final v = currentVideo;
    if (v == null) return 0;
    return v.trimEndMs > 0 ? v.trimEndMs : v.durationMs;
  }

  bool get hasActiveMedia => currentVideo != null;

  bool get hasNext => queueIndex >= 0 && queueIndex < queue.length - 1;
  bool get hasPrevious => queueIndex > 0;

  /// Loads and plays [video], replacing the current queue with [siblings]
  /// (typically all videos in the same folder) so next/prev work.
  Future<void> play(VideoEntity video, {List<VideoEntity>? siblings, VideoEntity? carryAutoPlayFrom}) async {
    // Queue entries are snapshots taken when a list was loaded — always
    // start from the freshest saved copy so speed/pitch/volume/trim edits
    // made since then aren't lost.
    video = await _repo.getById(video.id) ?? video;
    if (carryAutoPlayFrom != null) {
      // Auto-advancing keeps the chosen mode (Sequential / Random) going
      // for the rest of the queue instead of stopping after one video.
      video = video.copyWith(autoPlayNext: true, shufflePlaylist: carryAutoPlayFrom.shufflePlaylist);
    }
    currentVideo = video;
    queue = siblings ?? [video];
    queueIndex = queue.indexWhere((v) => v.id == video.id);
    if (queueIndex < 0) queueIndex = 0;

    await _player.open(Media(video.uriString), play: true);
    await _player.setRate(video.playbackSpeed);
    await _player.setPitch(_semitonesToRatio(video.pitchSemitones));
    final savedVolume = (video.volumeLevel * 100).clamp(0, 100).toDouble();
    if (savedVolume > 0) _volumeBeforeMute = savedVolume;
    // Mute is a session-level state: stays muted across tracks.
    await _player.setVolume(_isMuted ? 0 : savedVolume);
    await applyVideoFilters(video);
    _skips = await _repo.listSkips(video.id);
    if (video.positionMs > 0 && video.positionMs < video.durationMs) {
      await _player.seek(Duration(milliseconds: video.positionMs));
    } else if (video.trimStartMs > 0) {
      await _player.seek(Duration(milliseconds: video.trimStartMs));
    }
    _mediaSession.updateMetadata(title: video.title, album: video.folderGroup);
    _startSaveTimer();
    notifyListeners();
  }

  double _semitonesToRatio(double semitones) => pow(2, semitones / 12).toDouble();

  /// Applies brightness/contrast/saturation/gamma/hue/sharpen via the
  /// libmpv `vf` chain — a real-time equivalent of the Android app's
  /// enhancement sliders.
  Future<void> applyVideoFilters(VideoEntity v) async {
    final platform = _player.platform;
    if (platform == null) return;
    // Called dynamically: `setProperty` lives on the concrete
    // `NativePlayer` implementation, whose exact export path has moved
    // between media_kit releases. If your installed version renamed or
    // relocated it, adjust this one call — everything else (pitch,
    // speed, volume, seeking) uses the stable public Player API above
    // and is unaffected.
    final dynamic nativePlatform = platform;
    final params = v.enhancement.filterParams;
    final brightness = params.brightness + v.brightness;
    final contrast = params.contrast * v.contrast;
    final saturation = params.saturation * v.saturation;
    final gamma = params.gamma;
    final hue = params.hue + v.hue;
    final sharpen = max(params.sharpen, v.sharpness);

    final filters = <String>[
      'eq=brightness=${brightness.toStringAsFixed(3)}:contrast=${contrast.toStringAsFixed(3)}'
          ':saturation=${saturation.toStringAsFixed(3)}:gamma=${gamma.toStringAsFixed(3)}',
      if (hue.abs() > 0.01) 'hue=h=${hue.toStringAsFixed(1)}',
      if (sharpen > 0.01) 'unsharp=la=${(sharpen * 2).toStringAsFixed(2)}:ca=${(sharpen * 2).toStringAsFixed(2)}',
    ];
    try {
      await nativePlatform.setProperty('vf', filters.join(','));
    } catch (_) {
      // Filter chain unsupported/renamed on this backend — ignore,
      // picture still plays without the enhancement filter applied.
    }
  }

  void _startSaveTimer() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final v = currentVideo;
      if (v != null && _player.state.playing) {
        _repo.savePlaybackPosition(v.id, _player.state.position.inMilliseconds);
      }
    });
  }

  Future<void> togglePlayPause() async {
    if (currentVideo == null) return;
    if (_player.state.playing) {
      await _player.pause();
    } else {
      if (_player.state.completed) await _player.seek(Duration(milliseconds: trimStartMs));
      await _player.play();
    }
  }

  /// Stop = pause + rewind to the start, but the video STAYS LOADED so
  /// Play / Restart / Next / Previous / seeking all keep working. (This
  /// used to call [close], which unloaded everything and left every
  /// button on the Player screen dead.)
  Future<void> stop() async {
    final v = currentVideo;
    if (v == null) return;
    await _player.pause();
    await _player.seek(Duration(milliseconds: trimStartMs));
    await _repo.savePlaybackPosition(v.id, 0);
    _stopTicker();
    _mediaSession.updatePlaybackState(playing: false, position: Duration.zero, duration: _player.state.duration);
    notifyListeners();
  }

  bool get isMuted => _isMuted;

  Timer? _volumePersistTimer;

  /// Sets the volume (0-100), un-mutes, and remembers it as this
  /// video's saved level. Every volume control (slider, ± buttons,
  /// keyboard, mini-player, earbud/media keys) goes through here so they
  /// always agree with each other.
  Future<void> setVolumePercent(double percent) async {
    final p = percent.clamp(0, 100).toDouble();
    _isMuted = false;
    if (p > 0) _volumeBeforeMute = p;
    await _player.setVolume(p);
    final v = _currentVideo;
    if (v != null) {
      _currentVideo = v.copyWith(volumeLevel: p / 100);
      // Debounced so dragging a slider doesn't hammer the database.
      _volumePersistTimer?.cancel();
      _volumePersistTimer = Timer(const Duration(milliseconds: 350), () {
        final cur = _currentVideo;
        if (cur != null) _repo.savePreferences(cur);
      });
    }
    notifyListeners();
  }

  Future<void> adjustVolume(double deltaPercent) {
    final base = _isMuted ? _volumeBeforeMute : _player.state.volume;
    return setVolumePercent(base + deltaPercent);
  }

  Future<void> toggleMute() async {
    if (!_isMuted) {
      final current = _player.state.volume;
      if (current > 0) _volumeBeforeMute = current;
      await _player.setVolume(0);
      _isMuted = true;
    } else {
      // Restore exactly the level from before the mute (falls back to 50%
      // only if that level was itself 0).
      await _player.setVolume(_volumeBeforeMute > 0 ? _volumeBeforeMute : 50);
      _isMuted = false;
    }
    notifyListeners();
  }

  Future<void> seekRelative(int deltaMs) async {
    final target = _player.state.position + Duration(milliseconds: deltaMs);
    final clampedMs = target.inMilliseconds.clamp(trimStartMs, trimEndMs > 0 ? trimEndMs : 1 << 40);
    await _player.seek(Duration(milliseconds: clampedMs));
  }

  Future<void> seekTo(int ms) async {
    final clamped = ms.clamp(trimStartMs, trimEndMs > 0 ? trimEndMs : 1 << 40);
    await _player.seek(Duration(milliseconds: clamped));
  }

  Future<void> restart() async {
    await _player.seek(Duration(milliseconds: trimStartMs));
    await _player.play();
  }

  Future<void> playNext({bool shuffle = false, VideoEntity? carryFrom}) async {
    if (queue.isEmpty) return;
    int next;
    if (shuffle) {
      if (queue.length < 2) return;
      // Random, but never the video that just played.
      do {
        next = Random().nextInt(queue.length);
      } while (next == queueIndex);
    } else {
      if (!hasNext) return;
      next = queueIndex + 1;
    }
    await play(queue[next], siblings: queue, carryAutoPlayFrom: carryFrom);
  }

  Future<void> playPrevious() async {
    if (!hasPrevious) {
      await seekTo(trimStartMs);
      return;
    }
    await play(queue[queueIndex - 1], siblings: queue);
  }

  void _onCompleted() {
    final v = currentVideo;
    if (v == null) return;
    if (v.loopPlayback) {
      restart();
    } else if (v.autoPlayNext) {
      playNext(shuffle: v.shufflePlaylist, carryFrom: v);
    }
  }

  Future<void> close() async {
    final v = currentVideo;
    if (v != null) {
      await _repo.savePlaybackPosition(v.id, _player.state.position.inMilliseconds);
    }
    await _player.stop();
    currentVideo = null;
    queue = [];
    queueIndex = -1;
    _stopTicker();
    _saveTimer?.cancel();
    _mediaSession.updatePlaybackState(playing: false, position: Duration.zero, duration: Duration.zero);
    notifyListeners();
  }

  void setPlayerScreenVisible(bool visible) {
    isPlayerScreenVisible = visible;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _saveTimer?.cancel();
    _volumePersistTimer?.cancel();
    _mediaSessionSub?.cancel();
    _mediaSession.dispose();
    _player.dispose();
    super.dispose();
  }
}
