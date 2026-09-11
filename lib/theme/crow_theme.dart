import 'package:flutter/material.dart';
import 'crow_colors.dart';

/// Reusable outline "chip button" backgrounds — port of the
/// `bg_button_outline_*.xml` drawables (rounded stroke + transparent fill).
BoxDecoration crowOutlineDecoration(Color color, {double radius = 10}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: color, width: 1.4),
    color: Colors.transparent,
  );
}

class CrowTheme {
  CrowTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: CrowColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: CrowColors.accentYellow,
        secondary: CrowColors.accentCyan,
        surface: CrowColors.surface,
        error: CrowColors.accentRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: CrowColors.surface,
        foregroundColor: CrowColors.onBg,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: CrowColors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor: CrowColors.divider,
      textTheme: base.textTheme.apply(
        bodyColor: CrowColors.onBg,
        displayColor: CrowColors.onBg,
        fontFamily: 'Orbitron',
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: CrowColors.accentCyan,
        inactiveTrackColor: CrowColors.divider,
        thumbColor: CrowColors.accentCyan,
        overlayColor: CrowColors.accentCyan.withValues(alpha: 0.2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? CrowColors.accentYellow
              : CrowColors.onMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? CrowColors.accentYellow.withValues(alpha: 0.4)
              : CrowColors.divider,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.all(CrowColors.accentPink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: CrowColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: CrowColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: CrowColors.accentCyan, width: 1.4),
        ),
        labelStyle: const TextStyle(color: CrowColors.accentCyan),
        hintStyle: const TextStyle(color: CrowColors.onMuted),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(CrowColors.onMuted.withValues(alpha: 0.4)),
      ),
    );
  }
}
