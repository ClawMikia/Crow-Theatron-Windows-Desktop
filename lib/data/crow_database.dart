import 'dart:io' show Platform;
import 'dart:typed_data';
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
  static const dbVersion = 9;

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
          await db.execute(_createThumbnails);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 9) {
            // v9: persist the Sequential/Random choice + cache thumbnails.
            try {
              await db.execute('ALTER TABLE videos ADD COLUMN shuffle_playlist INTEGER NOT NULL DEFAULT 0');
            } catch (_) {/* column already there */}
            await db.execute(_createThumbnails);
          }
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
      shuffle_playlist INTEGER NOT NULL DEFAULT 0,
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

  /// Thumbnails live in their own table so `SELECT * FROM videos` list
  /// queries never drag image blobs along with them.
  static const _createThumbnails = '''
    CREATE TABLE IF NOT EXISTS video_thumbnails (
      video_id INTEGER PRIMARY KEY,
      data BLOB NOT NULL
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
          // folder_group is intentionally NOT overwritten: the user may have
          // moved this video to another library folder, and re-importing
          // must not undo that.
          if (e.durationMs > 0) 'duration_ms': e.durationMs,
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

  Future<void> deleteById(int id) => deleteByIds([id]);

  /// Removes videos from the LIBRARY only (files on disk are never
  /// touched), together with everything hanging off them.
  Future<void> deleteByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final chunk in _chunks(ids)) {
        final ph = List.filled(chunk.length, '?').join(',');
        await txn.delete('videos', where: 'id IN ($ph)', whereArgs: chunk);
        await txn.delete('chapter_markers', where: 'video_id IN ($ph)', whereArgs: chunk);
        await txn.delete('timeline_skips', where: 'video_id IN ($ph)', whereArgs: chunk);
        await txn.delete('playlist_videos', where: 'video_id IN ($ph)', whereArgs: chunk);
        await txn.delete('video_thumbnails', where: 'video_id IN ($ph)', whereArgs: chunk);
      }
    });
  }

  Iterable<List<int>> _chunks(List<int> ids, [int size = 500]) sync* {
    for (var i = 0; i < ids.length; i += size) {
      yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
    }
  }

  Future<List<int>> idsInFolder(String folder) async {
    final db = await database;
    final rows = await db.query('videos', columns: ['id'], where: 'folder_group = ?', whereArgs: [folder]);
    return rows.map((r) => r['id'] as int).toList();
  }

  Future<List<String>> listFolders() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT DISTINCT folder_group FROM videos ORDER BY folder_group COLLATE NOCASE ASC');
    return rows.map((r) => r['folder_group'] as String).toList();
  }

  /// Library-only "move": just re-labels the videos' folder.
  Future<void> moveToFolder(List<int> ids, String folder) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final chunk in _chunks(ids)) {
        final ph = List.filled(chunk.length, '?').join(',');
        await txn.update('videos', {'folder_group': folder}, where: 'id IN ($ph)', whereArgs: chunk);
      }
    });
  }

  Future<void> resetLibrary() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('videos');
      await txn.delete('chapter_markers');
      await txn.delete('timeline_skips');
      await txn.delete('playlist_videos');
      await txn.delete('video_thumbnails');
    });
  }

  // ── Thumbnails ─────────────────────────────────────────────────────────

  Future<Uint8List?> getThumbnail(int id) async {
    final db = await database;
    final rows = await db.query('video_thumbnails', columns: ['data'], where: 'video_id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final v = rows.first['data'];
    if (v is Uint8List) return v;
    if (v is List<int>) return Uint8List.fromList(v);
    return null;
  }

  Future<void> setThumbnail(int id, Uint8List bytes) async {
    final db = await database;
    await db.insert('video_thumbnails', {'video_id': id, 'data': bytes}, conflictAlgorithm: ffi.ConflictAlgorithm.replace);
  }

  /// (id, path) of every video that has no cached thumbnail yet.
  Future<List<(int, String)>> listMissingThumbnails() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT v.id AS id, v.uri AS uri FROM videos v
      LEFT JOIN video_thumbnails t ON t.video_id = v.id
      WHERE t.video_id IS NULL
      ORDER BY v.id DESC
    ''');
    return rows.map((r) => (r['id'] as int, r['uri'] as String)).toList();
  }

  Future<void> updateDuration(int id, int durationMs) async {
    final db = await database;
    await db.update('videos', {'duration_ms': durationMs}, where: 'id = ? AND duration_ms = 0', whereArgs: [id]);
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

  Future<void> updateSkip(TimelineSkip s) async {
    final db = await database;
    await db.update('timeline_skips', {'start_ms': s.startMs, 'end_ms': s.endMs, 'label': s.label},
        where: 'id = ?', whereArgs: [s.id]);
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

  Future<void> addVideoToPlaylist(int playlistId, int videoId) => addVideosToPlaylist(playlistId, [videoId]);

  /// Adds [videoIds] to a playlist, skipping ones already in it.
  /// Returns how many were actually added.
  Future<int> addVideosToPlaylist(int playlistId, List<int> videoIds) async {
    final db = await database;
    var added = 0;
    await db.transaction((txn) async {
      final existing = (await txn.query('playlist_videos', columns: ['video_id'], where: 'playlist_id = ?', whereArgs: [playlistId]))
          .map((r) => r['video_id'] as int)
          .toSet();
      final maxRow = await txn.rawQuery('SELECT MAX(position) AS m FROM playlist_videos WHERE playlist_id = ?', [playlistId]);
      var pos = ((maxRow.first['m'] as int?) ?? -1) + 1;
      for (final id in videoIds) {
        if (existing.contains(id)) continue;
        await txn.insert('playlist_videos', {'playlist_id': playlistId, 'video_id': id, 'position': pos++});
        existing.add(id);
        added++;
      }
    });
    return added;
  }

  Future<void> removeVideoFromPlaylist(int playlistId, int videoId) async {
    final db = await database;
    await db.delete('playlist_videos',
        where: 'playlist_id = ? AND video_id = ?', whereArgs: [playlistId, videoId]);
  }

  /// Every playlist plus how many videos it holds, in one query (used
  /// by the Playlists screen so opening it never does N follow-up
  /// queries for N playlists).
  Future<List<(Playlist, int)>> listPlaylistsWithCounts() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT p.*, COUNT(pv.video_id) AS video_count
      FROM playlists p
      LEFT JOIN playlist_videos pv ON pv.playlist_id = p.id
      GROUP BY p.id
      ORDER BY p.created_at DESC
    ''');
    return rows.map((r) => (Playlist.fromMap(r), (r['video_count'] as int?) ?? 0)).toList();
  }

  /// Library videos that are NOT already in [playlistId] — the source
  /// list for "Add videos to playlist".
  Future<List<VideoEntity>> listVideosNotInPlaylist(int playlistId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT v.* FROM videos v
      WHERE v.id NOT IN (SELECT video_id FROM playlist_videos WHERE playlist_id = ?)
      ORDER BY v.title COLLATE NOCASE ASC
    ''', [playlistId]);
    return rows.map(VideoEntity.fromMap).toList();
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
