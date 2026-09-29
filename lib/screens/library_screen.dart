import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/video_repository.dart';
import '../models/video_entity.dart';
import '../shortcuts/app_shortcuts.dart' show isTextInputActive;
import '../theme/crow_colors.dart';
import '../util/video_open.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/crow_scaffold.dart';
import '../widgets/keyboard_accessible.dart';
import '../widgets/library_actions.dart';
import '../widgets/section_header.dart';
import '../widgets/video_tiles.dart';

enum LibraryMode { all, favorites, continueWatching, recentlyPlayed, playlist }

/// Port of `activity_library.xml` + `library/LibraryActivity.kt` +
/// `ui/LibraryAdapter.kt`. Restructured for desktop: MODE_ALL shows a
/// folder list panel on the left with a wide responsive grid on the
/// right (instead of collapsible in-list folder headers); other modes
/// show a flat wide grid/list. Used two ways: embedded directly in
/// [AppShell] (a sidebar destination — no back button), or pushed
/// standalone on top of it (a playlist's video list — has a back button).
///
/// Every mode supports "select many": pick videos (or Select all /
/// Ctrl+A) and then move them to a folder, add them to a playlist, or
/// delete them.
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
  late final VideoRepository _repo;
  final SelectionController _selection = SelectionController();
  final FocusNode _focus = FocusNode(debugLabel: 'library-selection');
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _repo = context.read<VideoRepository>();
    _selection.addListener(_onSelectionChanged);
    _repo.addListener(_onRepoChanged);
    _load();
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoChanged);
    _selection.removeListener(_onSelectionChanged);
    _selection.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  /// Any change to the library (an import — even one still running —,
  /// a delete, a move, a reset…) lands here and reloads this view.
  void _onRepoChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    // Guards against out-of-order results: if two reloads overlap, only
    // the newest one is allowed to update the screen.
    final token = ++_loadToken;
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
    if (!mounted || token != _loadToken) return;
    setState(() {
      _videos = videos;
      _loading = false;
      // A folder that no longer exists (deleted / emptied by a move).
      if (_selectedFolder != null && !videos.any((v) => v.folderGroup == _selectedFolder)) {
        _selectedFolder = null;
      }
    });
    _selection.retainOnly(videos.map((v) => v.id).toSet());
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

  /// The videos currently on screen (respects the selected folder).
  List<VideoEntity> get _visible {
    if (widget.mode == LibraryMode.all && _selectedFolder != null) {
      return _videos.where((v) => v.folderGroup == _selectedFolder).toList();
    }
    return _videos;
  }

  // ── Opening / single delete ──────────────────────────────────────────

  Future<void> _tapVideo(VideoEntity v, List<VideoEntity> siblings) async {
    if (_selection.active) {
      _selection.toggle(v.id);
      return;
    }
    await openVideoPlayer(context, v, siblings);
    if (mounted) _load();
  }

  void _longPressVideo(VideoEntity v) {
    _selection.toggle(v.id);
    _focus.requestFocus();
  }

  Future<void> _delete(VideoEntity v) async {
    if (widget.mode == LibraryMode.playlist) {
      final ok = await confirmDestructive(
        context,
        title: 'Remove from playlist?',
        message: '"${v.title}" will be removed from this playlist. The video stays in your library.',
        confirmLabel: 'Remove',
      );
      if (!ok || !mounted) return;
      await _repo.removeVideoFromPlaylist(widget.playlistId!, v.id);
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
      await _repo.deleteVideo(v.id);
      _load();
    }
  }

  // ── Folders ──────────────────────────────────────────────────────────

  Future<void> _deleteFolder(String folder, int count) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete folder "$folder"?',
      message: 'This removes the folder and its $count video${count == 1 ? '' : 's'} from your library, '
          'along with their chapters, skips and playlist entries. The files on your PC are not touched.',
      confirmLabel: 'Delete folder',
    );
    if (!ok || !mounted) return;
    if (_selectedFolder == folder) setState(() => _selectedFolder = null);
    final n = await _repo.deleteFolder(folder);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "$folder" ($n video${n == 1 ? '' : 's'}) from the library')),
      );
    }
  }

  // ── Bulk actions ─────────────────────────────────────────────────────

  void _enterSelection() {
    _selection.start();
    _focus.requestFocus();
  }

  Future<void> _addVideosToPlaylist() => showAddVideosToPlaylistPicker(context, _repo, widget.playlistId!);

  Future<void> _bulkMove() async {
    if (await BulkActions.moveToFolder(context, _repo, _selection.ids)) _selection.exit();
  }

  Future<void> _bulkAddToPlaylist() async {
    if (await BulkActions.addToPlaylist(context, _repo, _selection.ids)) _selection.exit();
  }

  Future<void> _bulkDelete() async {
    final ids = _selection.ids;
    if (ids.isEmpty) return;
    if (widget.mode == LibraryMode.playlist) {
      final n = ids.length;
      final ok = await confirmDestructive(
        context,
        title: 'Remove $n video${n == 1 ? '' : 's'} from playlist?',
        message: 'They stay in your library — only their place in this playlist is removed.',
        confirmLabel: 'Remove',
      );
      if (!ok || !mounted) return;
      for (final id in ids) {
        await _repo.removeVideoFromPlaylist(widget.playlistId!, id);
      }
      _selection.exit();
      return;
    }
    if (await BulkActions.deleteFromLibrary(context, _repo, ids)) _selection.exit();
  }

  // ── UI ───────────────────────────────────────────────────────────────

  Map<String, List<VideoEntity>> get _grouped {
    final map = <String, List<VideoEntity>>{};
    for (final v in _videos) {
      map.putIfAbsent(v.folderGroup, () => []).add(v);
    }
    return map;
  }

  Widget _headerOrSelectionBar() {
    if (_selection.active) {
      final visible = _visible;
      return SelectionBar(
        count: _selection.count,
        total: visible.length,
        onSelectAll: () => _selection.selectAll(visible.map((v) => v.id)),
        onClear: _selection.clear,
        onMove: _bulkMove,
        onAddToPlaylist: _bulkAddToPlaylist,
        onDelete: _bulkDelete,
        onDone: _selection.exit,
        deleteLabel: widget.mode == LibraryMode.playlist ? 'Remove from playlist' : 'Delete',
      );
    }
    return SectionHeader(
      title: _title,
      actions: [
        if (widget.mode == LibraryMode.playlist)
          FocusableIconButton(
            icon: const Icon(Icons.playlist_add_rounded, color: CrowColors.accentYellow),
            tooltip: 'Add videos to this playlist',
            semanticsLabel: 'Add videos to this playlist',
            onPressed: _addVideosToPlaylist,
          ),
        FocusableIconButton(
          icon: const Icon(Icons.checklist_rounded, color: CrowColors.onBg),
          tooltip: 'Select videos (Ctrl+A selects all)',
          semanticsLabel: 'Select multiple videos',
          onPressed: _videos.isEmpty ? null : _enterSelection,
        ),
        FocusableIconButton(
          icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded, color: CrowColors.onBg),
          tooltip: 'Toggle view',
          semanticsLabel: 'Toggle grid or list view',
          onPressed: () => setState(() => _grid = !_grid),
        ),
      ],
    );
  }

  Widget _content() {
    // The header (with the grid/list toggle, Select, and — for a
    // playlist — Add videos) used to only render once there were
    // videos to show, so an empty playlist had no way to add anything
    // and no view toggle either. It's now always shown; only the body
    // below it changes.
    final header = _headerOrSelectionBar();

    if (_loading) {
      return Column(children: [header, const Expanded(child: Center(child: CircularProgressIndicator(color: CrowColors.accentYellow)))]);
    }
    if (_videos.isEmpty) {
      return Column(children: [header, Expanded(child: Center(child: _emptyState()))]);
    }

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
    final folders = groups.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final shown = _selectedFolder == null ? _videos : (groups[_selectedFolder] ?? []);

    return Column(
      children: [
        header,
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 250,
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
                        onDelete: () => _deleteFolder(f, groups[f]!.length),
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

  Widget _emptyState() {
    if (widget.mode == LibraryMode.playlist) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.playlist_add_rounded, size: 40, color: CrowColors.onMuted),
          const SizedBox(height: 12),
          const Text('This playlist is empty.', style: TextStyle(color: CrowColors.onMuted)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _addVideosToPlaylist,
            style: FilledButton.styleFrom(backgroundColor: CrowColors.accentYellow, foregroundColor: CrowColors.bg),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add videos'),
          ),
        ],
      );
    }
    return const Text('No videos yet. Pick a folder from Home.', style: TextStyle(color: CrowColors.onMuted));
  }

  Widget _buildFlat(List<VideoEntity> videos) {
    final selecting = _selection.active;
    if (_grid) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: crowVideoGridDelegate,
        itemCount: videos.length,
        itemBuilder: (context, i) => VideoGridCard(
          video: videos[i],
          selectionMode: selecting,
          selected: _selection.isSelected(videos[i].id),
          onTap: () => _tapVideo(videos[i], videos),
          onLongPress: () => _longPressVideo(videos[i]),
          onRemove: () => _delete(videos[i]),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: videos.length,
      itemBuilder: (context, i) => VideoListRow(
        video: videos[i],
        selectionMode: selecting,
        selected: _selection.isSelected(videos[i].id),
        onTap: () => _tapVideo(videos[i], videos),
        onLongPress: () => _longPressVideo(videos[i]),
        onRemove: () => _delete(videos[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = CallbackShortcuts(
      bindings: {
        // Ctrl+A → select every video currently shown (never steals
        // Ctrl+A from a text field).
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () {
          if (isTextInputActive() || _videos.isEmpty) return;
          _selection.selectAll(_visible.map((v) => v.id));
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_selection.active) _selection.exit();
        },
        const SingleActivator(LogicalKeyboardKey.delete): () {
          if (_selection.active && _selection.count > 0) _bulkDelete();
        },
      },
      child: Focus(focusNode: _focus, child: _content()),
    );
    if (!widget.standalone) return body;
    return CrowScaffold(
      toolbar: CrowToolbar(title: _title, titleColor: CrowColors.accentYellow),
      body: body,
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = selected ? CrowColors.accentYellow : CrowColors.onBg;
    return FocusableInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      semanticsLabel: '$label, $count videos',
      child: Container(
        padding: EdgeInsets.only(left: 16, right: onDelete != null ? 4 : 16, top: onDelete != null ? 2 : 10, bottom: onDelete != null ? 2 : 10),
        decoration: BoxDecoration(color: selected ? CrowColors.accentYellow.withValues(alpha: 0.1) : null),
        child: Row(
          children: [
            Icon(Icons.folder_rounded, size: 16, color: selected ? CrowColors.accentYellow : CrowColors.onMuted),
            const SizedBox(width: 10),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 13))),
            Text('$count', style: const TextStyle(color: CrowColors.onMuted, fontSize: 11)),
            if (onDelete != null)
              FocusableIconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: CrowColors.onMuted),
                onPressed: onDelete,
                tooltip: 'Delete folder',
                semanticsLabel: 'Delete folder $label',
                padding: const EdgeInsets.all(6),
              ),
          ],
        ),
      ),
    );
  }
}
