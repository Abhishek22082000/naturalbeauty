import 'package:flutter/material.dart';

/// The app's visual language, in one place.
///
/// Built around a deep botanical green with a warm off-white ground —
/// "natural beauty" rather than the blue-grey Material default. Both a
/// light and a dark scheme are defined so the app follows the device.
class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF2E6B4F); // deep leaf green
  static const _accent = Color(0xFFC77D4A); // warm terracotta

  /// Rounded, generous corners used consistently across cards and fields.
  static const radiusSm = 10.0;
  static const radiusMd = 14.0;
  static const radiusLg = 20.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    ).copyWith(
      tertiary: _accent,
      surface: isLight ? const Color(0xFFFCFBF7) : const Color(0xFF131614),
    );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          letterSpacing: -0.3,
        ),
      ),

      // Fields: soft filled pills with no hard outline until focused.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.1,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),

      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
