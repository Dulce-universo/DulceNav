// ============================================================
// DulceNav — dulce_navbar.dart
// Barra de navegación inferior. Ultra-compacta, 52dp de alto.
// Botones: Atrás, Adelante, Home, Pestañas, Menú.
// Sin sombras pesadas. Glassmorphism sutil.
// ============================================================

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/tab_manager.dart';
import '../../core/services/theme_service.dart';

class DulceNavBar extends StatelessWidget {
  final bool canGoBack;
  final bool canGoForward;
  final int tabCount;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onHome;
  final VoidCallback onTabs;
  final VoidCallback onMenu;

  const DulceNavBar({
    super.key,
    required this.canGoBack,
    required this.canGoForward,
    required this.tabCount,
    required this.onBack,
    required this.onForward,
    required this.onHome,
    required this.onTabs,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final tabManager = context.watch<TabManager>();
    final bool activeTabIsIncognito = tabManager.activeTab.isIncognito;
    final primaryColor = activeTabIsIncognito ? const Color(0xFF00D4FF) : DulceColors.primary;
    final theme = context.watch<ThemeService>();
    final blurSigma = theme.blurSigma;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          height: 48, // Height: 48px
          decoration: BoxDecoration(
            color: activeTabIsIncognito
                ? const Color(0xFF0A0F1D).withOpacity(theme.highContrast ? 1.0 : 0.8)
                : theme.activeSurfaceColor.withOpacity(theme.highContrast ? 1.0 : 0.8), // Background glassmorphism
            border: Border(
              top: BorderSide(
                color: activeTabIsIncognito
                    ? const Color(0xFF00D4FF).withOpacity(theme.highContrast ? 1.0 : 0.35)
                    : theme.activeBorderColor, // subtle border
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // -- Atras ---------------------------------------
              _NavButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded),
                tooltip: AppStrings.back,
                onPressed: canGoBack ? onBack : null,
                enabled: canGoBack,
                primaryColor: primaryColor,
              ),

              // -- Adelante -------------------------------------
              _NavButton(
                icon: Icon(Icons.arrow_forward_ios_rounded),
                tooltip: AppStrings.forward,
                onPressed: canGoForward ? onForward : null,
                enabled: canGoForward,
                primaryColor: primaryColor,
              ),

              // -- Inicio ---------------------------------------
              _NavButton(
                icon: Icon(Icons.home_rounded),
                tooltip: AppStrings.home,
                onPressed: onHome,
                primaryColor: primaryColor,
              ),

              // -- Pestanas -------------------------------------
              _TabsButton(
                tabCount: tabCount,
                onPressed: onTabs,
                primaryColor: primaryColor,
              ),

              // -- Menu -----------------------------------------
              _NavButton(
                icon: Icon(Icons.more_vert_rounded),
                tooltip: AppStrings.settings,
                onPressed: onMenu,
                primaryColor: primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Boton generico de la navbar ----------------------------
class _NavButton extends StatelessWidget {
  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool enabled;
  final Color primaryColor;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.enabled = true,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18), // circular shape (36 / 2)
          hoverColor: primaryColor.withOpacity(0.15), // soft hover background
          splashColor: primaryColor.withOpacity(0.2),
          child: Container(
            width: 36, // button size 36px
            height: 36,
            alignment: Alignment.center,
            child: IconTheme(
              data: IconThemeData(
                size: 18,
                color: enabled
                    ? DulceColors.textSecondary
                    : const Color(0xFF555870), // light gray disabled state
              ),
              child: icon,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Boton de pestanas con contador -------------------------
class _TabsButton extends StatelessWidget {
  final int tabCount;
  final VoidCallback onPressed;
  final Color primaryColor;

  const _TabsButton({
    required this.tabCount,
    required this.onPressed,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Pestanas ($tabCount)',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18), // circular shape (36 / 2)
          hoverColor: primaryColor.withOpacity(0.15), // soft hover background
          splashColor: primaryColor.withOpacity(0.2),
          child: Container(
            width: 36, // button size 36px
            height: 36,
            alignment: Alignment.center,
            child: Container(
              width: 18, // slightly smaller to fit nicely in 36px circular button
              height: 18,
              decoration: BoxDecoration(
                border: Border.all(
                  color: DulceColors.textSecondary,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                tabCount > 9 ? '9+' : '$tabCount',
                style: TextStyle(
                  color: DulceColors.textSecondary,
                  fontSize: 9, // unifies text size
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
