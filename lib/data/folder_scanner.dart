import 'dart:io';
import 'package:path/path.dart' as p;
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
      out.add(VideoEntity(
        uriString: entity.path,
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
      out.add(VideoEntity(
        uriString: path,
        title: p.basename(path),
        folderGroup: 'Imported Files',
        sizeBytes: size,
      ));
    }
    return out;
  }
}
