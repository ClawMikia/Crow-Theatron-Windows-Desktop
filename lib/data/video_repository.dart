import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/chapter_marker.dart';
import '../models/playlist.dart';
import '../models/timeline_skip.dart';
import '../models/video_entity.dart';
import 'app_prefs.dart';
import 'crow_database.dart';

/// Port of `data/VideoRepository.kt` — the facade every screen talks to.
/// On desktop, videos are referenced directly by their file path (no
/// SAF copy-to-internal-storage step is needed since the app already
/// has ordinary filesystem access).
///
/// Extends [ChangeNotifier] so that every screen that watches this
/// provider auto-refreshes when data is mutated (imports, deletions,
/// preference saves, chapter/skip edits, playlist changes, …).
class VideoRepository extends ChangeNotifier {
  VideoRepository(this._db, this._prefs) {
    // Forward preference changes so any widget watching the repository
    // also rebuilds when AppPrefs setters fire.
    _prefs.addListener(notifyListeners);
  }
  final CrowDatabase _db;
  final AppPrefs _prefs;

  static Future<VideoRepository> create() async {
    final prefs = await AppPrefs.getInstance();
    return VideoRepository(CrowDatabase.instance, prefs);
  }

  // ── Scanning / import ────────────────────────────────────────────────

  Future<void> importScanResults(List<VideoEntity> entities) async {
    var n = 0;
    for (final e in entities) {
      final prepared = e.copyWith(
        seekJumpSec: _prefs.defaultSeekJumpSec,
        enhancement: _prefs.defaultEnhancement,
      );
      await _db.insertOrMergeFromScan(prepared);
      // Progressive refresh: every open library/favorites/explore view
      // fills in while a big import is still running instead of only
      // after it finishes.
      if (++n % 25 == 0) notifyListeners();
    }
    notifyListeners();
  }

  /// Asks every listening screen to reload (e.g. after an import flow
  /// has finished and other state, like the last-used folder, changed).
  void refresh() => notifyListeners();

  // ── Removing from the LIBRARY (never touches files on disk) ──────────

  Future<void> deleteVideo(int id) => deleteVideos([id]);

  Future<void> deleteVideos(List<int> ids) async {
    await _db.deleteByIds(ids);
    for (final id in ids) {
      _thumbCache.remove(id);
    }
    notifyListeners();
  }

  /// Removes every video in [folder] from the library. Returns how many.
  Future<int> deleteFolder(String folder) async {
    final ids = await _db.idsInFolder(folder);
    await deleteVideos(ids);
    return ids.length;
  }

  Future<void> resetLibrary() async {
    await _db.resetLibrary();
    _thumbCache.clear();
    thumbnailRevision.value++;
    notifyListeners();
  }

  // ── Folders (library labels only) ────────────────────────────────────

  Future<List<String>> listFolders() => _db.listFolders();

  Future<void> moveVideosToFolder(List<int> ids, String folder) async {
    await _db.moveToFolder(ids, folder.trim());
    notifyListeners();
  }

  // ── Thumbnails ───────────────────────────────────────────────────────

  final Map<int, Uint8List> _thumbCache = {};
  final Set<int> _thumbMisses = {};

  /// Ticks whenever any thumbnail is (re)generated so tiles can pick it up
  /// without the whole library being reloaded.
  final ValueNotifier<int> thumbnailRevision = ValueNotifier<int>(0);

  Uint8List? cachedThumbnail(int id) => _thumbCache[id];

  Future<Uint8List?> loadThumbnail(int id) async {
    final cached = _thumbCache[id];
    if (cached != null) return cached;
    if (_thumbMisses.contains(id)) return null;
    final bytes = await _db.getThumbnail(id);
    if (bytes == null) {
      _thumbMisses.add(id);
    } else {
      _thumbCache[id] = bytes;
    }
    return bytes;
  }

  Future<List<(int, String)>> listMissingThumbnails() => _db.listMissingThumbnails();

  Timer? _durationNotify;

  Future<void> saveThumbnail(int id, Uint8List bytes, {int? durationMs}) async {
    await _db.setThumbnail(id, bytes);
    _thumbMisses.remove(id);
    _thumbCache[id] = bytes;
    thumbnailRevision.value++;
    if (durationMs != null && durationMs > 0) {
      await _db.updateDuration(id, durationMs);
      // Debounced: many thumbnails finishing in a row cause ONE reload.
      _durationNotify?.cancel();
      _durationNotify = Timer(const Duration(seconds: 2), notifyListeners);
    }
  }

  // ── Queries ──────────────────────────────────────────────────────────

  Future<VideoEntity?> getById(int id) => _db.getById(id);
  Future<List<VideoEntity>> listAllByFolder() => _db.listAllOrderedByFolder();
  Future<List<VideoEntity>> listFavorites() => _db.listFavorites();
  Future<List<VideoEntity>> listPlaybackMemory() => _db.listPlaybackMemory();
  Future<List<VideoEntity>> listContinueWatching() => _db.listContinueWatching();
  Future<List<VideoEntity>> listRecentlyPlayed({int limit = 20}) => _db.listRecentlyPlayed(limit: limit);
  Future<List<VideoEntity>> search(String query) => _db.searchByTitle(query);

  Future<void> savePlaybackPosition(int id, int positionMs) => _db.updatePlaybackState(id, positionMs);

  Future<void> savePreferences(VideoEntity e) async {
    await _db.updatePreferences(e);
    notifyListeners();
  }

  Future<void> setFavorite(int id, bool favorite) async {
    await _db.setFavorite(id, favorite);
    notifyListeners();
  }

  // ── Chapters ─────────────────────────────────────────────────────────

  Future<int> addChapter(int videoId, int positionMs, String label, {bool auto = false}) async {
    final id = await _db.insertChapter(
      ChapterMarker(
        videoId: videoId,
        positionMs: positionMs,
        label: label,
        isAutoDetected: auto,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    notifyListeners();
    return id;
  }

  Future<void> deleteChapter(int id) async {
    await _db.deleteChapter(id);
    notifyListeners();
  }

  Future<void> deleteAllChapters(int videoId) async {
    await _db.deleteChaptersForVideo(videoId);
    notifyListeners();
  }

  Future<List<ChapterMarker>> listChapters(int videoId) => _db.listChaptersForVideo(videoId);

  // ── Timeline skips ───────────────────────────────────────────────────

  Future<int> addSkip(int videoId, int startMs, int endMs, {String label = 'Skip'}) async {
    final id = await _db.insertSkip(
      TimelineSkip(
        videoId: videoId,
        startMs: startMs,
        endMs: endMs,
        label: label,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    notifyListeners();
    return id;
  }

  Future<void> deleteSkip(int id) async {
    await _db.deleteSkip(id);
    notifyListeners();
  }

  Future<void> deleteAllSkips(int videoId) async {
    await _db.deleteSkipsForVideo(videoId);
    notifyListeners();
  }
  Future<List<TimelineSkip>> listSkips(int videoId) => _db.listSkipsForVideo(videoId);

  // ── Playlists ────────────────────────────────────────────────────────

  Future<int> createPlaylist(String title) async {
    final id = await _db.insertPlaylist(title);
    notifyListeners();
    return id;
  }

  Future<void> deletePlaylist(int id) async {
    await _db.deletePlaylist(id);
    notifyListeners();
  }

  Future<void> renamePlaylist(int id, String newTitle) async {
    await _db.renamePlaylist(id, newTitle);
    notifyListeners();
  }

  Future<List<Playlist>> listPlaylists() => _db.listPlaylists();

  Future<void> addVideoToPlaylist(int playlistId, int videoId) async {
    await _db.addVideoToPlaylist(playlistId, videoId);
    notifyListeners();
  }

  /// Returns how many of [videoIds] were newly added (duplicates skipped).
  Future<int> addVideosToPlaylist(int playlistId, List<int> videoIds) async {
    final added = await _db.addVideosToPlaylist(playlistId, videoIds);
    notifyListeners();
    return added;
  }

  Future<void> removeVideoFromPlaylist(int playlistId, int videoId) async {
    await _db.removeVideoFromPlaylist(playlistId, videoId);
    notifyListeners();
  }

  Future<List<VideoEntity>> getVideosInPlaylist(int playlistId) => _db.getVideosInPlaylist(playlistId);

  AppPrefs get prefs => _prefs;
}
