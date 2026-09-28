import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:smtc_windows/smtc_windows.dart';

import 'media_session_service.dart';

MediaSessionService createMediaSessionService() => _WindowsMediaSessionService();

/// Windows System Media Transport Controls integration via
/// `smtc_windows`. This is what makes Play/Pause/Next/Previous on a
/// Bluetooth earbud, a wired headset's inline remote, or the
/// keyboard's dedicated media keys reach the app — Windows delivers
/// those through SMTC rather than as ordinary key events, regardless
/// of whether Crow Théatron's window currently has focus.
///
/// NOTE ON BUILD REQUIREMENTS: `smtc_windows` is implemented with a
/// small Rust/`windows-rs` native component, so building for Windows
/// with this package present requires `rustup` to be installed on the
/// build machine (see the package's own README). If that toolchain
/// isn't available this file's `initialize()` catches the failure and
/// the app falls back to working normally, just without OS-level
/// media-key routing (the in-app shortcuts and mini-player/PlayerScreen
/// buttons are unaffected either way).
///
/// NOTE ON API SURFACE: this targets `smtc_windows: ^1.1.0`'s
/// published API (`SMTCWindows.initialize()`, the `SMTCWindows`
/// constructor, `buttonPressStream`, `setPlaybackStatus`,
/// `updateMetadata`). If a different installed version renames or
/// relocates any of these, this is the one file to adjust — everything
/// else in the app is unaffected.
class _WindowsMediaSessionService implements MediaSessionService {
  SMTCWindows? _smtc;
  StreamSubscription<PressedButton>? _buttonSub;
  final _controller = StreamController<MediaSessionAction>.broadcast();

  @override
  Future<void> initialize() async {
    if (!Platform.isWindows) return;
    try {
      await SMTCWindows.initialize();
      _smtc = SMTCWindows(
        metadata: const MusicMetadata(title: 'Crow Théatron'),
        timeline: const PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: 0,
          positionMs: 0,
          minSeekTimeMs: 0,
          maxSeekTimeMs: 0,
        ),
        config: const SMTCConfig(
          fastForwardEnabled: false,
          rewindEnabled: false,
          nextEnabled: true,
          prevEnabled: true,
          pauseEnabled: true,
          playEnabled: true,
          stopEnabled: true,
        ),
      );
      _buttonSub = _smtc!.buttonPressStream.listen((button) {
        final action = switch (button) {
          PressedButton.play => MediaSessionAction.play,
          PressedButton.pause => MediaSessionAction.pause,
          PressedButton.next => MediaSessionAction.next,
          PressedButton.previous => MediaSessionAction.previous,
          PressedButton.stop => MediaSessionAction.stop,
          _ => null,
        };
        if (action != null) _controller.add(action);
      });
    } catch (e, st) {
      debugPrint('SMTC (Windows media session) unavailable: $e\n$st');
      _smtc = null;
    }
  }

  @override
  void updateMetadata({required String title, String? artist, String? album}) {
    try {
      _smtc?.updateMetadata(MusicMetadata(title: title, artist: artist, album: album));
    } catch (_) {
      // Best-effort — a metadata update failing shouldn't affect playback.
    }
  }

  @override
  void updatePlaybackState({
    required bool playing,
    required Duration position,
    required Duration duration,
  }) {
    final smtc = _smtc;
    if (smtc == null) return;
    try {
      smtc.setPlaybackStatus(playing ? PlaybackStatus.playing : PlaybackStatus.paused);
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Stream<MediaSessionAction> get actions => _controller.stream;

  @override
  Future<void> dispose() async {
    await _buttonSub?.cancel();
    try {
      _smtc?.dispose();
    } catch (_) {}
    await _controller.close();
  }
}
