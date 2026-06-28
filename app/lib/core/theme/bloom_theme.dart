import 'package:flutter/material.dart';

/// Gothic-Futurist palette — a dark cathedral of light.
/// Tuned: deeper void + richer violet, with gold given more presence.
class BloomColors {
  static const bg = Color(0xFF08070E); // deeper void
  static const obsidian = Color(0xFF12111C); // raised surface
  static const surface = Color(0xFF1B1830); // glass-ish container
  static const aura = Color(0xFF5A2BE0); // deeper violet glow
  static const orchid = Color(0xFF8A4FFF); // highlight
  static const halo = Color(0xFF2A1A55); // deeper ambient bg orb
  static const gold = Color(0xFFEFC982); // richer sacred accent
  static const goldBright = Color(0xFFFFE6B0); // gold highlight
  static const mist = Color(0xFFD6D2E6); // body text
  static const whisper = Color(0xFF847FA0); // secondary text
}

/// Dark, elegant Gothic-Futurist theme. Fonts (Cinzel display + Manrope body)
/// are BUNDLED as assets — no network fetch, works fully offline.
class BloomTheme {
  static const _display = 'Cinzel';
  static const _body = 'Manrope';

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: BloomColors.aura,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF241A45),
      onPrimaryContainer: BloomColors.mist,
      secondary: BloomColors.gold,
      onSecondary: Color(0xFF2A2113),
      secondaryContainer: Color(0xFF2A2113),
      onSecondaryContainer: BloomColors.gold,
      surface: BloomColors.bg,
      onSurface: BloomColors.mist,
      surfaceContainerHighest: BloomColors.surface,
      outline: Color(0x556D4AFF),
    );

    final base = ThemeData.dark(useMaterial3: true);

    // Headers in gold Cinzel; body in Manrope.
    TextStyle cinzel(double size, {double spacing = 1.2, FontWeight w = FontWeight.w600}) =>
        TextStyle(
          fontFamily: _display,
          fontSize: size,
          fontWeight: w,
          letterSpacing: spacing,
          color: BloomColors.gold,
          height: 1.25,
        );

    final text = base.textTheme
        .apply(fontFamily: _body, bodyColor: BloomColors.mist, displayColor: BloomColors.mist)
        .copyWith(
          displayMedium: cinzel(40, spacing: 2),
          displaySmall: cinzel(32, spacing: 1.8),
          headlineMedium: cinzel(28, spacing: 1.6),
          headlineSmall: cinzel(23, spacing: 1.4),
          titleLarge: cinzel(20, spacing: 1.2),
        );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: BloomColors.bg,
      textTheme: text,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: BloomColors.mist,
        centerTitle: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: BloomColors.obsidian.withValues(alpha: 0.85),
        indicatorColor: BloomColors.aura.withValues(alpha: 0.25),
        elevation: 0,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: _body, fontSize: 11, color: BloomColors.whisper, letterSpacing: 0.5),
        ),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? BloomColors.orchid : BloomColors.whisper,
            )),
      ),
      cardTheme: CardThemeData(
        color: BloomColors.surface.withValues(alpha: 0.55),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: BloomColors.aura.withValues(alpha: 0.18)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BloomColors.obsidian.withValues(alpha: 0.7),
        hintStyle: const TextStyle(color: BloomColors.whisper),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: BloomColors.aura.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: BloomColors.orchid, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BloomColors.gold,
          foregroundColor: const Color(0xFF221A0C),
          textStyle: const TextStyle(
              fontFamily: _body, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: BloomColors.orchid),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: BloomColors.obsidian.withValues(alpha: 0.7),
        side: BorderSide(color: BloomColors.aura.withValues(alpha: 0.25)),
        labelStyle: const TextStyle(fontFamily: _body, color: BloomColors.mist, fontSize: 12),
      ),
      dividerColor: BloomColors.aura.withValues(alpha: 0.12),
      iconTheme: const IconThemeData(color: BloomColors.mist),
    );
  }
}
