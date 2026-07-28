// ============================================================
// DulceNav — app_colors.dart
// Paleta cromatica oficial del ecosistema Dulce Universe.
// Coherente con DulceOP, DulcePlay y DulceBot.
// ============================================================

import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class DulceColors {
  DulceColors._(); // No instanciable

  // ─── FONDOS DINAMICOS ─────────────────────────────────────
  /// Fondo principal
  static Color get background => ThemeService.instance.activeBackgroundColor;

  /// Fondo de superficies (tarjetas, barras)
  static Color get surface => ThemeService.instance.activeSurfaceColor;

  /// Fondo elevado (modales, dropdowns)
  static Color get surfaceElevated {
    final preset = ThemeService.instance.preset;
    switch (preset) {
      case ThemePreset.deepOcean:
        return const Color(0xFF0B2036);
      case ThemePreset.emerald:
        return const Color(0xFF142620);
      case ThemePreset.ruby:
        return const Color(0xFF261216);
      case ThemePreset.absoluteNight:
        return const Color(0xFF161616);
      case ThemePreset.auto:
        final ext = ThemeService.instance.extractedColor;
        if (ext != null) {
          return Color.alphaBlend(Colors.black.withOpacity(0.82), ext);
        }
        return const Color(0xFF1A1A26);
      case ThemePreset.dulceClassic:
        return const Color(0xFF1A1A26);
    }
  }

  /// Borde sutil entre elementos
  static Color get border => ThemeService.instance.activeBorderColor;

  // ── MARCA DINAMICA ──────────────────────────────────────
  /// Color primario dinamico de marca
  static Color get primary => ThemeService.instance.activePrimaryColor;

  /// Primario con opacidad (hover states)
  static Color get primaryAlpha => primary.withOpacity(0.23);

  /// Cian neon — color de acento / highlights
  static Color get accent {
    final preset = ThemeService.instance.preset;
    switch (preset) {
      case ThemePreset.deepOcean:
        return const Color(0xFF00D4FF);
      case ThemePreset.emerald:
        return const Color(0xFF00FFB2);
      case ThemePreset.ruby:
        return const Color(0xFFFF5E7E);
      case ThemePreset.absoluteNight:
        return const Color(0xFFFFFFFF);
      case ThemePreset.auto:
        return primary;
      case ThemePreset.dulceClassic:
        return const Color(0xFF00D4FF);
    }
  }

  /// Acento con opacidad (glow effects)
  static Color get accentAlpha => accent.withOpacity(0.18);

  /// Gradiente principal: primario → acento
  static LinearGradient get primaryGradient => LinearGradient(
        colors: [primary, accent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Gradiente de fondo general
  static LinearGradient get backgroundGradient {
    return LinearGradient(
      colors: [
        background,
        Color.alphaBlend(Colors.black.withOpacity(0.55), background),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  /// Actualiza el color primario en runtime basado en la preferencia (Legacy)
  static void updatePrimaryColor(String colorName) {
    // Legacy support, actualizacion manejada por ThemeService
  }


  // ─── TEXTO ──────────────────────────────────────────────
  /// Texto principal
  static Color get textPrimary => ThemeService.instance.isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF1F2937);

  /// Texto secundario
  static Color get textSecondary => ThemeService.instance.isDarkMode ? const Color(0xFF8B8FA8) : const Color(0xFF4B5563);

  /// Texto deshabilitado / placeholder
  static Color get textDisabled => ThemeService.instance.isDarkMode ? const Color(0xFF424560) : const Color(0xFF9CA3AF);

  // ─── SEGURIDAD (Indicadores de sitios) ──────────────────
  /// 🟢 Sitio seguro
  static const Color safeGreen = Color(0xFF00FF87);
  static const Color safeGreenAlpha = Color(0x2500FF87);

  /// 🟡 Riesgo medio / desconocido
  static const Color warningYellow = Color(0xFFFFD600);
  static const Color warningYellowAlpha = Color(0x25FFD600);

  /// 🔴 Sitio peligroso / phishing / malware
  static const Color dangerRed = Color(0xFFFF1744);
  static const Color dangerRedAlpha = Color(0x25FF1744);

  // ─── ESTADOS UI ─────────────────────────────────────────
  /// Hover: capa semitransparente sobre elementos
  static const Color hoverOverlay = Color(0x0FFFFFFF);

  /// Focus: anillo de enfoque
  static Color get focusRing => primary;

  /// Ripple: efecto tactil
  static Color get ripple => primary.withOpacity(0.1);

  // ─── UTILIDADES ─────────────────────────────────────────
  /// Transparente
  static const Color transparent = Colors.transparent;

  /// Sombra oscura para glassmorphism sutil
  static const Color shadow = Color(0xCC000000);
}
