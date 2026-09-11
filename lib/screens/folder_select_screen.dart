import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../data/folder_scanner.dart';
import '../theme/crow_colors.dart';
import '../widgets/crow_scaffold.dart';
import 'main_screen.dart';

/// Port of `activity_folder_select.xml` + `folder/FolderSelectActivity.kt`.
/// Uses `file_picker`'s native Windows folder/file dialogs in place of
/// Android's SAF `OpenDocumentTree` / `OpenMultipleDocuments` contracts.
class FolderSelectScreen extends StatefulWidget {
  const FolderSelectScreen({super.key});

  @override
  State<FolderSelectScreen> createState() => _FolderSelectScreenState();
}

class _FolderSelectScreenState extends State<FolderSelectScreen> {
  bool _busy = false;
  String _status = '';

  Future<void> _chooseFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select a video folder');
    if (path == null) return;
    setState(() { _busy = true; _status = 'Scanning…'; });
    final videos = await FolderScanner.scanDirectory(path);
    if (videos.isEmpty) {
      setState(() { _busy = false; _status = 'No video files found in that folder.'; });
      if (mounted) _showMessage('No Videos Found', _status);
      return;
    }
    await repoOf(context).importScanResults(videos);
    repoOf(context).prefs.lastFolderPath = path;
    if (mounted) _showMessage('Import Complete', 'Imported ${videos.length} videos', pop: true);
  }

  Future<void> _chooseFiles() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select video files',
      allowMultiple: true,
      type: FileType.video,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() { _busy = true; _status = 'Importing videos…'; });
    final paths = result.files.map((f) => f.path!).where((p) => p.isNotEmpty).toList();
    final videos = await FolderScanner.resolveFiles(paths);
    await repoOf(context).importScanResults(videos);
    if (mounted) _showMessage('Import Complete', 'Imported ${videos.length} videos', pop: true);
  }

  void _showMessage(String title, String message, {bool pop = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CrowColors.surfaceElevated,
        title: Text(title, style: const TextStyle(color: CrowColors.onBg)),
        content: Text(message, style: const TextStyle(color: CrowColors.onMuted)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (pop) Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) => setState(() { _busy = false; }));
  }

  @override
  Widget build(BuildContext context) {
    return CrowScaffold(
      toolbar: const CrowToolbar(title: 'Select Videos', showBack: true, titleColor: CrowColors.accentYellow),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_library_rounded, size: 72, color: CrowColors.accentCyan),
              const SizedBox(height: 20),
              const Text(
                'Add videos to your library from a folder, or pick individual files.',
                textAlign: TextAlign.center,
                style: TextStyle(color: CrowColors.onMuted),
              ),
              const SizedBox(height: 28),
              if (_busy) ...[
                const CircularProgressIndicator(color: CrowColors.accentYellow),
                const SizedBox(height: 12),
                Text(_status, style: const TextStyle(color: CrowColors.onMuted)),
              ] else ...[
                FilledButton.icon(
                  onPressed: _chooseFolder,
                  style: FilledButton.styleFrom(
                    backgroundColor: CrowColors.accentYellow,
                    foregroundColor: CrowColors.bg,
                    minimumSize: const Size(280, 48),
                  ),
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Choose a folder'),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _chooseFiles,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CrowColors.accentCyan,
                    side: const BorderSide(color: CrowColors.accentCyan),
                    minimumSize: const Size(280, 48),
                  ),
                  icon: const Icon(Icons.insert_drive_file_outlined),
                  label: const Text('Choose files'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
