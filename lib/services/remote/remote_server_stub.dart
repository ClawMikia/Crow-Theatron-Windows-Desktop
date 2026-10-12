import 'package:flutter/foundation.dart';

import '../../data/video_repository.dart';
import '../playback_service.dart';

/// Web stub: browsers cannot open server sockets, so remote control is
/// simply unavailable. Same public API as `remote_server_io.dart` so the
/// Settings card compiles on every platform.
class RemoteServer extends ChangeNotifier {
  RemoteServer(PlaybackService svc, VideoRepository repo);

  static const int tcpPort = 8765;
  static const int udpPort = 8766;

  bool get supported => false;
  bool get enabled => false;
  bool get running => false;
  String get pin => '------';
  String? get lastError => 'Remote control is only available in the Windows desktop build.';
  List<String> get addresses => const [];
  int get clientCount => 0;
  int get pairedCount => 0;
  String get pairingUri => '';

  Future<void> init() async {}
  Future<void> setEnabled(bool value) async {}
  void regeneratePin() {}
  Future<void> forgetAllDevices() async {}
  Future<void> refreshAddresses() async {}
}
