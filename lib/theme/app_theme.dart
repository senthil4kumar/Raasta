import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Raasta brand palette — warm road amber on deep asphalt surfaces.
class RaastaColors {
  RaastaColors._();

  static const amber = Color(0xFFF59E0B);
  static const amberDeep = Color(0xFFD97706);
  static const coral = Color(0xFFFB7185);
  static const violet = Color(0xFF8B5CF6);
  static const teal = Color(0xFF2DD4BF);
  static const asphalt = Color(0xFF0F172A);
  static const slate = Color(0xFF1E293B);
  static const mist = Color(0xFFF8FAFC);
}

ThemeData buildRaastaTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: isDark ? RaastaColors.amber : RaastaColors.amberDeep,
    onPrimary: isDark ? RaastaColors.asphalt : Colors.white,
    secondary: RaastaColors.violet,
    onSecondary: Colors.white,
    tertiary: RaastaColors.teal,
    onTertiary: RaastaColors.asphalt,
    error: const Color(0xFFEF4444),
    onError: Colors.white,
    surface: isDark ? RaastaColors.asphalt : RaastaColors.mist,
    onSurface: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
    surfaceContainerHighest: isDark
        ? RaastaColors.slate.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.72),
    onSurfaceVariant: isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B),
    outline: isDark
        ? const Color(0xFF334155)
        : const Color(0xFFCBD5E1),
    shadow: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
  );

  final baseText = GoogleFonts.plusJakartaSansTextTheme(
    ThemeData(brightness: brightness).textTheme,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: baseText.copyWith(
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.1,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: baseText.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.45),
      labelLarge: baseText.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? RaastaColors.slate.withValues(alpha: 0.55)
          : Colors.white.withValues(alpha: 0.85),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: scheme.primary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: const FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: const FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}

/// Shared motion durations — shortened when the user prefers reduced motion.
Duration motionDuration(BuildContext context, Duration normal) {
  if (MediaQuery.disableAnimationsOf(context)) {
    return Duration.zero;
  }
  return normal;
}

bool motionEnabled(BuildContext context) =>
    !MediaQuery.disableAnimationsOf(context);
