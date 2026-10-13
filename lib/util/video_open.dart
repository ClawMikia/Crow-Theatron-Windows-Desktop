import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/video_entity.dart';
import '../screens/player_screen.dart';

/// Opens [video] in the full player. If its file has been deleted or
/// moved on disk, the library entry is deliberately KEPT (nothing in the
/// app ever removes a video just because its file is gone) and the user
/// gets a clear message instead of a broken player.
Future<void> openVideoPlayer(BuildContext context, VideoEntity video, List<VideoEntity> siblings) async {
  if (!kIsWeb) {
    // Check internal copy first (persists even if original is deleted)
    String? playbackPath = video.internalUriString;
    bool exists = false;
    
    if (playbackPath != null) {
      try {
        exists = await File(playbackPath).exists();
      } catch (_) {}
    }
    
    // Fall back to original path if no internal copy or it doesn't exist
    if (!exists) {
      try {
        exists = await File(video.uriString).exists();
        if (exists) {
          playbackPath = video.uriString;
        }
      } catch (_) {}
    }
    
    if (!exists) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(
              '"${video.title}" wasn\'t found on disk (${video.uriString}). '
              'It stays in your library — restore the file to play it again.',
            ),
          ),
        );
      }
      return;
    }
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PlayerScreen(videoId: video.id, siblingQueue: siblings)),
  );
}
