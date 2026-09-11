import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart' as ffi_web;

import '../models/chapter_marker.dart';
import '../models/playlist.dart';
import '../models/timeline_skip.dart';
import '../models/video_entity.dart';

/// Port of `data/CrowDbHelper.kt`. Table/column names are kept identical
/// to the Android schema so exported libraries stay portable.
class CrowDatabase {
  CrowDatabase._();
  static final CrowDatabase instance = CrowDatabase._();

  static const dbName = 'crow_theatron.db';
  static const dbVersion = 8;

  ffi.Database? _db;

  Future<ffi.Database> get database async => _db ??= await _open();

  Future<ffi.Database> _open() async {
    ffi.DatabaseFactory factory;
    String path;
    if (kIsWeb) {
      factory = ffi_web.databaseFactoryFfiWeb;
      path = dbName;
    } else {
      ffi.sqfliteFfiInit();
      factory = ffi.databaseFactoryFfi;
      final dir = await getApplicationSupportDirectory();
      path = p.join(dir.path, dbName);
    }
    return factory.openDatabase(
      path,
      options: ffi.OpenDatabaseOptions(
        version: dbVersion,
        onCreate: (db, version) async {
          await db.execute(_createVideos);
          await db.execute('CREATE INDEX idx_videos_folder ON videos(folder_group)');
          await db.execute('CREATE INDEX idx_videos_favorite ON videos(favorite)');
          await db.execute('CREATE INDEX idx_videos_played ON videos(last_played_at)');
          await db.execute(_createChapters);
          await db.execute('CREATE INDEX idx_chapters_video ON chapter_markers(video_id)');
          await db.execute(_createPlaylists);
          await db.execute(_createPlaylistVideos);
          await db.execute(_createSkips);
          await db.execute('CREATE INDEX idx_skips_video ON timeline_skips(video_id)');
        },
      ),
    );
  }

  static const _createVideos = '''
    CREATE TABLE videos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uri TEXT NOT NULL UNIQUE,
      source_uri TEXT,
      title TEXT NOT NULL,
      folder_group TEXT NOT NULL,
      duration_ms INTEGER NOT NULL DEFAULT 0,
      size_bytes INTEGER NOT NULL DEFAULT 0,
      thumbnail BLOB,
      position_ms INTEGER NOT NULL DEFAULT 0,
      pitch_semitones INTEGER NOT NULL DEFAULT 0,
      trim_start_ms INTEGER NOT NULL DEFAULT 0,
      trim_end_ms INTEGER NOT NULL DEFAULT 0,
      favorite INTEGER NOT NULL DEFAULT 0,
      seek_jump_sec INTEGER NOT NULL DEFAULT 10,
      auto_play_next INTEGER NOT NULL DEFAULT 0,
      loop_playback INTEGER NOT NULL DEFAULT 0,
      enhancement TEXT NOT NULL DEFAULT 'NONE',
      last_played_at INTEGER NOT NULL DEFAULT 0,
      playback_speed REAL NOT NULL DEFAULT 1.0,
      volume_level REAL NOT NULL DEFAULT 1.0,
      brightness REAL NOT NULL DEFAULT 0.0,
      contrast REAL NOT NULL DEFAULT 1.0,
      saturation REAL NOT NULL DEFAULT 1.0,
      hue REAL NOT NULL DEFAULT 0.0,
      sharpness REAL NOT NULL DEFAULT 0.0,
      zoom_level REAL NOT NULL DEFAULT 1.0,
      crop_mode TEXT NOT NULL DEFAULT 'FIT',
      audio_boost REAL NOT NULL DEFAULT 1.0,
      eq_preset TEXT NOT NULL DEFAULT 'FLAT',
      subtitle_track INTEGER NOT NULL DEFAULT -1,
      subtitle_offset_ms INTEGER NOT NULL DEFAULT 0,
      subtitle_size_sp REAL NOT NULL DEFAULT 16.0,
      subtitle_bold INTEGER NOT NULL DEFAULT 0,
      subtitle_bg_alpha INTEGER NOT NULL DEFAULT 128,
      preferred_orientation INTEGER NOT NULL DEFAULT -1
    )
  ''';

  static const _createChapters = '''
    CREATE TABLE chapter_markers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      video_id INTEGER NOT NULL,
      position_ms INTEGER NOT NULL,
      label TEXT NOT NULL,
      is_auto INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    )
  ''';

  static const _createSkips = '''
    CREATE TABLE timeline_skips (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      video_id INTEGER NOT NULL,
      start_ms INTEGER NOT NULL,
      end_ms INTEGER NOT NULL,
      label TEXT NOT NULL DEFAULT 'Skip',
      created_at INTEGER NOT NULL
    )
  ''';

  static const _createPlaylists = '''
    CREATE TABLE playlists (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
  ''';

  static const _createPlaylistVideos = '''
    CREATE TABLE playlist_videos (
      playlist_id INTEGER NOT NULL,
      video_id INTEGER NOT NULL,
      position INTEGER NOT NULL DEFAULT 0
    )
  ''';

  // ── Videos ─────────────────────────────────────────────────────────────

  Future<int?> getIdByUri(String uri) async {
    final db = await database;
    final rows = await db.query('videos', columns: ['id'], where: 'uri = ?', whereArgs: [uri]);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  Future<int?> getIdBySourceUri(String sourceUri) async {
    final db = await database;
    final rows =
        await db.query('videos', columns: ['id'], where: 'source_uri = ?', whereArgs: [sourceUri]);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  Future<int> insertOrMergeFromScan(VideoEntity e) async {
    final db = await database;
    final existingId = await getIdBySourceUri(e.sourceUriString ?? e.uriString) ?? await getIdByUri(e.uriString);
    if (existingId != null) {
      await db.update(
        'videos',
        {
          'title': e.title,
          'folder_group': e.folderGroup,
          'duration_ms': e.durationMs,
          'size_bytes': e.sizeBytes,
        },
        where: 'id = ?',
        whereArgs: [existingId],
      );
      return existingId;
    }
    return db.insert('videos', e.toMap());
  }

  Future<void> updatePlaybackState(int id, int positionMs, {int? lastPlayedAt}) async {
    final db = await database;
    await db.update(
      'videos',
      {'position_ms': positionMs, 'last_played_at': lastPlayedAt ?? DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updatePreferences(VideoEntity e) async {
    final db = await database;
    final m = e.toMap()..remove('id')..remove('uri')..remove('source_uri')..remove('folder_group')..remove('size_bytes')..remove('last_played_at')..remove('position_ms');
    await db.update('videos', m, where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> setFavorite(int id, bool favorite) async {
    final db = await database;
    await db.update('videos', {'favorite': favorite ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<VideoEntity?> getById(int id) async {
    final db = await database;
    final rows = await db.query('videos', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : VideoEntity.fromMap(rows.first);
  }

  Future<List<VideoEntity>> listAllOrderedByFolder() async {
    final db = await database;
    final rows = await db.query('videos', orderBy: 'folder_group COLLATE NOCASE ASC, title COLLATE NOCASE ASC');
    return rows.map(VideoEntity.fromMap).toList();
  }

  Future<List<VideoEntity>> listFavorites() async {
    final db = await database;
    final rows = await db.query('videos', where: 'favorite = 1', orderBy: 'last_played_at DESC');
    return rows.map(VideoEntity.fromMap).toList();
  }

  Future<List<VideoEntity>> listContinueWatching() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT * FROM videos
      WHERE position_ms > 5000
      AND duration_ms > 0
      AND CAST(position_ms AS REAL) / duration_ms < 0.95
      ORDER BY last_played_at DESC
    ''');
    return rows.map(VideoEntity.fromMap).toList();
  }

  Future<List<VideoEntity>> listPlaybackMemory() => listContinueWatching();

  Future<List<VideoEntity>> listRecentlyPlayed({int limit = 20}) async {
    final db = await database;
    final rows = await db.query('videos',
        where: 'last_played_at > 0', orderBy: 'last_played_at DESC', limit: limit);
    return rows.map(VideoEntity.fromMap).toList();
  }

  Future<List<VideoEntity>> searchByTitle(String query) async {
    final db = await database;
    final rows = await db.query(
      'videos',
      where: 'title LIKE ? COLLATE NOCASE',
      whereArgs: ['%${query.trim()}%'],
      orderBy: 'folder_group COLLATE NOCASE ASC, title COLLATE NOCASE ASC',
    );
    return rows.map(VideoEntity.fromMap).toList();
  }

  Future<void> deleteById(int id) async {
    final db = await database;
    await db.delete('videos', where: 'id = ?', whereArgs: [id]);
  }

  // ── Chapters ───────────────────────────────────────────────────────────

  Future<int> insertChapter(ChapterMarker c) async {
    final db = await database;
    return db.insert('chapter_markers', c.toMap());
  }

  Future<void> deleteChapter(int id) async {
    final db = await database;
    await db.delete('chapter_markers', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteChaptersForVideo(int videoId) async {
    final db = await database;
    await db.delete('chapter_markers', where: 'video_id = ?', whereArgs: [videoId]);
  }

  Future<List<ChapterMarker>> listChaptersForVideo(int videoId) async {
    final db = await database;
    final rows =
        await db.query('chapter_markers', where: 'video_id = ?', whereArgs: [videoId], orderBy: 'position_ms ASC');
    return rows.map(ChapterMarker.fromMap).toList();
  }

  // ── Timeline skips ─────────────────────────────────────────────────────

  Future<int> insertSkip(TimelineSkip s) async {
    final db = await database;
    return db.insert('timeline_skips', s.toMap());
  }

  Future<void> deleteSkip(int id) async {
    final db = await database;
    await db.delete('timeline_skips', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSkipsForVideo(int videoId) async {
    final db = await database;
    await db.delete('timeline_skips', where: 'video_id = ?', whereArgs: [videoId]);
  }

  Future<List<TimelineSkip>> listSkipsForVideo(int videoId) async {
    final db = await database;
    final rows =
        await db.query('timeline_skips', where: 'video_id = ?', whereArgs: [videoId], orderBy: 'start_ms ASC');
    return rows.map(TimelineSkip.fromMap).toList();
  }

  // ── Playlists ──────────────────────────────────────────────────────────

  Future<int> insertPlaylist(String title) async {
    final db = await database;
    return db.insert('playlists', {'title': title, 'created_at': DateTime.now().millisecondsSinceEpoch});
  }

  Future<void> deletePlaylist(int id) async {
    final db = await database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
    await db.delete('playlist_videos', where: 'playlist_id = ?', whereArgs: [id]);
  }

  Future<void> renamePlaylist(int id, String newTitle) async {
    final db = await database;
    await db.update('playlists', {'title': newTitle}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addVideoToPlaylist(int playlistId, int videoId) async {
    final db = await database;
    await db.insert('playlist_videos', {'playlist_id': playlistId, 'video_id': videoId, 'position': 0});
  }

  Future<void> removeVideoFromPlaylist(int playlistId, int videoId) async {
    final db = await database;
    await db.delete('playlist_videos',
        where: 'playlist_id = ? AND video_id = ?', whereArgs: [playlistId, videoId]);
  }

  Future<List<Playlist>> listPlaylists() async {
    final db = await database;
    final rows = await db.query('playlists', orderBy: 'title ASC');
    return rows.map(Playlist.fromMap).toList();
  }

  Future<List<VideoEntity>> getVideosInPlaylist(int playlistId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT v.* FROM videos v
      JOIN playlist_videos pv ON v.id = pv.video_id
      WHERE pv.playlist_id = ?
      ORDER BY pv.position ASC
    ''', [playlistId]);
    return rows.map(VideoEntity.fromMap).toList();
  }
}

/// True when running on a platform without a real filesystem (web).
bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
