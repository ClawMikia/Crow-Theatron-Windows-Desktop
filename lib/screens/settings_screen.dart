import 'package:flutter/material.dart';
import '../data/app_prefs.dart';
import '../theme/crow_colors.dart';
import '../widgets/section_header.dart';
import '../widgets/keyboard_accessible.dart';

/// Port of `activity_settings.xml` + `settings/SettingsActivity.kt`.
/// "Display & Playback" defaults — applied to newly scanned videos and
/// used as step sizes in the Player screen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    AppPrefs.getInstance().then((p) => setState(() => _prefs = p));
  }

  String _fmt(double v, bool decimal) {
    if (!decimal) return v.toInt().toString();
    var s = v.toStringAsFixed(3);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s.isEmpty ? '0' : s;
  }

  Future<void> _editNumber({
    required String title,
    required double current,
    required bool decimal,
    required ValueChanged<double> onSave,
  }) async {
    final controller = TextEditingController(text: _fmt(current, decimal));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CrowColors.surfaceElevated,
        title: Text(title, style: const TextStyle(color: CrowColors.onBg)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: CrowColors.onBg),
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null || parsed <= 0) return;
              Navigator.pop(ctx, parsed);
            },
            child: const Text('Save', style: TextStyle(color: CrowColors.accentCyan)),
          ),
        ],
      ),
    );
    if (result != null) {
      onSave(result);
      setState(() {});
    }
  }

  Future<void> _resetDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CrowColors.surfaceElevated,
        title: const Text('Reset Display & Playback', style: TextStyle(color: CrowColors.onBg)),
        content: const Text('Restore all values in this section to their default settings?',
            style: TextStyle(color: CrowColors.onMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed == true) {
      await _prefs!.resetPlaybackDefaults();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    return Column(
      children: [
        const SectionHeader(title: 'Display & Playback', subtitle: 'Defaults for newly scanned videos and Player screen step sizes'),
        Expanded(
          child: prefs == null
              ? const Center(child: CircularProgressIndicator(color: CrowColors.accentYellow))
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Seek interval', style: TextStyle(color: CrowColors.onMuted, fontSize: 12)),
                        Row(
                          children: [
                            Expanded(
                              child: FocusableSlider(
                                value: prefs.defaultSeekJumpSec.clamp(1, 59).toDouble(),
                                min: 1,
                                max: 59,
                                divisions: 58,
                                onChanged: (v) => setState(() => prefs.defaultSeekJumpSec = v.round()),
                                semanticsLabel: 'Seek interval',
                                semanticsValue: '${prefs.defaultSeekJumpSec} sec',
                              ),
                            ),
                            FocusableInkWell(
                              onTap: () => _editNumber(
                                title: 'Skip interval (sec)',
                                current: prefs.defaultSeekJumpSec.toDouble(),
                                decimal: false,
                                onSave: (v) => prefs.defaultSeekJumpSec = v.toInt(),
                              ),
                              borderRadius: BorderRadius.circular(8),
                              semanticsLabel: 'Edit seek interval',
                              child: Text('${prefs.defaultSeekJumpSec}',
                                  style: const TextStyle(color: CrowColors.accentCyan, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _SettingRow(
                          label: 'Fast forward / rewind',
                          value: '${prefs.defaultSeekJumpSec} sec',
                          onTap: () => _editNumber(
                            title: 'Fast forward / rewind (sec)',
                            current: prefs.defaultSeekJumpSec.toDouble(),
                            decimal: false,
                            onSave: (v) => prefs.defaultSeekJumpSec = v.toInt(),
                          ),
                        ),
                        _SettingRow(
                          label: 'Speed step',
                          value: '${_fmt(prefs.defaultSpeedStep, true)} x',
                          onTap: () => _editNumber(
                            title: 'Speed step (x)',
                            current: prefs.defaultSpeedStep,
                            decimal: true,
                            onSave: (v) => prefs.defaultSpeedStep = v,
                          ),
                        ),
                        _SettingRow(
                          label: 'Pitch step',
                          value: '${_fmt(prefs.defaultPitchStepSemitones, true)} st',
                          onTap: () => _editNumber(
                            title: 'Pitch step (st)',
                            current: prefs.defaultPitchStepSemitones,
                            decimal: true,
                            onSave: (v) => prefs.defaultPitchStepSemitones = v,
                          ),
                        ),
                        _SettingRow(
                          label: 'Trim step',
                          value: '${prefs.defaultTrimStepMs} ms',
                          onTap: () => _editNumber(
                            title: 'Trim step (ms)',
                            current: prefs.defaultTrimStepMs.toDouble(),
                            decimal: false,
                            onSave: (v) => prefs.defaultTrimStepMs = v.toInt(),
                          ),
                        ),
                        _SettingRow(
                          label: 'Volume step',
                          value: '${prefs.defaultVolumeStepPercent} %',
                          onTap: () => _editNumber(
                            title: 'Volume step (%)',
                            current: prefs.defaultVolumeStepPercent.toDouble(),
                            decimal: false,
                            onSave: (v) => prefs.defaultVolumeStepPercent = v.toInt(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _resetDefaults,
                  style: OutlinedButton.styleFrom(foregroundColor: CrowColors.accentRed, side: const BorderSide(color: CrowColors.accentRed)),
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Reset Display & Playback'),
                ),
              ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      semanticsLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: CrowColors.onBg, fontSize: 14))),
            Text(value, style: const TextStyle(color: CrowColors.accentCyan, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
