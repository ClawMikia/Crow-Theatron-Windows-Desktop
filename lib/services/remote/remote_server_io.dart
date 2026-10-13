import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/video_repository.dart';
import '../../models/crop_mode.dart';
import '../../models/enhancement_mode.dart';
import '../../models/eq_preset.dart';
import '../../models/video_entity.dart';
import '../playback_service.dart';

/// Phone remote-control server for the Crow-Chap Android app.
///
/// * TCP 8765 — newline-delimited JSON. First message must be
///   `{"t":"hello","pin":"123456"}` or `{"t":"hello","token":"..."}`.
/// * UDP 8766 — discovery: replies to `CROW_DISCOVER` with server info.
///
/// The server pushes `state` messages (throttled) and answers library /
/// playlist / queue / art requests. Every command is routed through the
/// same [PlaybackService] / [VideoRepository] calls the desktop UI uses,
/// so the two stay in sync.
class RemoteServer extends ChangeNotifier {
  RemoteServer(this._svc, this._repo);

  static const int tcpPort = 8765;
  static const int udpPort = 8766;
  static const int protocolVersion = 1;

  static const _kEnabled = 'remote_enabled';
  static const _kTokens = 'remote_tokens';
  static const _kPin = 'remote_pin';

  final PlaybackService _svc;
  final VideoRepository _repo;

  SharedPreferences? _prefs;
  ServerSocket? _server;
  RawDatagramSocket? _udp;
  final List<_Client> _clients = [];
  final Set<String> _tokens = {};

  bool _enabled = false;
  String _pin = '000000';
  String? _lastError;
  List<String> _addresses = [];

  Timer? _pushTimer;
  String _lastSig = '';
  int _lastPos = -100000;
  bool _listening = false;

  bool get supported => true;
  bool get enabled => _enabled;
  bool get running => _server != null;
  String get pin => _pin;
  String? get lastError => _lastError;
  List<String> get addresses => List.unmodifiable(_addresses);
  int get clientCount => _clients.where((c) => c.authed).length;
  int get pairedCount => _tokens.length;

  /// `crowchap://pair?ip=a,b&port=8765&pin=123456&name=PC` — shown as a QR
  /// code in Settings and scanned by the phone.
  String get pairingUri {
    final ips = _addresses.join(',');
    return 'crowchap://pair?ip=${Uri.encodeComponent(ips)}&port=$tcpPort'
        '&pin=$_pin&name=${Uri.encodeComponent(_hostName())}';
  }

  String _hostName() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'Crow PC';
    }
  }

  // ── Lifecycle ────────────────────────────────────────────────────────

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    _enabled = p.getBool(_kEnabled) ?? false;
    _tokens
      ..clear()
      ..addAll(p.getStringList(_kTokens) ?? const []);
    _pin = p.getString(_kPin) ?? _newPin();
    await p.setString(_kPin, _pin);
    await refreshAddresses();
    if (_enabled) await _start();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _prefs?.setBool(_kEnabled, value);
    if (value) {
      await _start();
    } else {
      await _stop();
    }
    notifyListeners();
  }

  void regeneratePin() {
    _pin = _newPin();
    _prefs?.setString(_kPin, _pin);
    notifyListeners();
  }

  Future<void> forgetAllDevices() async {
    _tokens.clear();
    await _prefs?.setStringList(_kTokens, <String>[]);
    for (final c in List<_Client>.from(_clients)) {
      _drop(c);
    }
    notifyListeners();
  }

  Future<void> refreshAddresses() async {
    try {
      final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      final ips = <String>[];
      for (final i in ifaces) {
        for (final a in i.addresses) {
          ips.add(a.address);
        }
      }
      // Prefer typical home-LAN ranges first.
      ips.sort((a, b) => _rank(a).compareTo(_rank(b)));
      _addresses = ips;
    } catch (_) {
      _addresses = [];
    }
    notifyListeners();
  }

  int _rank(String ip) {
    if (ip.startsWith('192.168.')) return 0;
    if (ip.startsWith('10.')) return 1;
    if (ip.startsWith('172.')) return 2;
    return 3;
  }

  String _newPin() {
    final r = Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  String _newToken() {
    final r = Random.secure();
    return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Future<void> _start() async {
    if (_server != null) return;
    _lastError = null;
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort, shared: true);
      _server!.listen(_onClient, onError: (_) {}, cancelOnError: false);
    } catch (e) {
      _lastError = 'Could not open TCP $tcpPort: $e';
      _server = null;
      return;
    }
    try {
      _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort, reuseAddress: true);
      _udp!.broadcastEnabled = true;
      _udp!.listen(_onUdp);
    } catch (e) {
      // Discovery is optional — manual IP / QR still work.
      _lastError = 'Discovery (UDP $udpPort) unavailable: $e';
      _udp = null;
    }
    if (!_listening) {
      _svc.addListener(_onPlaybackChanged);
      _listening = true;
    }
    await refreshAddresses();
  }

  Future<void> _stop() async {
    if (_listening) {
      _svc.removeListener(_onPlaybackChanged);
      _listening = false;
    }
    _pushTimer?.cancel();
    _pushTimer = null;
    for (final c in List<_Client>.from(_clients)) {
      _drop(c);
    }
    await _server?.close();
    _server = null;
    _udp?.close();
    _udp = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  // ── Discovery ────────────────────────────────────────────────────────

  void _onUdp(RawSocketEvent ev) {
    if (ev != RawSocketEvent.read) return;
    final dg = _udp?.receive();
    if (dg == null) return;
    final text = utf8.decode(dg.data, allowMalformed: true).trim();
    if (!text.startsWith('CROW_DISCOVER')) return;
    final reply = jsonEncode({
      't': 'crow_server',
      'name': _hostName(),
      'port': tcpPort,
      'ver': protocolVersion,
    });
    _udp?.send(utf8.encode(reply), dg.address, dg.port);
  }

  // ── Client handling ──────────────────────────────────────────────────

  void _onClient(Socket socket) {
    final c = _Client(socket);
    _clients.add(c);
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}
    // Unauthenticated sockets get 10 s to say hello.
    c.authTimer = Timer(const Duration(seconds: 10), () {
      if (!c.authed) _drop(c);
    });
    utf8.decoder.bind(socket).transform(const LineSplitter()).listen(
      (line) => _onLine(c, line),
      onDone: () => _drop(c),
      onError: (_) => _drop(c),
      cancelOnError: true,
    );
    notifyListeners();
  }

  void _drop(_Client c) {
    c.authTimer?.cancel();
    if (_clients.remove(c)) {
      try {
        c.socket.destroy();
      } catch (_) {}
      notifyListeners();
    }
  }

  void _send(_Client c, Map<String, Object?> msg) {
    try {
      c.socket.write('${jsonEncode(msg)}\n');
    } catch (_) {
      _drop(c);
    }
  }

  void _broadcast(Map<String, Object?> msg) {
    final line = '${jsonEncode(msg)}\n';
    for (final c in List<_Client>.from(_clients)) {
      if (!c.authed) continue;
      try {
        c.socket.write(line);
      } catch (_) {
        _drop(c);
      }
    }
  }

  Future<void> _onLine(_Client c, String line) async {
    if (!c.authed && line.length > 2048) {
      _drop(c);
      return;
    }
    Map<String, dynamic> m;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) return;
      m = decoded;
    } catch (_) {
      return;
    }
    final t = m['t'] as String? ?? '';
    if (!c.authed) {
      if (t == 'hello') await _hello(c, m);
      return;
    }
    try {
      await _handle(c, t, m);
    } catch (e) {
      _send(c, {'t': 'error', 'msg': '$e'});
    }
  }

  Future<void> _hello(_Client c, Map<String, dynamic> m) async {
    final pin = m['pin']?.toString();
    final token = m['token']?.toString();
    String? issued;
    if (token != null && token.isNotEmpty && _tokens.contains(token)) {
      issued = token;
    } else if (pin != null && pin.isNotEmpty && pin == _pin) {
      issued = _newToken();
      _tokens.add(issued);
      await _prefs?.setStringList(_kTokens, _tokens.toList());
    }
    if (issued == null) {
      c.fails++;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _send(c, {'t': 'hello_err', 'msg': token != null && pin == null ? 'Pairing expired — enter the PIN again' : 'Wrong PIN'});
      if (c.fails >= 5) _drop(c);
      return;
    }
    c.authed = true;
    c.authTimer?.cancel();
    c.name = (m['name'] as String?) ?? 'Phone';
    _send(c, {
      't': 'hello_ok',
      'token': issued,
      'name': _hostName(),
      'ver': protocolVersion,
      'eqPresets': [for (final e in EqPreset.values) {'key': e.storageKey, 'name': e.displayName}],
      'cropModes': [for (final e in CropMode.values) {'key': e.storageKey, 'name': e.label}],
      'enhancements': [for (final e in EnhancementMode.values) {'key': e.storageKey, 'name': e.displayName}],
    });
    _send(c, _stateMap());
    notifyListeners();
  }

  // ── State push ───────────────────────────────────────────────────────

  void _onPlaybackChanged() {
    if (_clients.isEmpty) return;
    if (_pushTimer != null) return;
    _pushTimer = Timer(const Duration(milliseconds: 120), () {
      _pushTimer = null;
      _pushState(force: false);
    });
  }

  void _pushState({required bool force}) {
    if (clientCount == 0) return;
    final s = _stateMap();
    final pos = s['pos'] as int;
    final sig = jsonEncode(Map<String, Object?>.from(s)..remove('pos'));
    final changed = sig != _lastSig;
    final posMoved = (pos - _lastPos).abs() >= 900;
    if (force || changed || posMoved) {
      _lastSig = sig;
      _lastPos = pos;
      _broadcast(s);
    }
  }

  Map<String, Object?> _stateMap() {
    final v = _svc.currentVideo;
    final st = _svc.player.state;
    final durMs = st.duration.inMilliseconds > 0 ? st.duration.inMilliseconds : (v?.durationMs ?? 0);
    final vol = _svc.isMuted ? (v?.volumeLevel ?? 1.0) * 100 : st.volume;
    return {
      't': 'state',
      'has': v != null,
      'id': v?.id ?? 0,
      'title': v?.title ?? '',
      'folder': v?.folderGroup ?? '',
      'playing': st.playing,
      'pos': st.position.inMilliseconds,
      'dur': durMs,
      'vol': vol.round(),
      'muted': _svc.isMuted,
      'fullscreen': _svc.fullscreen,
      'speed': v?.playbackSpeed ?? 1.0,
      'pitch': v?.pitchSemitones ?? 0.0,
      'eq': (v?.eqPreset ?? EqPreset.flat).storageKey,
      'crop': (v?.cropMode ?? CropMode.fit).storageKey,
      'enh': (v?.enhancement ?? EnhancementMode.none).storageKey,
      'fav': v?.favorite ?? false,
      'loop': v?.loopPlayback ?? false,
      'auto': v?.autoPlayNext ?? false,
      'shuffle': v?.shufflePlaylist ?? false,
      'next': _svc.hasNext,
      'prev': _svc.hasPrevious,
      'trimStart': _svc.trimStartMs,
      'trimEnd': _svc.trimEndMs,
      'qi': _svc.queueIndex,
      'qn': _svc.queue.length,
      'stepSec': _svc.prefs.defaultSeekJumpSec,
      'speedStep': _svc.prefs.defaultSpeedStep,
      'pitchStep': _svc.prefs.defaultPitchStepSemitones,
      'volStep': _svc.prefs.defaultVolumeStepPercent,
    };
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  int _i(Map<String, dynamic> m, String k, [int d = 0]) => (m[k] as num?)?.toInt() ?? d;
  double _d(Map<String, dynamic> m, String k, [double d = 0]) => (m[k] as num?)?.toDouble() ?? d;
  bool _b(Map<String, dynamic> m, String k, [bool d = false]) => m[k] is bool ? m[k] as bool : d;
  double _round2(double v) => (v * 100).round() / 100;

  Map<String, Object?> _videoJson(VideoEntity v) => {
        'id': v.id,
        'title': v.title,
        'folder': v.folderGroup,
        'dur': v.durationMs,
        'pos': v.positionMs,
        'fav': v.favorite,
      };

  /// Persists per-video settings exactly like PlayerScreen._saveVideo.
  Future<void> _saveCurrent(VideoEntity updated) async {
    final live = _svc.currentVideo;
    if (live == null || live.id != updated.id) return;
    updated = updated.copyWith(volumeLevel: live.volumeLevel);
    await _repo.savePreferences(updated);
    _svc.currentVideo = updated;
    await _svc.applyVideoFilters(updated);
  }

  Future<List<VideoEntity>> _listFor(Map<String, dynamic> m) async {
    final q = (m['q'] as String?)?.trim() ?? '';
    final mode = (m['mode'] as String?) ?? 'all';
    List<VideoEntity> l;
    if (q.isNotEmpty) {
      l = await _repo.search(q);
    } else {
      switch (mode) {
        case 'favorites':
          l = await _repo.listFavorites();
          break;
        case 'recent':
          l = await _repo.listRecentlyPlayed(limit: 50);
          break;
        case 'continue':
          l = await _repo.listContinueWatching();
          break;
        case 'memory':
          l = await _repo.listPlaybackMemory();
          break;
        default:
          l = await _repo.listAllByFolder();
      }
    }
    final folder = m['folder'] as String?;
    if (folder != null && folder.isNotEmpty) {
      l = l.where((v) => v.folderGroup == folder).toList();
    }
    return l;
  }

  Future<List<VideoEntity>> _contextList(Map<String, dynamic> m) async {
    final pid = m['pid'];
    if (pid is num) return _repo.getVideosInPlaylist(pid.toInt());
    return _listFor(m);
  }

  // ── Command router ───────────────────────────────────────────────────

  Future<void> _handle(_Client c, String t, Map<String, dynamic> m) async {
    final cur = _svc.currentVideo;
    switch (t) {
      case 'ping':
        _send(c, {'t': 'pong'});
        return;
      case 'get_state':
        _pushState(force: true);
        return;

      // Transport
      case 'play_pause':
        await _svc.togglePlayPause();
        break;
      case 'play':
        if (!_svc.player.state.playing) await _svc.togglePlayPause();
        break;
      case 'pause':
        if (_svc.player.state.playing) await _svc.togglePlayPause();
        break;
      case 'stop':
        await _svc.stop();
        break;
      case 'next':
        await _svc.playNext();
        break;
      case 'prev':
        await _svc.playPrevious();
        break;
      case 'restart':
        await _svc.restart();
        break;
      case 'seek_to':
        await _svc.seekTo(_i(m, 'ms'));
        break;
      case 'seek_rel':
        await _svc.seekRelative(_i(m, 'ms'));
        break;

      // Volume
      case 'volume':
        await _svc.setVolumePercent(_d(m, 'v'));
        break;
      case 'volume_rel':
        await _svc.adjustVolume(_d(m, 'd'));
        break;
      case 'mute':
        await _svc.toggleMute();
        break;

      // View
      case 'fullscreen':
        _svc.toggleFullscreen();
        break;

      // Tools (per-video, persisted)
      case 'speed':
        if (cur != null) {
          final sp = _round2(_d(m, 'v', 1).clamp(0.25, 3.0));
          await _svc.player.setRate(sp);
          await _saveCurrent(cur.copyWith(playbackSpeed: sp));
        }
        break;
      case 'pitch':
        if (cur != null) {
          final st = _round2(_d(m, 'v').clamp(-12.0, 12.0));
          await _svc.player.setPitch(pow(2, st / 12).toDouble());
          await _saveCurrent(cur.copyWith(pitchSemitones: st));
        }
        break;
      case 'eq':
        if (cur != null) {
          final e = EqPreset.fromKey(m['key'] as String?);
          final updated = cur.copyWith(eqPreset: e);
          await _saveCurrent(updated);
          await _svc.applyAudioEq(updated);
        }
        break;
      case 'crop':
        if (cur != null) {
          await _saveCurrent(cur.copyWith(cropMode: CropMode.fromKey(m['key'] as String?)));
        }
        break;
      case 'enhance':
        if (cur != null) {
          await _saveCurrent(cur.copyWith(enhancement: EnhancementMode.fromKey(m['key'] as String?)));
        }
        break;
      case 'loop':
        if (cur != null) await _saveCurrent(cur.copyWith(loopPlayback: _b(m, 'on')));
        break;
      case 'auto':
        if (cur != null) await _saveCurrent(cur.copyWith(autoPlayNext: _b(m, 'on')));
        break;
      case 'shuffle':
        if (cur != null) await _saveCurrent(cur.copyWith(shufflePlaylist: _b(m, 'on')));
        break;
      case 'favorite':
        final favId = _i(m, 'id', cur?.id ?? 0);
        if (favId != 0) {
          final on = _b(m, 'on');
          await _repo.setFavorite(favId, on);
          if (cur != null && cur.id == favId) _svc.currentVideo = cur.copyWith(favorite: on);
        }
        break;

      // Library / playback of a chosen video
      case 'get_lib':
        {
          final list = await _listFor(m);
          final capped = list.length > 3000 ? list.sublist(0, 3000) : list;
          _send(c, {
            't': 'lib',
            'mode': m['mode'] ?? 'all',
            'q': m['q'] ?? '',
            'folder': m['folder'],
            'folders': await _repo.listFolders(),
            'total': list.length,
            'videos': capped.map(_videoJson).toList(),
          });
          return;
        }
      case 'play_video':
        {
          final video = await _repo.getById(_i(m, 'id'));
          if (video == null) {
            _send(c, {'t': 'error', 'msg': 'Video not found'});
            return;
          }
          var siblings = await _contextList(m);
          if (!siblings.any((v) => v.id == video.id)) siblings = [video];
          await _svc.play(video, siblings: siblings);
          break;
        }
      case 'play_all':
        {
          final list = await _contextList(m);
          if (list.isEmpty) return;
          final shuffle = _b(m, 'shuffle');
          final ordered = List<VideoEntity>.from(list);
          if (shuffle) ordered.shuffle();
          await _svc.play(ordered.first, siblings: ordered);
          final now = _svc.currentVideo;
          if (now != null) {
            await _saveCurrent(now.copyWith(autoPlayNext: true, shufflePlaylist: shuffle));
          }
          break;
        }
      case 'delete_from_library':
        await _repo.deleteVideo(_i(m, 'id'));
        break;

      // Queue
      case 'get_queue':
        _send(c, {
          't': 'queue',
          'index': _svc.queueIndex,
          'items': _svc.queue.map(_videoJson).toList(),
        });
        return;
      case 'play_queue_index':
        {
          final i = _i(m, 'i', -1);
          if (i >= 0 && i < _svc.queue.length) {
            await _svc.play(_svc.queue[i], siblings: List<VideoEntity>.from(_svc.queue));
          }
          break;
        }

      // Playlists
      case 'get_playlists':
        {
          final rows = await _repo.listPlaylistsWithCounts();
          _send(c, {
            't': 'playlists',
            'items': [for (final r in rows) {'id': r.$1.id, 'title': r.$1.title, 'count': r.$2}],
          });
          return;
        }
      case 'get_playlist':
        {
          final pid = _i(m, 'id');
          final vids = await _repo.getVideosInPlaylist(pid);
          _send(c, {'t': 'playlist', 'id': pid, 'videos': vids.map(_videoJson).toList()});
          return;
        }
      case 'create_playlist':
        {
          final title = (m['title'] as String?)?.trim() ?? '';
          if (title.isNotEmpty) await _repo.createPlaylist(title);
          break;
        }
      case 'delete_playlist':
        await _repo.deletePlaylist(_i(m, 'id'));
        break;
      case 'rename_playlist':
        {
          final title = (m['title'] as String?)?.trim() ?? '';
          if (title.isNotEmpty) await _repo.renamePlaylist(_i(m, 'id'), title);
          break;
        }
      case 'add_to_playlist':
        await _repo.addVideoToPlaylist(_i(m, 'pid'), _i(m, 'vid'));
        break;
      case 'remove_from_playlist':
        await _repo.removeVideoFromPlaylist(_i(m, 'pid'), _i(m, 'vid'));
        break;

      // Thumbnails
      case 'get_art':
        {
          final id = _i(m, 'id');
          final bytes = await _repo.loadThumbnail(id);
          if (bytes == null || bytes.isEmpty || bytes.length > 400000) {
            _send(c, {'t': 'art', 'id': id, 'none': true});
          } else {
            _send(c, {'t': 'art', 'id': id, 'b64': base64Encode(bytes)});
          }
          return;
        }

      default:
        return;
    }
    // Any state-changing command: push fresh state immediately.
    _pushState(force: true);
  }
}

class _Client {
  _Client(this.socket);
  final Socket socket;
  bool authed = false;
  int fails = 0;
  String name = 'Phone';
  Timer? authTimer;
}
