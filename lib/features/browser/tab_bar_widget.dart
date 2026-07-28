// ==============================================================
// DulceNav - tab_bar_widget.dart
// Barra horizontal de pestanas en la parte superior del navegador.
// Disenho de cristal (glassmorphic) y coherente con DulceUI.
// ==============================================================

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/tab_manager.dart';
import '../../core/utils/url_utils.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/storage_service.dart';

class TabBarWidget extends StatelessWidget {
  final TabManager tabManager;
  final VoidCallback onNewTab;
  final VoidCallback onNewIncognitoTab;
  final Function(int index) onTabSelected;
  final Function(int index) onTabClosed;
  final Color? adaptiveColor;

  const TabBarWidget({
    super.key,
    required this.tabManager,
    required this.onNewTab,
    required this.onNewIncognitoTab,
    required this.onTabSelected,
    required this.onTabClosed,
    this.adaptiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool activeTabIsIncognito = tabManager.activeTab.isIncognito;
    final theme = context.watch<ThemeService>();
    final blurSigma = theme.blurSigma;

    final hasAdaptive = StorageService.instance.adaptiveThemeEnabled && adaptiveColor != null && !activeTabIsIncognito;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: 44, // 44px height for desktop
          decoration: BoxDecoration(
            color: hasAdaptive
                ? adaptiveColor!.withOpacity(theme.highContrast ? 1.0 : 0.80)
                : (activeTabIsIncognito
                    ? const Color(0xFF0A0F1D).withOpacity(theme.highContrast ? 1.0 : 0.85) // deeper blue-black esmerilado background
                    : theme.activeSurfaceColor.withOpacity(theme.highContrast ? 1.0 : 0.70)), // esmerilado background
            border: Border(
              bottom: BorderSide(
                color: theme.activeBorderColor, // fine bottom border
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              // Lista scrollable de pestanas
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: tabManager.tabCount,
                  itemBuilder: (BuildContext ctx, int index) {
                    final DulceTab tab = tabManager.tabs[index];
                    final bool isActive = index == tabManager.activeIndex;

                    return _TabChip(
                      tab: tab,
                      isActive: isActive,
                      onTap: () => onTabSelected(index),
                      onClose: tabManager.tabCount > 1
                          ? () => onTabClosed(index)
                          : null,
                    );
                  },
                ),
              ),

              // Boton nueva pestana
              if (tabManager.canAddTab) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Tooltip(
                      message: 'Nueva pestana',
                      child: GestureDetector(
                        onTap: onNewTab,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E2E).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: DulceColors.primary.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Tooltip(
                      message: 'Nueva pestana de incognito',
                      child: GestureDetector(
                        onTap: onNewIncognitoTab,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF00D4FF).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '\u{1F575}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------
// Chip individual de pestana
// --------------------------------------------------------------
class _TabChip extends StatefulWidget {
  final DulceTab tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _TabChip({
    required this.tab,
    required this.isActive,
    required this.onTap,
    this.onClose,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _isHovered = false;
  bool _isCloseHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isActive;
    final bool isIncognito = widget.tab.isIncognito;
    final primaryColor = isIncognito ? const Color(0xFF00D4FF) : DulceColors.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(
            minWidth: 100,
            maxWidth: 180,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active
                ? primaryColor.withOpacity(0.15) // illuminated active tab
                : (_isHovered
                    ? (isIncognito ? const Color(0xFF1E293B).withOpacity(0.60) : const Color(0xFF1E1E2E).withOpacity(0.60))
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? primaryColor.withOpacity(0.60) // bright primary border glow
                  : (_isHovered
                      ? primaryColor.withOpacity(0.25)
                      : Colors.transparent),
              width: 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.12), // glow shadow
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de estado / Favicon
              _buildTabIcon(widget.tab),
              const SizedBox(width: 6),

              // Titulo de la pestana
              Flexible(
                child: Text(
                  _getDisplayTitle(widget.tab),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active
                        ? Colors.white
                        : (_isHovered
                            ? Colors.white.withOpacity(0.9)
                            : DulceColors.textSecondary),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),

              // Boton cerrar con circulo hover
              if (widget.onClose != null) ...[
                const SizedBox(width: 6),
                MouseRegion(
                  onEnter: (_) => setState(() => _isCloseHovered = true),
                  onExit: (_) => setState(() => _isCloseHovered = false),
                  child: GestureDetector(
                    onTap: (widget.onClose != null) ? widget.onClose : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _isCloseHovered
                            ? Colors.white.withOpacity(0.15)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: _isCloseHovered
                            ? Colors.white
                            : (active ? DulceColors.textSecondary : DulceColors.textDisabled),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabIcon(DulceTab tab) {
    if (tab.hasActiveMedia) {
      return Icon(
        Icons.volume_up_rounded,
        size: 13,
        color: tab.isIncognito ? const Color(0xFF00D4FF) : DulceColors.primary,
      );
    }

    if (tab.isIncognito) {
      if (tab.isLoading) {
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
          ),
        );
      }
      return Text(
        '\u{1F575}',
        style: TextStyle(
          fontSize: 13,
        ),
      );
    }

    if (tab.isHibernated) {
      return Icon(
        Icons.bedtime_rounded,
        size: 13,
        color: DulceColors.textDisabled,
      );
    }

    if (tab.isLoading) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(DulceColors.primary),
        ),
      );
    }

    // Retornar icono especifico del sitio
    final String domain = UrlUtils.getDomain(tab.url).toLowerCase();
    if (domain.contains('google.com')) {
      return Icon(Icons.search_rounded, size: 13, color: Color(0xFF4285F4));
    }
    if (domain.contains('youtube.com')) {
      return Icon(Icons.play_circle_filled_rounded, size: 13, color: Color(0xFFFF0000));
    }
    if (domain.contains('github.com')) {
      return Icon(Icons.code_rounded, size: 13, color: Color(0xFF6E40C9));
    }
    if (domain.contains('wikipedia.org')) {
      return Icon(Icons.menu_book_rounded, size: 13, color: Color(0xFF636466));
    }
    if (domain.contains('reddit.com')) {
      return Icon(Icons.forum_rounded, size: 13, color: Color(0xFFFF4500));
    }
    if (domain.contains('dulceapps.lovable.app')) {
      return Icon(Icons.apps_rounded, size: 13, color: DulceColors.primary);
    }

    // Default icon
    if (UrlUtils.isHomePage(tab.url)) {
      return Icon(
        Icons.travel_explore_rounded,
        size: 13,
        color: widget.isActive ? DulceColors.primary : DulceColors.textDisabled,
      );
    } else {
      return Icon(
        Icons.public_rounded,
        size: 13,
        color: widget.isActive ? DulceColors.primary : DulceColors.textDisabled,
      );
    }
  }

  String _getDisplayTitle(DulceTab tab) {
    String baseTitle = '';
    if (UrlUtils.isHomePage(tab.url)) {
      baseTitle = 'Nueva pestaña';
    } else if (tab.title.isNotEmpty && tab.title != tab.url) {
      baseTitle = tab.title;
    } else {
      baseTitle = UrlUtils.getDomain(tab.url);
    }
    if (tab.isHibernated) {
      return '$baseTitle (zZz)';
    }
    return baseTitle;
  }
}
