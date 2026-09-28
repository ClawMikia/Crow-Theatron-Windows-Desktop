import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/video_repository.dart';
import 'playback_service.dart';

/// Generates a real preview frame (and the real duration) for every
/// library video that doesn't have one yet, one at a time in the
/// background, using a second, muted, headless media_kit player — no new
/// package needed.
///
/// - Results are cached in the database, so they show instantly next
///   launch and survive the source file being deleted.
/// - It waits while you're watching something so it never competes with
///   playback.
/// - A file that no longer exists is skipped, never removed: the library
///   entry stays.
class ThumbnailService {
  ThumbnailService(this._repo, this._playback);

  final VideoRepository _repo;
  final PlaybackService _playback;

  final Set<int> _failed = {};
  bool _running = false;
  bool _disposed = false;
  Player? _player;
  VideoController? _controller; // kept referenced so it isn't collected mid-use

  void start() {
    if (kIsWeb) return; // web has no local file paths to sample
    _repo.addListener(_kick);
    _kick();
  }

  void _kick() {
    if (_running || _disposed) return;
    _running = true;
    _run().whenComplete(() => _running = false);
  }

  Future<void> _run() async {
    try {
      while (!_disposed) {
        final pending = (await _repo.listMissingThumbnails()).where((e) => !_failed.contains(e.$1)).toList();
        if (pending.isEmpty) break;
        for (final (id, path) in pending) {
          if (_disposed) break;
          while (!_disposed && _playback.player.state.playing) {
            await Future.delayed(const Duration(seconds: 3));
          }
          await _generate(id, path);
        }
      }
    } catch (e) {
      debugPrint('ThumbnailService: $e');
    } finally {
      await _releasePlayer();
    }
  }

  Future<void> _generate(int id, String path) async {
    try {
      if (!File(path).existsSync()) {
        _failed.add(id); // file gone — keep the entry, just no new thumbnail
        return;
      }
      final player = await _ensurePlayer();
      await player.stop(); // reset state so we never read the previous video's values
      await player.open(Media(path), play: false);
      await _waitFor(() => player.state.duration > Duration.zero && (player.state.width ?? 0) > 0);

      final durMs = player.state.duration.inMilliseconds;
      var seekMs = (durMs * 0.1).round().clamp(1000, 90000);
      if (seekMs >= durMs) seekMs = durMs ~/ 2;
      await player.seek(Duration(milliseconds: seekMs));
      await Future.delayed(const Duration(milliseconds: 600));

      Uint8List? bytes;
      for (var i = 0; i < 5 && (bytes == null || bytes.isEmpty); i++) {
        bytes = await player.screenshot();
        if (bytes == null || bytes.isEmpty) await Future.delayed(const Duration(milliseconds: 400));
      }
      if (bytes != null && bytes.isNotEmpty) {
        await _repo.saveThumbnail(id, bytes, durationMs: durMs);
      } else {
        _failed.add(id);
      }
    } catch (e) {
      debugPrint('ThumbnailService: thumbnail for $path failed: $e');
      _failed.add(id);
    }
  }

  Future<void> _waitFor(bool Function() ready, {Duration timeout = const Duration(seconds: 10)}) async {
    final end = DateTime.now().add(timeout);
    while (!ready()) {
      if (DateTime.now().isAfter(end)) throw TimeoutException('media not ready');
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<Player> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) return existing;
    final p = Player();
    // A controller gives the player a (tiny, never displayed) video
    // output — required for screenshots to work.
    _controller = VideoController(p, configuration: const VideoControllerConfiguration(width: 480, height: 270));
    await p.setVolume(0);
    try {
      // Small frames + moderate JPEG quality keep the cached thumbnails
      // light. Called dynamically because `setProperty` lives on the
      // concrete native player whose export path has moved between
      // media_kit releases; if unavailable we just get bigger frames.
      final dynamic native = p.platform;
      await native.setProperty('screenshot-jpeg-quality', '70');
      await native.setProperty('vf', 'scale=480:-2');
    } catch (_) {}
    _player = p;
    return p;
  }

  Future<void> _releasePlayer() async {
    final p = _player;
    _player = null;
    _controller = null;
    try {
      await p?.dispose();
    } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    _repo.removeListener(_kick);
    _releasePlayer();
  }
}
