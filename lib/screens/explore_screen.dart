import 'package:flutter/material.dart';
import '../models/video_entity.dart';
import '../theme/crow_colors.dart';
import '../widgets/section_header.dart';
import '../widgets/video_tiles.dart';
import 'main_screen.dart';
import 'player_screen.dart';

/// Port of `activity_explore.xml` + `explore/ExploreActivity.kt`.
/// Embedded directly in [AppShell]'s content area (Explore sidebar item).
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _controller = TextEditingController();
  List<VideoEntity> _results = [];
  bool _grid = true;

  Future<void> _search(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final results = await repoOf(context).search(q);
    if (mounted) setState(() => _results = results);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: 'Explore',
          subtitle: 'Search your library by filename',
          actions: [
            IconButton(
              icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded, color: CrowColors.onBg),
              onPressed: () => setState(() => _grid = !_grid),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
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
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => PlayerScreen(videoId: _results[i].id, siblingQueue: _results)),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _results.length,
                      itemBuilder: (context, i) => VideoListRow(
                        video: _results[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => PlayerScreen(videoId: _results[i].id, siblingQueue: _results)),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}
