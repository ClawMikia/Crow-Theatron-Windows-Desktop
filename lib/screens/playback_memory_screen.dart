import 'package:flutter/material.dart';
import 'library_screen.dart';

/// Port of `memory/PlaybackMemoryActivity.kt` — same list rendering as
/// [LibraryScreen], scoped to videos with unfinished playback progress.
class PlaybackMemoryScreen extends StatelessWidget {
  const PlaybackMemoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LibraryScreen(mode: LibraryMode.continueWatching);
  }
}
