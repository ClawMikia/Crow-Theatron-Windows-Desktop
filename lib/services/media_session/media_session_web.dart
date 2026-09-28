import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'media_session_service.dart';

MediaSessionService createMediaSessionService() => _WebMediaSessionService();

/// Browser Media Session API integration
/// (`navigator.mediaSession`/`MediaMetadata`/`setActionHandler`), used
/// when Crow Théatron is running as a web app. This is what lets a
/// Bluetooth earbud's play/pause/next/previous buttons, a laptop's
/// dedicated media keys, and the browser/OS's own now-playing overlay
/// control playback, and shows the video title in that overlay.
///
/// NOTE ON API SURFACE: this targets the `package:web` bindings for
/// the standard Media Session API. If the installed `web` package
/// version renamed a member here, this is the one file to adjust —
/// every other part of the media-session feature (the abstract
/// interface, the Windows SMTC implementation, and the wiring in
/// PlaybackService) is unaffected.
class _WebMediaSessionService implements MediaSessionService {
  final _controller = StreamController<MediaSessionAction>.broadcast();

  web.MediaSession? get _session => web.window.navigator.mediaSession;

  @override
  Future<void> initialize() async {
    final session = _session;
    if (session == null) return;
    _bind(session, 'play', MediaSessionAction.play);
    _bind(session, 'pause', MediaSessionAction.pause);
    _bind(session, 'stop', MediaSessionAction.stop);
    _bind(session, 'nexttrack', MediaSessionAction.next);
    _bind(session, 'previoustrack', MediaSessionAction.previous);
    _bind(session, 'seekforward', MediaSessionAction.seekForward);
    _bind(session, 'seekbackward', MediaSessionAction.seekBackward);
  }

  void _bind(web.MediaSession session, String action, MediaSessionAction result) {
    try {
      session.setActionHandler(
        action,
        ((JSAny? _) {
          _controller.add(result);
        }).toJS,
      );
    } catch (_) {
      // This particular action isn't supported by the browser — safe
      // to ignore, the rest keep working.
    }
  }

  @override
  void updateMetadata({required String title, String? artist, String? album}) {
    final session = _session;
    if (session == null) return;
    try {
      session.metadata = web.MediaMetadata(
        title: title,
        artist: artist ?? '',
        album: album ?? '',
      );
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  void updatePlaybackState({
    required bool playing,
    required Duration position,
    required Duration duration,
  }) {
    final session = _session;
    if (session == null) return;
    try {
      session.playbackState = playing ? 'playing' : 'paused';
      if (duration > Duration.zero) {
        session.setPositionState(
          web.MediaPositionState(
            duration: duration.inMilliseconds / 1000,
            position: position.inMilliseconds.clamp(0, duration.inMilliseconds) / 1000,
            playbackRate: 1.0,
          ),
        );
      }
    } catch (_) {
      // Best-effort — a handful of browsers don't implement
      // setPositionState yet.
    }
  }

  @override
  Stream<MediaSessionAction> get actions => _controller.stream;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
