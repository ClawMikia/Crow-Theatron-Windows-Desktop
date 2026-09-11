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
class VideoRepository {
  VideoRepository(this._db, this._prefs);
  final CrowDatabase _db;
  final AppPrefs _prefs;

  static Future<VideoRepository> create() async {
    final prefs = await AppPrefs.getInstance();
    return VideoRepository(CrowDatabase.instance, prefs);
  }

  // ── Scanning / import ────────────────────────────────────────────────

  Future<void> importScanResults(List<VideoEntity> entities) async {
    for (final e in entities) {
      final prepared = e.copyWith(
        seekJumpSec: _prefs.defaultSeekJumpSec,
        enhancement: _prefs.defaultEnhancement,
      );
      await _db.insertOrMergeFromScan(prepared);
    }
  }

  Future<void> deleteVideo(int id) => _db.deleteById(id);

  // ── Queries ──────────────────────────────────────────────────────────

  Future<VideoEntity?> getById(int id) => _db.getById(id);
  Future<List<VideoEntity>> listAllByFolder() => _db.listAllOrderedByFolder();
  Future<List<VideoEntity>> listFavorites() => _db.listFavorites();
  Future<List<VideoEntity>> listPlaybackMemory() => _db.listPlaybackMemory();
  Future<List<VideoEntity>> listContinueWatching() => _db.listContinueWatching();
  Future<List<VideoEntity>> listRecentlyPlayed({int limit = 20}) => _db.listRecentlyPlayed(limit: limit);
  Future<List<VideoEntity>> search(String query) => _db.searchByTitle(query);

  Future<void> savePlaybackPosition(int id, int positionMs) => _db.updatePlaybackState(id, positionMs);
  Future<void> savePreferences(VideoEntity e) => _db.updatePreferences(e);
  Future<void> setFavorite(int id, bool favorite) => _db.setFavorite(id, favorite);

  // ── Chapters ─────────────────────────────────────────────────────────

  Future<int> addChapter(int videoId, int positionMs, String label, {bool auto = false}) => _db.insertChapter(
        ChapterMarker(
          videoId: videoId,
          positionMs: positionMs,
          label: label,
          isAutoDetected: auto,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
  Future<void> deleteChapter(int id) => _db.deleteChapter(id);
  Future<void> deleteAllChapters(int videoId) => _db.deleteChaptersForVideo(videoId);
  Future<List<ChapterMarker>> listChapters(int videoId) => _db.listChaptersForVideo(videoId);

  // ── Timeline skips ───────────────────────────────────────────────────

  Future<int> addSkip(int videoId, int startMs, int endMs, {String label = 'Skip'}) => _db.insertSkip(
        TimelineSkip(
          videoId: videoId,
          startMs: startMs,
          endMs: endMs,
          label: label,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
  Future<void> deleteSkip(int id) => _db.deleteSkip(id);
  Future<void> deleteAllSkips(int videoId) => _db.deleteSkipsForVideo(videoId);
  Future<List<TimelineSkip>> listSkips(int videoId) => _db.listSkipsForVideo(videoId);

  // ── Playlists ────────────────────────────────────────────────────────

  Future<int> createPlaylist(String title) => _db.insertPlaylist(title);
  Future<void> deletePlaylist(int id) => _db.deletePlaylist(id);
  Future<void> renamePlaylist(int id, String newTitle) => _db.renamePlaylist(id, newTitle);
  Future<List<Playlist>> listPlaylists() => _db.listPlaylists();
  Future<void> addVideoToPlaylist(int playlistId, int videoId) => _db.addVideoToPlaylist(playlistId, videoId);
  Future<void> removeVideoFromPlaylist(int playlistId, int videoId) =>
      _db.removeVideoFromPlaylist(playlistId, videoId);
  Future<List<VideoEntity>> getVideosInPlaylist(int playlistId) => _db.getVideosInPlaylist(playlistId);

  AppPrefs get prefs => _prefs;
}
