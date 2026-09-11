/// Port of `data/EnhancementMode.kt`.
enum EnhancementMode {
  none('NONE', 'None'),
  vividHd('VIVID_HD', 'Vivid HD'),
  cinemaContrast('CINEMA_CONTRAST', 'Cinema Contrast'),
  warmFilm('WARM_FILM', 'Warm Film'),
  coolHdrSim('COOL_HDR_SIM', 'Cool HDR'),
  amoled('AMOLED', 'AMOLED'),
  nightMode('NIGHT_MODE', 'Night Mode'),
  anime('ANIME', 'Anime'),
  eyeComfort('EYE_COMFORT', 'Eye Comfort'),
  vividOutdoor('VIVID_OUTDOOR', 'Vivid Outdoor'),
  cinematicDark('CINEMATIC_DARK', 'Cinematic Dark');

  final String storageKey;
  final String displayName;
  const EnhancementMode(this.storageKey, this.displayName);

  static EnhancementMode fromKey(String? key) => EnhancementMode.values
      .firstWhere((e) => e.storageKey == key, orElse: () => EnhancementMode.none);

  /// One-line description shown in the enhancement picker card.
  String get description {
    switch (this) {
      case EnhancementMode.none:
        return 'No adjustments — original picture.';
      case EnhancementMode.vividHd:
        return 'Boosts saturation and contrast for a punchier picture.';
      case EnhancementMode.cinemaContrast:
        return 'Deeper blacks and filmic contrast curve.';
      case EnhancementMode.warmFilm:
        return 'Warm color grade reminiscent of film stock.';
      case EnhancementMode.coolHdrSim:
        return 'Cooler tones with simulated HDR punch.';
      case EnhancementMode.amoled:
        return 'Crushes blacks for AMOLED / OLED screens.';
      case EnhancementMode.nightMode:
        return 'Reduces brightness and blue tones for night viewing.';
      case EnhancementMode.anime:
        return 'Vivid, sharp look tuned for animation.';
      case EnhancementMode.eyeComfort:
        return 'Softer contrast and warmer tone for long sessions.';
      case EnhancementMode.vividOutdoor:
        return 'Extra brightness and contrast for sunlit viewing.';
      case EnhancementMode.cinematicDark:
        return 'Low-key, desaturated cinematic look.';
    }
  }

  /// mpv `eq` + `unsharp` + `hue` filter chain parameters used to realize
  /// the look on the actual video output via libmpv `vf`.
  /// (brightness -1..1, contrast 0..2, saturation 0..3, gamma 0.1..10, hueDeg -180..180, sharpen 0..1.5)
  ({double brightness, double contrast, double saturation, double gamma, double hue, double sharpen}) get filterParams {
    switch (this) {
      case EnhancementMode.none:
        return (brightness: 0, contrast: 1, saturation: 1, gamma: 1, hue: 0, sharpen: 0);
      case EnhancementMode.vividHd:
        return (brightness: 0.02, contrast: 1.15, saturation: 1.35, gamma: 1, hue: 0, sharpen: 0.4);
      case EnhancementMode.cinemaContrast:
        return (brightness: -0.03, contrast: 1.25, saturation: 0.95, gamma: 0.92, hue: 0, sharpen: 0.1);
      case EnhancementMode.warmFilm:
        return (brightness: 0.02, contrast: 1.08, saturation: 1.1, gamma: 1, hue: 8, sharpen: 0);
      case EnhancementMode.coolHdrSim:
        return (brightness: 0.03, contrast: 1.2, saturation: 1.15, gamma: 1.05, hue: -8, sharpen: 0.3);
      case EnhancementMode.amoled:
        return (brightness: -0.06, contrast: 1.3, saturation: 1.1, gamma: 0.9, hue: 0, sharpen: 0);
      case EnhancementMode.nightMode:
        return (brightness: -0.12, contrast: 0.95, saturation: 0.8, gamma: 0.85, hue: -6, sharpen: 0);
      case EnhancementMode.anime:
        return (brightness: 0.02, contrast: 1.18, saturation: 1.4, gamma: 1, hue: 0, sharpen: 0.6);
      case EnhancementMode.eyeComfort:
        return (brightness: 0.01, contrast: 0.92, saturation: 0.9, gamma: 1.02, hue: 6, sharpen: 0);
      case EnhancementMode.vividOutdoor:
        return (brightness: 0.08, contrast: 1.3, saturation: 1.2, gamma: 1.1, hue: 0, sharpen: 0.2);
      case EnhancementMode.cinematicDark:
        return (brightness: -0.08, contrast: 1.2, saturation: 0.7, gamma: 0.88, hue: 0, sharpen: 0);
    }
  }
}
