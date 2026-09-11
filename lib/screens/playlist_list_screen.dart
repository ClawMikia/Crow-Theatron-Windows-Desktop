import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../theme/crow_colors.dart';
import '../widgets/section_header.dart';
import 'library_screen.dart';
import 'main_screen.dart';

/// Port of `playlist/PlaylistListActivity.kt` — create, rename, delete,
/// and open user playlists. Embedded directly in [AppShell]'s content
/// area (Playlists sidebar item); opening one pushes a standalone
/// [LibraryScreen] on top with a back button.
class PlaylistListScreen extends StatefulWidget {
  const PlaylistListScreen({super.key});

  @override
  State<PlaylistListScreen> createState() => _PlaylistListScreenState();
}

class _PlaylistListScreenState extends State<PlaylistListScreen> {
  List<Playlist> _playlists = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final list = await repoOf(context).listPlaylists();
    if (mounted) setState(() => _playlists = list);
  }

  Future<void> _create() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CrowColors.surfaceElevated,
        title: const Text('New Playlist', style: TextStyle(color: CrowColors.onBg)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: CrowColors.onBg),
          decoration: const InputDecoration(hintText: 'Playlist name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Create', style: TextStyle(color: CrowColors.accentCyan))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await repoOf(context).createPlaylist(name);
      _load();
    }
  }

  Future<void> _rename(Playlist p) async {
    final controller = TextEditingController(text: p.title);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CrowColors.surfaceElevated,
        title: const Text('Rename Playlist', style: TextStyle(color: CrowColors.onBg)),
        content: TextField(controller: controller, autofocus: true, style: const TextStyle(color: CrowColors.onBg)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await repoOf(context).renamePlaylist(p.id, name);
      _load();
    }
  }

  Future<void> _delete(Playlist p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CrowColors.surfaceElevated,
        title: const Text('Delete Playlist', style: TextStyle(color: CrowColors.onBg)),
        content: Text('Delete "${p.title}"? This does not delete the videos.', style: const TextStyle(color: CrowColors.onMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: CrowColors.accentRed))),
        ],
      ),
    );
    if (confirmed == true) {
      await repoOf(context).deletePlaylist(p.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: 'Playlists',
          actions: [
            FilledButton.icon(
              onPressed: _create,
              style: FilledButton.styleFrom(backgroundColor: CrowColors.accentCyan, foregroundColor: CrowColors.bg),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New playlist'),
            ),
          ],
        ),
        Expanded(
          child: _playlists.isEmpty
              ? const Center(child: Text('No playlists yet. Create one to get started.', style: TextStyle(color: CrowColors.onMuted)))
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    childAspectRatio: 2.4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _playlists.length,
                  itemBuilder: (context, i) {
                    final p = _playlists[i];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: CrowColors.divider)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LibraryScreen(mode: LibraryMode.playlist, playlistId: p.id, playlistName: p.title, standalone: true),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.playlist_play_rounded, color: CrowColors.accentYellow, size: 30),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CrowColors.onBg, fontSize: 15, fontWeight: FontWeight.w600)),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: CrowColors.onMuted, size: 20),
                                color: CrowColors.surfaceElevated,
                                onSelected: (v) => v == 'rename' ? _rename(p) : _delete(p),
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 'rename', child: Text('Rename', style: TextStyle(color: CrowColors.onBg))),
                                  PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: CrowColors.accentRed))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
