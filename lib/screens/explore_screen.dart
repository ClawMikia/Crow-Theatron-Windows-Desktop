import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/video_repository.dart';
import '../models/video_entity.dart';
import '../shortcuts/app_shortcuts.dart' show isTextInputActive;
import '../theme/crow_colors.dart';
import '../util/video_open.dart';
import '../widgets/keyboard_accessible.dart';
import '../widgets/library_actions.dart';
import '../widgets/section_header.dart';
import '../widgets/video_tiles.dart';

/// Port of `activity_explore.xml` + `explore/ExploreActivity.kt`.
/// Embedded directly in [AppShell]'s content area (Explore sidebar item).
/// Search results support the same "select many" actions as the Library.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _controller = TextEditingController();
  List<VideoEntity> _results = [];
  bool _grid = true;
  late final VideoRepository _repo;
  final SelectionController _selection = SelectionController();
  final FocusNode _focus = FocusNode(debugLabel: 'explore-selection');
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _repo = context.read<VideoRepository>();
    _selection.addListener(_onSelectionChanged);
    _repo.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoChanged);
    _selection.removeListener(_onSelectionChanged);
    _selection.dispose();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  void _onRepoChanged() {
    if (mounted) _search(_controller.text);
  }

  Future<void> _search(String raw) async {
    final token = ++_searchToken;
    final q = raw.trim();
    if (q.isEmpty) {
      if (mounted) setState(() => _results = []);
      return;
    }
    final results = await _repo.search(q);
    if (!mounted || token != _searchToken) return;
    setState(() => _results = results);
    _selection.retainOnly(results.map((v) => v.id).toSet());
  }

  Future<void> _tap(VideoEntity v) async {
    if (_selection.active) {
      _selection.toggle(v.id);
      return;
    }
    await openVideoPlayer(context, v, _results);
  }

  void _longPress(VideoEntity v) {
    _selection.toggle(v.id);
    _focus.requestFocus();
  }

  Future<void> _bulkMove() async {
    if (await BulkActions.moveToFolder(context, _repo, _selection.ids)) _selection.exit();
  }

  Future<void> _bulkAddToPlaylist() async {
    if (await BulkActions.addToPlaylist(context, _repo, _selection.ids)) _selection.exit();
  }

  Future<void> _bulkDelete() async {
    if (_selection.ids.isEmpty) return;
    if (await BulkActions.deleteFromLibrary(context, _repo, _selection.ids)) _selection.exit();
  }

  Widget _header() {
    if (_selection.active) {
      return SelectionBar(
        count: _selection.count,
        total: _results.length,
        onSelectAll: () => _selection.selectAll(_results.map((v) => v.id)),
        onClear: _selection.clear,
        onMove: _bulkMove,
        onAddToPlaylist: _bulkAddToPlaylist,
        onDelete: _bulkDelete,
        onDone: _selection.exit,
      );
    }
    return SectionHeader(
      title: 'Explore',
      subtitle: 'Search your library by filename',
      actions: [
        FocusableIconButton(
          icon: const Icon(Icons.checklist_rounded, color: CrowColors.onBg),
          onPressed: () {
            _selection.start();
            _focus.requestFocus();
          },
          tooltip: 'Select videos',
          semanticsLabel: 'Select multiple videos',
        ),
        FocusableIconButton(
          icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded, color: CrowColors.onBg),
          onPressed: () => setState(() => _grid = !_grid),
          tooltip: 'Toggle view',
          semanticsLabel: 'Toggle grid or list view',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selecting = _selection.active;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () {
          if (isTextInputActive() || _results.isEmpty) return;
          _selection.selectAll(_results.map((v) => v.id));
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_selection.active) _selection.exit();
        },
        const SingleActivator(LogicalKeyboardKey.delete): () {
          if (isTextInputActive()) return;
          if (_selection.active && _selection.count > 0) _bulkDelete();
        },
      },
      child: Focus(
        focusNode: _focus,
        child: Column(
          children: [
            _header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 420,
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: CrowColors.onBg),
                    onChanged: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search by filename',
                      prefixIcon: Icon(Icons.search_rounded, color: CrowColors.accentCyan),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _controller.text.trim().isEmpty ? 'Type to search your library.' : 'No matches found.',
                        style: const TextStyle(color: CrowColors.onMuted),
                      ),
                    )
                  : _grid
                      ? GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate: crowVideoGridDelegate,
                          itemCount: _results.length,
                          itemBuilder: (context, i) => VideoGridCard(
                            video: _results[i],
                            selectionMode: selecting,
                            selected: _selection.isSelected(_results[i].id),
                            onTap: () => _tap(_results[i]),
                            onLongPress: () => _longPress(_results[i]),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _results.length,
                          itemBuilder: (context, i) => VideoListRow(
                            video: _results[i],
                            selectionMode: selecting,
                            selected: _selection.isSelected(_results[i].id),
                            onTap: () => _tap(_results[i]),
                            onLongPress: () => _longPress(_results[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
