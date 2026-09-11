import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../data/video_repository.dart';
import '../models/video_entity.dart';

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
      if (playing) {
        _startTicker();
      } else {
        _stopTicker();
      }
    });
    _player.stream.completed.listen((completed) {
      if (completed) _onCompleted();
    });
    _player.stream.position.listen((_) => notifyListeners());
  }

  final VideoRepository _repo;
  late final Player _player;
  Player get player => _player;

  VideoEntity? currentVideo;
  List<VideoEntity> queue = [];
  int queueIndex = -1;

  /// True while the full PlayerScreen is on top — hides the mini-player.
  bool isPlayerScreenVisible = false;

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
  Future<void> play(VideoEntity video, {List<VideoEntity>? siblings}) async {
    currentVideo = video;
    queue = siblings ?? [video];
    queueIndex = queue.indexWhere((v) => v.id == video.id);
    if (queueIndex < 0) queueIndex = 0;

    await _player.open(Media(video.uriString), play: true);
    await _player.setRate(video.playbackSpeed);
    await _player.setPitch(_semitonesToRatio(video.pitchSemitones));
    await _player.setVolume((video.volumeLevel * 100).clamp(0, 100));
    await applyVideoFilters(video);
    if (video.positionMs > 0 && video.positionMs < video.durationMs) {
      await _player.seek(Duration(milliseconds: video.positionMs));
    } else if (video.trimStartMs > 0) {
      await _player.seek(Duration(milliseconds: video.trimStartMs));
    }
    _startSaveTimer();
    notifyListeners();
  }

  double _semitonesToRatio(int semitones) => pow(2, semitones / 12).toDouble();

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
    if (_player.state.playing) {
      await _player.pause();
    } else {
      if (_player.state.completed) await _player.seek(Duration(milliseconds: trimStartMs));
      await _player.play();
    }
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

  Future<void> playNext({bool shuffle = false}) async {
    if (queue.isEmpty) return;
    int next;
    if (shuffle) {
      next = Random().nextInt(queue.length);
    } else {
      if (!hasNext) return;
      next = queueIndex + 1;
    }
    await play(queue[next], siblings: queue);
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
      playNext(shuffle: v.shufflePlaylist);
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
    _player.dispose();
    super.dispose();
  }
}
