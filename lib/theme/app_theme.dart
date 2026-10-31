import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Raasta "Monochrome Luxe" palette: matte black, graphite greys, hairlines
/// and a single bronze-amber accent.
class RaastaColors {
  RaastaColors._();

  /// The one accent colour.
  static const amber = Color(0xFFD08A3C);
  static const amberDeep = Color(0xFF9C6224);
  static const amberLight = Color(0xFFF0B56B);

  /// Kept for older call sites; all neutral now.
  static const coral = Color(0xFFB9B4AE);
  static const violet = Color(0xFFCFCFD2);
  static const teal = Color(0xFF9AA0A6);

  static const black = Color(0xFF060607);
  static const asphalt = Color(0xFF0A0A0B);
  static const slate = Color(0xFF151517);
  static const graphite = Color(0xFF232326);
  static const mist = Color(0xFFEDEBE8);
  static const muted = Color(0xFF8C8C91);
  static const hairline = Color(0x1FFFFFFF);
}

TextTheme _luxeText(TextTheme base) {
  final t = GoogleFonts.jostTextTheme(base);
  TextStyle? s(TextStyle? x, {FontWeight? w, double? ls, double? h}) =>
      x?.copyWith(fontWeight: w, letterSpacing: ls, height: h);
  return t.copyWith(
    headlineLarge: s(t.headlineLarge, w: FontWeight.w300, ls: 6, h: 1.1),
    headlineMedium: s(t.headlineMedium, w: FontWeight.w300, ls: 1.5),
    headlineSmall: s(t.headlineSmall, w: FontWeight.w300, ls: 1.2),
    titleLarge: s(t.titleLarge, w: FontWeight.w400, ls: 0.8),
    titleMedium: s(t.titleMedium, w: FontWeight.w400, ls: 0.6),
    titleSmall: s(t.titleSmall, w: FontWeight.w500, ls: 0.6),
    bodyLarge: s(t.bodyLarge, w: FontWeight.w300, ls: 0.4, h: 1.5),
    bodyMedium: s(t.bodyMedium, w: FontWeight.w300, ls: 0.3, h: 1.45),
    bodySmall: s(t.bodySmall, w: FontWeight.w400, ls: 0.3),
    labelLarge: s(t.labelLarge, w: FontWeight.w500, ls: 0.8),
    labelMedium: s(t.labelMedium, w: FontWeight.w500, ls: 0.8),
    labelSmall: s(t.labelSmall, w: FontWeight.w500, ls: 0.8),
  );
}

/// The app is always dark: a matte black cockpit. [brightness] is accepted so
/// existing call sites keep working, but both modes use the same look.
ThemeData buildRaastaTheme({required Brightness brightness}) {
  const hair = RaastaColors.hairline;
  final scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: RaastaColors.amber,
    onPrimary: const Color(0xFF14100A),
    secondary: RaastaColors.mist,
    onSecondary: RaastaColors.black,
    tertiary: RaastaColors.muted,
    onTertiary: RaastaColors.black,
    error: const Color(0xFFE5675C),
    onError: Colors.white,
    surface: RaastaColors.asphalt,
    onSurface: const Color(0xFFEDEBE8),
    surfaceContainerHighest: const Color(0xFF111113).withValues(alpha: 0.78),
    secondaryContainer: const Color(0xFF1A1A1C),
    onSurfaceVariant: RaastaColors.muted,
    outline: Colors.white.withValues(alpha: 0.18),
    shadow: Colors.black.withValues(alpha: 0.6),
  );

  final text = _luxeText(ThemeData(brightness: Brightness.dark).textTheme)
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  const square = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(3)),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: RaastaColors.asphalt,
    canvasColor: RaastaColors.asphalt,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.white.withValues(alpha: 0.04),
    dividerTheme: const DividerThemeData(color: hair, thickness: 0.6, space: 1),
    textTheme: text,
    iconTheme: const IconThemeData(size: 20, weight: 200),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: hair, width: 0.7),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0x33FFFFFF), width: 0.8),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0x33FFFFFF), width: 0.8),
      ),
      // The animated amber line is drawn by FocusUnderline.
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0x33FFFFFF), width: 0.8),
      ),
      labelStyle: text.bodyMedium?.copyWith(
        color: RaastaColors.muted,
        letterSpacing: 1,
      ),
      floatingLabelStyle: text.labelSmall?.copyWith(
        color: RaastaColors.amber,
        letterSpacing: 1.6,
      ),
      prefixIconColor: RaastaColors.muted,
      suffixIconColor: RaastaColors.muted,
      hintStyle: text.bodyMedium?.copyWith(color: RaastaColors.muted),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: RaastaColors.amber,
      selectionColor: RaastaColors.amber.withValues(alpha: 0.3),
      selectionHandleColor: RaastaColors.amber,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: square,
        backgroundColor: RaastaColors.amber,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
        textStyle: text.labelLarge?.copyWith(
          letterSpacing: 1.4,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: square,
        foregroundColor: scheme.onSurface,
        side: const BorderSide(color: Color(0x40FFFFFF), width: 0.8),
        textStyle: text.labelLarge?.copyWith(letterSpacing: 1.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: square,
        foregroundColor: scheme.onSurface,
        textStyle: text.labelLarge?.copyWith(letterSpacing: 1.2),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurface,
        iconSize: 21,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      selectedColor: RaastaColors.amber.withValues(alpha: 0.16),
      side: const BorderSide(color: Color(0x2EFFFFFF), width: 0.7),
      shape: const StadiumBorder(),
      labelStyle: text.labelMedium?.copyWith(color: scheme.onSurface),
      checkmarkColor: RaastaColors.amber,
      showCheckmark: false,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xE6101012),
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onSurface,
        letterSpacing: 0.6,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0x33FFFFFF), width: 0.7),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF0E0E10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0x33FFFFFF), width: 0.7),
      ),
      titleTextStyle: text.titleLarge?.copyWith(letterSpacing: 1.2),
      contentTextStyle: text.bodyMedium?.copyWith(color: RaastaColors.muted),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF0C0C0E),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      modalBackgroundColor: Color(0xFF0C0C0E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
        side: BorderSide(color: Color(0x2EFFFFFF), width: 0.7),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: RaastaColors.amber,
      linearTrackColor: Color(0x1FFFFFFF),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: RaastaColors.muted,
      textColor: scheme.onSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
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

/// Looping ambient motion (spotlight drift, grain-free shimmer) is skipped for
/// reduced-motion users and inside widget tests, where it would never settle.
bool ambientMotionEnabled(BuildContext context) =>
    motionEnabled(context) &&
    !WidgetsBinding.instance.runtimeType.toString().contains('Test');
