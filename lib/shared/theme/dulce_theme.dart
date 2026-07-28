// ============================================================
// DulceNav — dulce_theme.dart
// Sistema de diseño completo: DulceUI dinámico Claro/Oscuro.
// Sin animaciones pesadas. Tipografía Inter UI local.
// ============================================================

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';

class DulceTheme {
  DulceTheme._();

  static ThemeData get dark => _buildTheme(Brightness.dark);
  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',

      // ── Colores base ───────────────────────────────────
      colorScheme: isDark
          ? ColorScheme.dark(
              brightness: brightness,
              primary: DulceColors.primary,
              onPrimary: Colors.white,
              secondary: DulceColors.accent,
              onSecondary: Colors.black,
              surface: DulceColors.surface,
              onSurface: DulceColors.textPrimary,
              surfaceContainerHighest: DulceColors.surfaceElevated,
              error: DulceColors.dangerRed,
              onError: Colors.white,
              outline: DulceColors.border,
              shadow: DulceColors.shadow,
            )
          : ColorScheme.light(
              brightness: brightness,
              primary: DulceColors.primary,
              onPrimary: Colors.white,
              secondary: DulceColors.accent,
              onSecondary: Colors.white,
              surface: DulceColors.surface,
              onSurface: DulceColors.textPrimary,
              surfaceContainerHighest: DulceColors.surfaceElevated,
              error: DulceColors.dangerRed,
              onError: Colors.white,
              outline: DulceColors.border,
              shadow: DulceColors.shadow,
            ),

      scaffoldBackgroundColor: DulceColors.background,
      canvasColor: DulceColors.surface,

      // ── Tipografía ─────────────────────────────────────
      textTheme: TextTheme(
        // Títulos grandes
        displayLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: DulceColors.textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: DulceColors.textPrimary,
        ),
        // Títulos de sección
        headlineLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: DulceColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: DulceColors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: DulceColors.textPrimary,
        ),
        // Cuerpo de texto
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: DulceColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: DulceColors.textSecondary,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: DulceColors.textDisabled,
        ),
        // Labels
        labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: DulceColors.textPrimary,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: DulceColors.textSecondary,
        ),
      ),

      // ── AppBar ─────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: DulceColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: DulceColors.textSecondary,
          size: 20,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: DulceColors.textPrimary,
        ),
      ),

      // ── NavigationBar (barra inferior) ─────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DulceColors.surface,
        indicatorColor: DulceColors.primaryAlpha,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: AppConfig.navBarHeight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: DulceColors.primary,
              size: 22,
            );
          }
          return IconThemeData(
            color: DulceColors.textDisabled,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: DulceColors.primary,
            );
          }
          return TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: DulceColors.textDisabled,
          );
        }),
      ),

      // ── Cards ──────────────────────────────────────────
      cardTheme: CardThemeData(
        color: DulceColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: DulceColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── TextField (barra de URL) ────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DulceColors.surfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: DulceColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: DulceColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide:
              BorderSide(color: DulceColors.primary, width: 1.5),
        ),
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          color: DulceColors.textDisabled,
          fontSize: 14,
        ),
      ),

      // ── Botones Elevados ───────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DulceColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Botones de Texto ───────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DulceColors.primary,
          textStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ── Icon Button ────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: DulceColors.textSecondary,
          hoverColor: DulceColors.hoverOverlay,
        ),
      ),

      // ── Divider ────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: DulceColors.border,
        thickness: 1,
        space: 1,
      ),

      // ── Switch ─────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return DulceColors.primary;
          }
          return DulceColors.textDisabled;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return DulceColors.primaryAlpha;
          }
          return DulceColors.surfaceElevated;
        }),
        trackOutlineColor:
            WidgetStateProperty.resolveWith((states) => DulceColors.border),
      ),

      // ── Progress Indicator ─────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: DulceColors.primary,
        linearTrackColor: DulceColors.border,
      ),

      // ── Tooltip ────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: DulceColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: DulceColors.border),
        ),
        textStyle: TextStyle(
          fontFamily: 'Inter',
          color: DulceColors.textPrimary,
          fontSize: 12,
        ),
      ),

      // ── Duración de animaciones (REDUCIDA para bajo consumo)
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      // ── Splash / Ripple ────────────────────────────────
      splashColor: DulceColors.ripple,
      highlightColor: Colors.transparent,
      hoverColor: DulceColors.hoverOverlay,
    );
  }
}
