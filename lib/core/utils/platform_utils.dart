// ============================================================
// DulceNav — platform_utils.dart
// Utilidades de detección de plataforma y capacidades.
// ============================================================

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class PlatformUtils {
  PlatformUtils._();

  // ── Detección ───────────────────────────────────────────
  static bool get isWindows =>
      !kIsWeb && Platform.isWindows;

  static bool get isAndroid =>
      !kIsWeb && Platform.isAndroid;

  static bool get isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  // ── Nombre legible ──────────────────────────────────────
  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    return 'Desconocido';
  }

  // ── WebView backend ────────────────────────────────────
  /// En Windows: Edge/Chromium (webview_windows)
  /// En Android: WebView del sistema (webview_flutter)
  static String get webViewBackend {
    if (isWindows) return 'Microsoft Edge (WebView2)';
    if (isAndroid) return 'Android System WebView';
    return 'Unknown';
  }

  // ── Capacidades ─────────────────────────────────────────
  /// ¿Soporta modo cine con fullscreen nativo?
  static bool get supportsFullscreen => isWindows || isAndroid;

  /// ¿Tiene soporte táctil?
  static bool get hasTouchInput => isMobile;

  /// ¿Tiene teclado físico?
  static bool get hasHardwareKeyboard => isDesktop;
}
