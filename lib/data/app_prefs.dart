import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enhancement_mode.dart';

/// Port of `data/AppPrefs.kt`. A [ChangeNotifier] so that preference
/// changes (e.g. on the Settings / Enhancement screens) immediately
/// propagate to every listening widget.
class AppPrefs extends ChangeNotifier {
  AppPrefs._(this._p);
  final SharedPreferences _p;

  static AppPrefs? _instance;
  static Future<AppPrefs> getInstance() async {
    if (_instance != null) return _instance!;
    final p = await SharedPreferences.getInstance();
    _instance = AppPrefs._(p);
    return _instance!;
  }

  static const _keySeekJump = 'default_seek_jump_sec';
  static const _keyPitchStep = 'default_pitch_step_semitones';
  static const _keySpeedStep = 'default_speed_step';
  static const _keyTrimStepMs = 'default_trim_step_ms';
  static const _keyVolumeStep = 'default_volume_step_percent';
  static const _keyEnhancement = 'default_enhancement';
  static const _keyLastFolder = 'last_folder_path';

  int get defaultSeekJumpSec => _p.getInt(_keySeekJump) ?? 10;
  set defaultSeekJumpSec(int v) {
    _p.setInt(_keySeekJump, v < 1 ? 1 : v);
    notifyListeners();
  }

  double get defaultPitchStepSemitones => _p.getDouble(_keyPitchStep) ?? 1.0;
  set defaultPitchStepSemitones(double v) {
    _p.setDouble(_keyPitchStep, v < 0.1 ? 0.1 : v);
    notifyListeners();
  }

  double get defaultSpeedStep => _p.getDouble(_keySpeedStep) ?? 0.1;
  set defaultSpeedStep(double v) {
    _p.setDouble(_keySpeedStep, v < 0.01 ? 0.01 : v);
    notifyListeners();
  }

  int get defaultTrimStepMs => _p.getInt(_keyTrimStepMs) ?? 10000;
  set defaultTrimStepMs(int v) {
    _p.setInt(_keyTrimStepMs, v < 1000 ? 1000 : v);
    notifyListeners();
  }

  int get defaultVolumeStepPercent => _p.getInt(_keyVolumeStep) ?? 5;
  set defaultVolumeStepPercent(int v) {
    _p.setInt(_keyVolumeStep, v.clamp(1, 100));
    notifyListeners();
  }

  EnhancementMode get defaultEnhancement => EnhancementMode.fromKey(_p.getString(_keyEnhancement));
  set defaultEnhancement(EnhancementMode v) {
    _p.setString(_keyEnhancement, v.storageKey);
    notifyListeners();
  }

  String? get lastFolderPath => _p.getString(_keyLastFolder);
  set lastFolderPath(String? v) {
    if (v == null) {
      _p.remove(_keyLastFolder);
    } else {
      _p.setString(_keyLastFolder, v);
    }
    notifyListeners();
  }

  Future<void> resetPlaybackDefaults() async {
    await _p.remove(_keySeekJump);
    await _p.remove(_keyPitchStep);
    await _p.remove(_keySpeedStep);
    await _p.remove(_keyTrimStepMs);
    await _p.remove(_keyVolumeStep);
    notifyListeners();
  }
}
