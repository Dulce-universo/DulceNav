// ============================================================
// DulceNav — theme_service.dart
// Servicio para gestionar temas dinamicos del ecosistema.
// ============================================================

import 'package:flutter/material.dart';
import 'storage_service.dart';

enum ThemePreset { dulceClassic, deepOcean, emerald, ruby, absoluteNight, auto }
enum BlurIntensity { light, medium, intense }

class ThemeService extends ChangeNotifier with WidgetsBindingObserver {
  ThemeService._() {
    _loadSettings();
    WidgetsBinding.instance.addObserver(this);
  }
  static final ThemeService instance = ThemeService._();

  ThemePreset _preset = ThemePreset.dulceClassic;
  bool _highContrast = false;
  BlurIntensity _blur = BlurIntensity.medium;
  Color? _extractedColor;
  double _uiScale = 1.0;
  bool _isWindowFocused = true;
  bool _isDarkMode = true;

  ThemePreset get preset => _preset;
  bool get highContrast => _highContrast;
  BlurIntensity get blur => _blur;
  Color? get extractedColor => _extractedColor;
  double get uiScale => _uiScale;
  bool get isWindowFocused => _isWindowFocused;
  bool get isDarkMode => _isDarkMode;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final focused = state == AppLifecycleState.resumed;
    if (_isWindowFocused != focused) {
      _isWindowFocused = focused;
      notifyListeners();
    }
  }

  void _loadSettings() {
    final storage = StorageService.instance;
    _preset = _parsePreset(storage.themePreset);
    _highContrast = storage.highContrast;
    _blur = _parseBlur(storage.blurIntensity);
    _uiScale = storage.uiScale;
    _isDarkMode = storage.getBool('is_dark_mode') ?? true;
  }

  void setDarkMode(bool val) {
    _isDarkMode = val;
    StorageService.instance.setBool('is_dark_mode', val);
    notifyListeners();
  }

  ThemePreset _parsePreset(String val) {
    switch (val) {
      case 'deepOcean':
        return ThemePreset.deepOcean;
      case 'emerald':
        return ThemePreset.emerald;
      case 'ruby':
        return ThemePreset.ruby;
      case 'absoluteNight':
        return ThemePreset.absoluteNight;
      case 'auto':
        return ThemePreset.auto;
      case 'dulceClassic':
      default:
        return ThemePreset.dulceClassic;
    }
  }

  String _presetToString(ThemePreset val) {
    switch (val) {
      case ThemePreset.deepOcean:
        return 'deepOcean';
      case ThemePreset.emerald:
        return 'emerald';
      case ThemePreset.ruby:
        return 'ruby';
      case ThemePreset.absoluteNight:
        return 'absoluteNight';
      case ThemePreset.auto:
        return 'auto';
      case ThemePreset.dulceClassic:
        return 'dulceClassic';
    }
  }

  BlurIntensity _parseBlur(String val) {
    switch (val) {
      case 'light':
        return BlurIntensity.light;
      case 'intense':
        return BlurIntensity.intense;
      case 'medium':
      default:
        return BlurIntensity.medium;
    }
  }

  String _blurToString(BlurIntensity val) {
    switch (val) {
      case BlurIntensity.light:
        return 'light';
      case BlurIntensity.intense:
        return 'intense';
      case BlurIntensity.medium:
        return 'medium';
    }
  }

  void setPreset(ThemePreset val) {
    _preset = val;
    StorageService.instance.setThemePreset(_presetToString(val));
    notifyListeners();
  }

  void setHighContrast(bool val) {
    _highContrast = val;
    StorageService.instance.setHighContrast(val);
    notifyListeners();
  }

  void setBlur(BlurIntensity val) {
    _blur = val;
    StorageService.instance.setBlurIntensity(_blurToString(val));
    notifyListeners();
  }

  void setUiScale(double val) {
    _uiScale = val;
    StorageService.instance.setUiScale(val);
    notifyListeners();
  }

  void updateExtractedColor(Color color) {
    if (_preset == ThemePreset.auto) {
      _extractedColor = color;
      notifyListeners();
    }
  }

  // Smart shadow generation depending on window focus
  List<BoxShadow> getSmartShadow(Color color) {
    if (_isWindowFocused) {
      return [
        BoxShadow(
          color: color.withOpacity(_highContrast ? 0.55 : 0.35),
          blurRadius: 18,
          spreadRadius: 2,
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: color.withOpacity(_highContrast ? 0.25 : 0.12),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ];
    }
  }

  // Get active primary accent color
  Color get activePrimaryColor {
    if (_preset == ThemePreset.auto && _extractedColor != null) {
      return _extractedColor!;
    }
    if (!_isDarkMode) {
      switch (_preset) {
        case ThemePreset.deepOcean:
          return const Color(0xFF0070F3);
        case ThemePreset.emerald:
          return const Color(0xFF059669);
        case ThemePreset.ruby:
          return const Color(0xFFDC2626);
        case ThemePreset.absoluteNight:
          return const Color(0xFF374151);
        case ThemePreset.auto:
        case ThemePreset.dulceClassic:
          return const Color(0xFF4F46E5);
      }
    }
    switch (_preset) {
      case ThemePreset.deepOcean:
        return const Color(0xFF0091FF);
      case ThemePreset.emerald:
        return const Color(0xFF00FFB2);
      case ThemePreset.ruby:
        return const Color(0xFFFF2D55);
      case ThemePreset.absoluteNight:
        return const Color(0xFFE0E0E0);
      case ThemePreset.auto:
      case ThemePreset.dulceClassic:
        return const Color(0xFF6C63FF);
    }
  }

  // Get active background color
  Color get activeBackgroundColor {
    if (!_isDarkMode) {
      return const Color(0xFFF9FAFB);
    }
    switch (_preset) {
      case ThemePreset.deepOcean:
        return const Color(0xFF020B14);
      case ThemePreset.emerald:
        return const Color(0xFF060F0C);
      case ThemePreset.ruby:
        return const Color(0xFF0F0507);
      case ThemePreset.absoluteNight:
        return const Color(0xFF000000);
      case ThemePreset.auto:
        if (_extractedColor != null) {
          return Color.alphaBlend(
            Colors.black.withOpacity(0.93),
            _extractedColor!,
          );
        }
        return const Color(0xFF0A0A0F);
      case ThemePreset.dulceClassic:
        return const Color(0xFF0A0A0F);
    }
  }

  // Get active surface color
  Color get activeSurfaceColor {
    if (!_isDarkMode) {
      switch (_preset) {
        case ThemePreset.deepOcean:
          return const Color(0xFFEDF2F7);
        case ThemePreset.emerald:
          return const Color(0xFFECFDF5);
        case ThemePreset.ruby:
          return const Color(0xFFFFF5F5);
        default:
          return const Color(0xFFFFFFFF);
      }
    }
    switch (_preset) {
      case ThemePreset.deepOcean:
        return const Color(0xFF061524);
      case ThemePreset.emerald:
        return const Color(0xFF0C1814);
      case ThemePreset.ruby:
        return const Color(0xFF1A0A0D);
      case ThemePreset.absoluteNight:
        return const Color(0xFF0C0C0C);
      case ThemePreset.auto:
        if (_extractedColor != null) {
          return Color.alphaBlend(
            Colors.black.withOpacity(0.88),
            _extractedColor!,
          );
        }
        return const Color(0xFF12121A);
      case ThemePreset.dulceClassic:
        return const Color(0xFF12121A);
    }
  }

  // Get active border color
  Color get activeBorderColor {
    if (_highContrast) {
      return activePrimaryColor.withOpacity(1.0);
    }
    if (!_isDarkMode) {
      return const Color(0xFFE5E7EB);
    }
    switch (_preset) {
      case ThemePreset.deepOcean:
        return const Color(0xFF122D4A);
      case ThemePreset.emerald:
        return const Color(0xFF1F3830);
      case ThemePreset.ruby:
        return const Color(0xFF381F24);
      case ThemePreset.absoluteNight:
        return const Color(0xFF262626);
      case ThemePreset.auto:
        if (_extractedColor != null) {
          return _extractedColor!.withOpacity(0.25);
        }
        return const Color(0xFF252535);
      case ThemePreset.dulceClassic:
        return const Color(0xFF252535);
    }
  }

  double get blurSigma {
    switch (_blur) {
      case BlurIntensity.light:
        return 5.0;
      case BlurIntensity.intense:
        return 22.0;
      case BlurIntensity.medium:
        return 12.0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
