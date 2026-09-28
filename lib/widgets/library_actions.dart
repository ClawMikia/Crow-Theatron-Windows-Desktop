import 'package:flutter/material.dart';

import '../data/video_repository.dart';
import '../theme/crow_colors.dart';
import 'confirm_dialog.dart';

/// Which videos are ticked while a library grid/list is in "select
/// many" mode.
class SelectionController extends ChangeNotifier {
  final Set<int> _ids = {};
  bool _active = false;

  bool get active => _active;
  int get count => _ids.length;
  Set<int> get ids => Set.unmodifiable(_ids);
  bool isSelected(int id) => _ids.contains(id);

  void start([int? firstId]) {
    _active = true;
    if (firstId != null) _ids.add(firstId);
    notifyListeners();
  }

  void toggle(int id) {
    if (!_ids.remove(id)) _ids.add(id);
    _active = true;
    notifyListeners();
  }

  void selectAll(Iterable<int> ids) {
    _active = true;
    _ids
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void clear() {
    _ids.clear();
    notifyListeners();
  }

  void exit() {
    _active = false;
    _ids.clear();
    notifyListeners();
  }

  /// Drop selections for videos that no longer exist in the current view.
  void retainOnly(Set<int> available) {
    final before = _ids.length;
    _ids.removeWhere((id) => !available.contains(id));
    if (_ids.length != before) notifyListeners();
  }
}

/// Toolbar shown in place of a library's header while selecting.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.total,
    required this.onSelectAll,
    required this.onClear,
    required this.onMove,
    required this.onAddToPlaylist,
    required this.onDelete,
    required this.onDone,
    this.deleteLabel = 'Delete',
  });

  final int count;
  final int total;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onMove;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onDelete;
  final VoidCallback onDone;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    final hasSelection = count > 0;
    final allSelected = total > 0 && count == total;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: CrowColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CrowColors.accentYellow.withValues(alpha: 0.6)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          Text(
            hasSelection ? '$count selected' : 'Select videos',
            style: const TextStyle(color: CrowColors.accentYellow, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: allSelected ? onClear : onSelectAll,
            icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded, size: 18),
            label: Text(allSelected ? 'Deselect all' : 'Select all'),
          ),
          TextButton.icon(
            onPressed: hasSelection ? onMove : null,
            icon: const Icon(Icons.drive_file_move_rounded, size: 18),
            label: const Text('Move to folder'),
          ),
          TextButton.icon(
            onPressed: hasSelection ? onAddToPlaylist : null,
            icon: const Icon(Icons.playlist_add_rounded, size: 18),
            label: const Text('Add to playlist'),
          ),
          TextButton.icon(
            onPressed: hasSelection ? onDelete : null,
            style: TextButton.styleFrom(foregroundColor: CrowColors.accentRed),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(deleteLabel),
          ),
          TextButton.icon(
            onPressed: onDone,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// "Move N videos to…" — pick an existing folder or type a new name.
Future<String?> showMoveToFolderDialog(BuildContext context, {required List<String> folders, required int count}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: CrowColors.surfaceElevated,
      title: Text('Move $count video${count == 1 ? '' : 's'} to…', style: const TextStyle(color: CrowColors.onBg)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (folders.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final f in folders)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.folder_rounded, size: 18, color: CrowColors.accentYellow),
                        title: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CrowColors.onBg)),
                        onTap: () => Navigator.pop(ctx, f),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              style: const TextStyle(color: CrowColors.onBg),
              decoration: const InputDecoration(hintText: 'Or type a new folder name', border: OutlineInputBorder()),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final v = controller.text.trim();
            if (v.isNotEmpty) Navigator.pop(ctx, v);
          },
          child: const Text('Create & move', style: TextStyle(color: CrowColors.accentCyan)),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// Result of the playlist picker: either an existing playlist id, or the
/// name of a new one to create.
typedef PlaylistChoice = ({int? id, String? newName});

Future<PlaylistChoice?> showAddToPlaylistDialog(BuildContext context, VideoRepository repo, {required int count}) async {
  final playlists = await repo.listPlaylists();
  if (!context.mounted) return null;
  final controller = TextEditingController();
  final result = await showDialog<PlaylistChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: CrowColors.surfaceElevated,
      title: Text('Add $count video${count == 1 ? '' : 's'} to playlist', style: const TextStyle(color: CrowColors.onBg)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('No playlists yet — create one below.', style: TextStyle(color: CrowColors.onMuted)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in playlists)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.playlist_play_rounded, size: 20, color: CrowColors.accentYellow),
                        title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CrowColors.onBg)),
                        onTap: () => Navigator.pop(ctx, (id: p.id, newName: null)),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              style: const TextStyle(color: CrowColors.onBg),
              decoration: const InputDecoration(hintText: 'Or create a new playlist', border: OutlineInputBorder()),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) Navigator.pop(ctx, (id: null, newName: v.trim()));
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final v = controller.text.trim();
            if (v.isNotEmpty) Navigator.pop(ctx, (id: null, newName: v));
          },
          child: const Text('Create & add', style: TextStyle(color: CrowColors.accentCyan)),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// The three bulk operations, shared by every library-style screen.
/// Each returns true if it actually changed something.
class BulkActions {
  BulkActions._();

  static void _snack(BuildContext context, String text) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static Future<bool> moveToFolder(BuildContext context, VideoRepository repo, Set<int> ids) async {
    final folders = await repo.listFolders();
    if (!context.mounted) return false;
    final target = await showMoveToFolderDialog(context, folders: folders, count: ids.length);
    if (target == null || target.trim().isEmpty) return false;
    await repo.moveVideosToFolder(ids.toList(), target);
    _snack(context, 'Moved ${ids.length} video${ids.length == 1 ? '' : 's'} to "${target.trim()}"');
    return true;
  }

  static Future<bool> addToPlaylist(BuildContext context, VideoRepository repo, Set<int> ids) async {
    final choice = await showAddToPlaylistDialog(context, repo, count: ids.length);
    if (choice == null) return false;
    var playlistId = choice.id;
    var name = '';
    if (playlistId == null) {
      playlistId = await repo.createPlaylist(choice.newName!);
      name = choice.newName!;
    } else {
      final all = await repo.listPlaylists();
      name = all.where((p) => p.id == playlistId).map((p) => p.title).firstOrNull ?? 'playlist';
    }
    final added = await repo.addVideosToPlaylist(playlistId, ids.toList());
    final skipped = ids.length - added;
    _snack(
      context,
      'Added $added video${added == 1 ? '' : 's'} to "$name"'
      '${skipped > 0 ? ' ($skipped already in it)' : ''}',
    );
    return true;
  }

  static Future<bool> deleteFromLibrary(BuildContext context, VideoRepository repo, Set<int> ids) async {
    final n = ids.length;
    final ok = await confirmDestructive(
      context,
      title: 'Delete $n video${n == 1 ? '' : 's'}?',
      message: 'This removes ${n == 1 ? 'it' : 'them'} from your library, along with chapters, skips and playlist entries. '
          'The video files on your PC are not touched.',
    );
    if (!ok) return false;
    await repo.deleteVideos(ids.toList());
    _snack(context, 'Removed $n video${n == 1 ? '' : 's'} from the library');
    return true;
  }
}
