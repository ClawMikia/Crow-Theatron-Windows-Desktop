import 'package:flutter/material.dart';
import '../data/video_repository.dart';
import '../models/video_entity.dart';
import '../theme/crow_colors.dart';
import '../widgets/crow_scaffold.dart';
import '../widgets/section_header.dart';
import '../widgets/video_tiles.dart';
import 'main_screen.dart';
import 'player_screen.dart';
import '../widgets/keyboard_accessible.dart';

enum LibraryMode { all, favorites, continueWatching, recentlyPlayed, playlist }

/// Port of `activity_library.xml` + `library/LibraryActivity.kt` +
/// `ui/LibraryAdapter.kt`. Restructured for desktop: MODE_ALL shows a
/// folder list panel on the left with a wide responsive grid on the
/// right (instead of collapsible in-list folder headers); other modes
/// show a flat wide grid/list. Used two ways: embedded directly in
/// [AppShell] (a sidebar destination — no back button), or pushed
/// standalone on top of it (a playlist's video list — has a back button).
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.mode,
    this.playlistId,
    this.playlistName,
    this.standalone = false,
  });

  final LibraryMode mode;
  final int? playlistId;
  final String? playlistName;
  final bool standalone;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<VideoEntity> _videos = [];
  bool _grid = true;
  String? _selectedFolder; // null = "All folders"
  bool _loading = true;
  late VideoRepository _repo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _repo = repoOf(context);
      _load();
      _repo.addListener(_onRepoChanged);
    });
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    List<VideoEntity> videos;
    switch (widget.mode) {
      case LibraryMode.favorites:
        videos = await _repo.listFavorites();
        break;
      case LibraryMode.continueWatching:
        videos = await _repo.listContinueWatching();
        break;
      case LibraryMode.recentlyPlayed:
        videos = await _repo.listRecentlyPlayed();
        break;
      case LibraryMode.playlist:
        videos = await _repo.getVideosInPlaylist(widget.playlistId!);
        break;
      case LibraryMode.all:
        videos = await _repo.listAllByFolder();
      break;
    }
    if (mounted) setState(() { _videos = videos; _loading = false; });
  }

  String get _title {
    switch (widget.mode) {
      case LibraryMode.favorites:
        return 'Favorites';
      case LibraryMode.continueWatching:
        return 'Continue Watching';
      case LibraryMode.recentlyPlayed:
        return 'Playback Memory';
      case LibraryMode.playlist:
        return widget.playlistName ?? 'Playlist';
      case LibraryMode.all:
        return 'Library';
    }
  }

  Future<void> _openVideo(VideoEntity v, List<VideoEntity> siblings) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(videoId: v.id, siblingQueue: siblings)),
    );
    _load();
  }

  Future<void> _delete(VideoEntity v) async {
    if (widget.mode == LibraryMode.playlist) {
      await repoOf(context).removeVideoFromPlaylist(widget.playlistId!, v.id);
      _load();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CrowColors.surfaceElevated,
        title: const Text('Delete Video', style: TextStyle(color: CrowColors.onBg)),
        content: const Text('Are you sure you want to delete this video from the library?',
            style: TextStyle(color: CrowColors.onMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: CrowColors.accentRed))),
        ],
      ),
    );
    if (confirmed == true) {
      await repoOf(context).deleteVideo(v.id);
      _load();
    }
  }

  Map<String, List<VideoEntity>> get _grouped {
    final map = <String, List<VideoEntity>>{};
    for (final v in _videos) {
      map.putIfAbsent(v.folderGroup, () => []).add(v);
    }
    return map;
  }

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: CrowColors.accentYellow));
    }
    if (_videos.isEmpty) {
      return const Center(
        child: Text('No videos yet. Pick a folder from Home.', style: TextStyle(color: CrowColors.onMuted)),
      );
    }

    final header = SectionHeader(
      title: _title,
      actions: [
        IconButton(
          icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded, color: CrowColors.onBg),
          tooltip: 'Toggle view',
          onPressed: () => setState(() => _grid = !_grid),
        ),
      ],
    );

    if (widget.mode != LibraryMode.all) {
      return Column(
        children: [
          header,
          Expanded(child: _buildFlat(_videos)),
        ],
      );
    }

    // MODE_ALL — folder panel + grid.
    final groups = _grouped;
    final folders = groups.keys.toList()..sort();
    final shown = _selectedFolder == null ? _videos : (groups[_selectedFolder] ?? []);

    return Column(
      children: [
        header,
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 230,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _FolderTile(
                      label: 'All folders',
                      count: _videos.length,
                      selected: _selectedFolder == null,
                      onTap: () => setState(() => _selectedFolder = null),
                    ),
                    for (final f in folders)
                      _FolderTile(
                        label: f,
                        count: groups[f]!.length,
                        selected: _selectedFolder == f,
                        onTap: () => setState(() => _selectedFolder = f),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1, color: CrowColors.divider),
              Expanded(child: _buildFlat(shown)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlat(List<VideoEntity> videos) {
    if (_grid) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: crowVideoGridDelegate,
        itemCount: videos.length,
        itemBuilder: (context, i) => VideoGridCard(
          video: videos[i],
          onTap: () => _openVideo(videos[i], videos),
          onRemove: () => _delete(videos[i]),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: videos.length,
      itemBuilder: (context, i) => VideoListRow(
        video: videos[i],
        onTap: () => _openVideo(videos[i], videos),
        onRemove: () => _delete(videos[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _content();
    if (!widget.standalone) return body;
    return CrowScaffold(
      toolbar: CrowToolbar(title: _title, titleColor: CrowColors.accentYellow),
      body: body,
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.label, required this.count, required this.selected, required this.onTap});
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? CrowColors.accentYellow : CrowColors.onBg;
    return FocusableInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      semanticsLabel: '$label, $count videos',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: selected ? CrowColors.accentYellow.withValues(alpha: 0.1) : null),
        child: Row(
          children: [
            Icon(Icons.folder_rounded, size: 16, color: selected ? CrowColors.accentYellow : CrowColors.onMuted),
            const SizedBox(width: 10),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 13))),
            Text('$count', style: const TextStyle(color: CrowColors.onMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
