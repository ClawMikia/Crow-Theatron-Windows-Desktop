import 'dart:async';

import 'media_session_service.dart';

MediaSessionService createMediaSessionService() => _StubMediaSessionService();

/// No-op implementation used on any platform without a real media
/// session integration (or as the safe fallback if one fails to
/// initialize). In-app keyboard shortcuts and on-screen transport
/// controls are unaffected — this only means hardware/earbud media
/// keys won't be routed through the OS.
class _StubMediaSessionService implements MediaSessionService {
  final _controller = StreamController<MediaSessionAction>.broadcast();

  @override
  Future<void> initialize() async {}

  @override
  void updateMetadata({required String title, String? artist, String? album}) {}

  @override
  void updatePlaybackState({
    required bool playing,
    required Duration position,
    required Duration duration,
  }) {}

  @override
  Stream<MediaSessionAction> get actions => _controller.stream;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
