import 'media_session_stub.dart'
    if (dart.library.js_interop) 'media_session_web.dart'
    if (dart.library.io) 'media_session_windows.dart' as platform;

/// A hardware/earbud/OS media-control action reported back to the app.
enum MediaSessionAction {
  play,
  pause,
  next,
  previous,
  stop,
  seekForward,
  seekBackward,
}

/// Cross-platform bridge to the OS/browser media-control surface that
/// earbuds, Bluetooth headsets, and OS media-key overlays actually talk
/// to.
///
/// - **Windows**: backed by `smtc_windows`, which registers the app
///   with Windows' *System Media Transport Controls* — the same
///   mechanism that gives the taskbar thumbnail transport buttons,
///   the Windows 11 media flyout, and (crucially) hardware/Bluetooth
///   media-key and earbud button presses. See
///   `media_session_windows.dart`.
/// - **Web**: backed by the browser's `navigator.mediaSession` Media
///   Session API, which surfaces the same lock-screen/notification
///   controls and hardware media-key routing in Chrome/Edge. See
///   `media_session_web.dart`.
/// - **Everywhere else** (and as a safe fallback if the platform
///   integration fails to initialize, e.g. the Windows build machine
///   didn't have the Rust toolchain `smtc_windows` needs): a harmless
///   no-op, `media_session_stub.dart`. The in-app keyboard/UI controls
///   and the `LogicalKeyboardKey.media*` bindings in
///   `shortcuts/app_shortcuts.dart` keep working regardless.
abstract class MediaSessionService {
  factory MediaSessionService() => platform.createMediaSessionService();

  /// Must be called once, after the Flutter binding is ready, before
  /// any other method.
  Future<void> initialize();

  /// Call whenever the current video changes.
  void updateMetadata({required String title, String? artist, String? album});

  /// Call whenever play/pause state or position changes so the OS
  /// overlay / lock screen stays in sync.
  void updatePlaybackState({
    required bool playing,
    required Duration position,
    required Duration duration,
  });

  /// Fires when the user presses a hardware/earbud/OS media control.
  Stream<MediaSessionAction> get actions;

  Future<void> dispose();
}
