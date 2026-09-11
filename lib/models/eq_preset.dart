/// Port of `data/EqPreset.kt`.
enum EqPreset {
  flat('FLAT', 'Flat'),
  bassBoost('BASS_BOOST', 'Bass Boost'),
  trebleBoost('TREBLE_BOOST', 'Treble Boost'),
  vocalClarity('VOCAL_CLARITY', 'Vocal Clarity'),
  cinema('CINEMA', 'Cinema'),
  night('NIGHT', 'Night Mode'),
  loud('LOUD', 'Loudness');

  final String storageKey;
  final String displayName;
  const EqPreset(this.storageKey, this.displayName);

  static EqPreset fromKey(String? key) =>
      EqPreset.values.firstWhere((e) => e.storageKey == key, orElse: () => EqPreset.flat);
}
