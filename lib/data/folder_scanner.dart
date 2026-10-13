import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/video_entity.dart';

/// Port of `data/FolderScanner.kt`. Walks a real filesystem directory
/// (Windows desktop) instead of a SAF tree Uri.
class FolderScanner {
  FolderScanner._();

  static const videoExtensions = {
    'mp4', 'mkv', 'webm', 'avi', 'mov', 'm4v', '3gp', '3g2', 'wmv', 'flv', 'ts', 'mts', 'm2ts', 'ogv', 'mpeg', 'mpg'
  };

  static bool isVideoFile(String fileName) {
    final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    return videoExtensions.contains(ext);
  }

  /// Gets the internal videos directory where persistent copies are stored.
  static Future<String> _getInternalVideosDir() async {
    final appDir = await getApplicationSupportDirectory();
    final videosDir = Directory(p.join(appDir.path, 'videos'));
    if (!await videosDir.exists()) {
      await videosDir.create(recursive: true);
    }
    return videosDir.path;
  }

  /// Copies a video file to internal storage and returns the internal path.
  /// Returns null if copy fails.
  static Future<String?> _copyToInternalStorage(String sourcePath) async {
    try {
      final internalDir = await _getInternalVideosDir();
      final fileName = p.basename(sourcePath);
      final internalPath = p.join(internalDir, fileName);
      
      // If file already exists with same size, skip copy
      final sourceFile = File(sourcePath);
      final internalFile = File(internalPath);
      if (await internalFile.exists()) {
        final sourceSize = await sourceFile.length();
        final internalSize = await internalFile.length();
        if (sourceSize == internalSize) {
          return internalPath;
        }
      }
      
      await sourceFile.copy(internalPath);
      return internalPath;
    } catch (e) {
      // If copy fails, return null and fall back to original path
      return null;
    }
  }

  /// Recursively scans [rootPath], grouping by relative folder path —
  /// same grouping behaviour as the Android `DocumentFile` tree walk.
  static Future<List<VideoEntity>> scanDirectory(String rootPath) async {
    final root = Directory(rootPath);
    if (!await root.exists()) return [];
    final out = <VideoEntity>[];

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!isVideoFile(name)) continue;
      int size = 0;
      try {
        size = await entity.length();
      } catch (_) {}
      final relDir = p.relative(p.dirname(entity.path), from: rootPath);
      final folderGroup = relDir == '.' ? p.basename(rootPath) : '${p.basename(rootPath)}/$relDir';
      
      // Copy to internal storage for persistence
      final internalPath = await _copyToInternalStorage(entity.path);
      
      out.add(VideoEntity(
        uriString: entity.path,
        internalUriString: internalPath,
        title: name,
        folderGroup: folderGroup,
        sizeBytes: size,
      ));
    }
    return out;
  }

  /// Resolves individually-picked files (mirrors `resolveUris`).
  static Future<List<VideoEntity>> resolveFiles(List<String> paths) async {
    final out = <VideoEntity>[];
    for (final path in paths) {
      final file = File(path);
      int size = 0;
      try {
        size = await file.length();
      } catch (_) {}
      
      // Copy to internal storage for persistence
      final internalPath = await _copyToInternalStorage(path);
      
      out.add(VideoEntity(
        uriString: path,
        internalUriString: internalPath,
        title: p.basename(path),
        folderGroup: 'Imported Files',
        sizeBytes: size,
      ));
    }
    return out;
  }
}
