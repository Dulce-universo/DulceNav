// ============================================================
// DulceNav — home_screen.dart
// Pantalla de inicio. Solo buscador + sitios recomendados.
// Sin rastreadores, sin anuncios, sin sugerencias de terceros.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/url_utils.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/update_service.dart';
import '../../core/services/download_manager.dart';
import '../../core/services/theme_service.dart';
import '../../shared/widgets/dynamic_background.dart';
import '../../ui/widgets/weather_widget.dart';
import '../../core/services/hardware_profile_service.dart';
import '../../ui/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<String>? onNavigate;
  final ValueChanged<String>? onNewTabWithUrl;
  final bool isIncognito;

  const HomeScreen({
    super.key,
    this.onNavigate,
    this.onNewTabWithUrl,
    this.isIncognito = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      HardwareProfileService.instance.detect(context: context).then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    });
  }

  // Sitios seguros recomendados del ecosistema
  static final List<_QuickSite> _quickSites = [
    _QuickSite(
      name: 'Dulce Universe',
      url: 'https://dulceapps.lovable.app',
      color: DulceColors.primary,
    ),
    const _QuickSite(
      name: 'Google',
      url: 'https://www.google.com',
      color: Color(0xFF4285F4),
    ),
    const _QuickSite(
      name: 'YouTube',
      url: 'https://www.youtube.com',
      color: Color(0xFFFF0000),
    ),
    const _QuickSite(
      name: 'GitHub',
      url: 'https://www.github.com',
      color: Color(0xFF6E40C9),
    ),
    const _QuickSite(
      name: 'Wikipedia',
      url: 'https://www.wikipedia.org',
      color: Color(0xFF636466),
    ),
    const _QuickSite(
      name: 'Reddit',
      url: 'https://www.reddit.com',
      color: Color(0xFFFF4500),
    ),
  ];

  void _navigate(String input) {
    final url = UrlUtils.processInput(input);
    if (widget.onNavigate != null) {
      widget.onNavigate!(url);
    } else {
      context.go('/browser?url=${Uri.encodeComponent(url)}');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.isIncognito ? const Color(0xFF00D4FF) : DulceColors.primary;
    final primaryGradient = widget.isIncognito
        ? const LinearGradient(
            colors: [Color(0xFF0052D4), Color(0xFF00D4FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : DulceColors.primaryGradient;
    final welcomeTitle = widget.isIncognito ? '🔒 MODO PRIVADO ACTIVO' : AppStrings.homeWelcome;
    final welcomeSubtitle = widget.isIncognito
        ? 'No se guardara nada de lo que hagas aqui'
        : AppStrings.homeSubtitle;
    final badgeColor = widget.isIncognito ? const Color(0xFF00D4FF) : DulceColors.safeGreen;
    final badgeText = widget.isIncognito ? 'Incognito' : 'Protegido';

    return Scaffold(
      backgroundColor: DulceColors.transparent, // transparent to let container gradient show
      body: DynamicBackground(
        isIncognito: widget.isIncognito,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                // ── Header ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo / Nombre
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: primaryGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.travel_explore_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'DulceNav',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: DulceColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          const WeatherWidget(),
                          const SizedBox(width: 12),
                          // Badge de privacidad "Protegido" o "Incognito"
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: badgeColor.withOpacity(0.7), // brighter border
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: badgeColor.withOpacity(0.2), // glow effect
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                 widget.isIncognito
                                     ? Icon(Icons.visibility_off_rounded, size: 14, color: Color(0xFF00D4FF))
                                     : Icon(Icons.gpp_good_rounded, size: 14, color: DulceColors.safeGreen),
                                const SizedBox(width: 5),
                                Text(
                                  badgeText,
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontSize: 11,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Título
                      Text(
                        welcomeTitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 32, // Redesigned to 32px
                          fontWeight: FontWeight.w600, // weight 600
                          color: Colors.white, // white
                        ),
                      ),
                      const SizedBox(height: 12), // Greater separation
                      Text(
                        welcomeSubtitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15, // size 15px
                          color: DulceColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Barra de búsqueda principal con Efecto Vidrio (52px) ──
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: primaryColor.withOpacity(0.12), // soft glow
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              height: 52, // 52px height
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E2E).withOpacity(0.7), // background glassmorphism
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.35), // subtle border
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.search_rounded,
                                    color: DulceColors.textDisabled,
                                    size: 22, // larger icon
                                  ),
                                  const SizedBox(width: 14), // text URL more separated
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocus,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: AppStrings.searchHint,
                                        hintStyle: TextStyle(
                                          color: DulceColors.textDisabled,
                                          fontSize: 15,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      style: TextStyle(
                                        color: DulceColors.textPrimary,
                                        fontSize: 15,
                                        fontFamily: 'Inter',
                                      ),
                                      textInputAction: TextInputAction.go,
                                      autocorrect: false,
                                      onSubmitted: _navigate,
                                    ),
                                  ),
                                  // Botón buscar redondo con hover morado o azul
                                  Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: _SearchArrowButton(
                                      primaryColor: primaryColor,
                                      onTap: () => _navigate(_searchController.text),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                _buildUpdateBanner(context),
                _buildHardwareProfileBanner(context),

                const SizedBox(height: 48), // Spacing for clean layout

                // ── Tus sitios favoritos ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tus sitios favoritos',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: DulceColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildBookmarksSection(),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Sitios recientes ──
                _buildRecentSitesSection(),
                const SizedBox(height: 32),

                // ── Sitios rápidos (Wrap en vez de GridView para responsive) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.homeTrendingTitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: DulceColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: _quickSites.map((site) {
                            return _QuickSiteCard(
                              site: site,
                              onTap: () => _navigate(site.url),
                              primaryColor: primaryColor,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // ── Aviso legal ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                  child: Text(
                    AppStrings.legalDisclaimer,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: DulceColors.textDisabled,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
}

  Widget _buildBookmarksSection() {
    final bookmarks = StorageService.instance.bookmarks;

    if (bookmarks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E).withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: DulceColors.primary.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Text(
          'Guarda paginas desde el menu para verlas aqui',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: DulceColors.textSecondary,
          ),
        ),
      );
    }

    final parsedBookmarks = <Map<String, String>>[];
    for (final item in bookmarks) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) {
          final url = decoded['url']?.toString() ?? item;
          final title = decoded['title']?.toString() ?? '';
          parsedBookmarks.add({
            'title': title.isEmpty ? UrlUtils.getDomain(url) : title,
            'url': url,
          });
        } else {
          parsedBookmarks.add({
            'title': UrlUtils.getDomain(item),
            'url': item,
          });
        }
      } catch (_) {
        parsedBookmarks.add({
          'title': UrlUtils.getDomain(item),
          'url': item,
        });
      }
    }

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: parsedBookmarks.map((bookmark) {
          final url = bookmark['url']!;
          final title = bookmark['title']!;
          final color = _getColorForUrl(url);

          return _QuickSiteCard(
            site: _QuickSite(
              name: title,
              url: url,
              color: color,
            ),
            primaryColor: widget.isIncognito ? const Color(0xFF00D4FF) : DulceColors.primary,
            onTap: () {
              if (widget.onNewTabWithUrl != null) {
                widget.onNewTabWithUrl!(url);
              } else {
                _navigate(url);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentSitesSection() {
    final historyList = StorageService.instance.history;
    if (historyList.isEmpty) return const SizedBox.shrink();

    final parsedRecent = <Map<String, String>>[];
    for (final item in historyList.take(6)) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) {
          final url = decoded['url']?.toString() ?? '';
          final title = decoded['title']?.toString() ?? '';
          if (url.isNotEmpty) {
            parsedRecent.add({
              'title': title.isEmpty ? UrlUtils.getDomain(url) : title,
              'url': url,
            });
          }
        }
      } catch (_) {}
    }

    if (parsedRecent.isEmpty) return const SizedBox.shrink();

    final theme = context.watch<ThemeService>();
    final isDark = theme.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sitios recientes',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DulceColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  await StorageService.instance.clearHistory();
                  setState(() {});
                },
                child: const Text('Limpiar', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: parsedRecent.map((item) {
                final url = item['url']!;
                final title = item['title']!;
                
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      if (widget.onNewTabWithUrl != null) {
                        widget.onNewTabWithUrl!(url);
                      } else {
                        _navigate(url);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           Icon(Icons.history_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                          const SizedBox(width: 8),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: DulceColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('google.com')) return const Color(0xFF4285F4);
    if (lower.contains('youtube.com')) return const Color(0xFFFF0000);
    if (lower.contains('github.com')) return const Color(0xFF6E40C9);
    if (lower.contains('wikipedia.org')) return const Color(0xFF636466);
    if (lower.contains('reddit.com')) return const Color(0xFFFF4500);
    if (lower.contains('dulceapps.lovable.app')) return widget.isIncognito ? const Color(0xFF00D4FF) : DulceColors.primary;
    return widget.isIncognito ? const Color(0xFF00D4FF) : DulceColors.primary;
  }

  Widget _buildUpdateBanner(BuildContext context) {
    return Consumer<UpdateService>(
      builder: (context, updateService, _) {
        if (updateService.state != UpdateState.updateAvailable &&
            updateService.state != UpdateState.downloading &&
            updateService.state != UpdateState.downloaded) {
          return const SizedBox.shrink();
        }

        final primaryColor = widget.isIncognito ? const Color(0xFF00D4FF) : DulceColors.primary;

        return Container(
          margin: const EdgeInsets.only(top: 24, left: 32, right: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E).withOpacity(0.85),
                border: Border.all(
                  color: primaryColor.withOpacity(0.4),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.system_update_alt_rounded, color: primaryColor, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔄 ¡Hay una nueva version v${updateService.latestVersion} disponible!',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          updateService.notes,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (updateService.state == UpdateState.updateAvailable)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: Icon(Icons.download_rounded, size: 16),
                      label: Text('Descargar ahora'),
                      onPressed: () {
                        final dm = context.read<DownloadManager>();
                        updateService.startDownloadUpdate(dm);
                      },
                    ),
                  if (updateService.state == UpdateState.downloading)
                    SizedBox(
                      width: 120,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LinearProgressIndicator(
                            value: updateService.progress,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Descargando: ${(updateService.progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (updateService.state == UpdateState.downloaded)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DulceColors.safeGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: Icon(Icons.install_desktop_rounded, size: 16),
                      label: Text('Instalar y Reiniciar'),
                      onPressed: () => updateService.installAndRestart(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHardwareProfileBanner(BuildContext context) {
    if (widget.isIncognito) return const SizedBox.shrink();
    final storage = StorageService.instance;
    if (storage.hardwareBannerShownV170) return const SizedBox.shrink();

    final info = HardwareProfileService.instance.cachedInfo;
    if (info == null) return const SizedBox.shrink();

    final profile = HardwareProfileService.instance.recommendProfile(info);
    final explanation = HardwareProfileService.instance.explainRecommendation(profile, info);

    final primaryColor = widget.isIncognito ? const Color(0xFF00D4FF) : DulceColors.primary;

    return Container(
      margin: const EdgeInsets.only(top: 16, left: 32, right: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E).withOpacity(0.85),
            border: Border.all(
              color: primaryColor.withOpacity(0.4),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✨ Perfil recomendado para tu equipo',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          explanation,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hardware detectado: ${info.osName} · ${info.cpuName} (${info.cpuCores} nucleos) · ${info.totalRamGb.toStringAsFixed(1)} GB RAM',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      await storage.setHardwareBannerShownV170(true);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    icon: const Icon(Icons.settings_rounded, size: 14, color: Colors.white70),
                    label: const Text(
                      'Personalizar',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () async {
                      await storage.setHardwareBannerShownV170(true);
                      setState(() {});
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ).then((_) {
                          if (mounted) setState(() {});
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 14),
                    label: const Text(
                      'Aplicar recomendacion',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () async {
                      await HardwareProfileService.instance.applyProfile(profile, overwrite: true);
                      await storage.setHardwareBannerShownV170(true);
                      setState(() {});
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Perfil de rendimiento aplicado con exito.',
                              style: TextStyle(fontFamily: 'Inter'),
                            ),
                            backgroundColor: DulceColors.primary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Botón de Flecha de Búsqueda con Efecto Hover ───────────────
class _SearchArrowButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color primaryColor;
  const _SearchArrowButton({required this.onTap, required this.primaryColor});

  @override
  State<_SearchArrowButton> createState() => _SearchArrowButtonState();
}

class _SearchArrowButtonState extends State<_SearchArrowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300), // smoother transition
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.primaryColor.withOpacity(0.8) // dynamic hover background
                : widget.primaryColor,
            shape: BoxShape.circle,
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.5), // glow of its color
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ─── Modelo de sitio rápido ──────────────────────────────────
class _QuickSite {
  final String name;
  final String url;
  final Color color;
  const _QuickSite({
    required this.name,
    required this.url,
    required this.color,
  });
}

// ─── Tarjeta de sitio rápido interactiva con efecto hover ──────
class _QuickSiteCard extends StatefulWidget {
  final _QuickSite site;
  final VoidCallback onTap;
  final Color primaryColor;

  const _QuickSiteCard({required this.site, required this.onTap, required this.primaryColor});

  @override
  State<_QuickSiteCard> createState() => _QuickSiteCardState();
}

class _QuickSiteCardState extends State<_QuickSiteCard> {
  bool _isHovered = false;
  Timer? _preloadTimer;

  @override
  void dispose() {
    _preloadTimer?.cancel();
    super.dispose();
  }

  void _onEnter() {
    setState(() => _isHovered = true);
    _preloadTimer?.cancel();
    _preloadTimer = Timer(const Duration(milliseconds: 300), () {
      _preloadUrl(widget.site.url);
    });
  }

  void _onExit() {
    setState(() => _isHovered = false);
    _preloadTimer?.cancel();
  }

  Future<void> _preloadUrl(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.scheme.startsWith('http')) {
        await http.head(uri).timeout(const Duration(seconds: 2));
        debugPrint('[PredictivePreload] Preloaded $url successfully');
      }
    } catch (_) {}
  }

  Widget _buildSiteIcon(_QuickSite site) {
    switch (site.name) {
      case 'Dulce Universe':
        return Icon(Icons.apps_rounded, color: site.color, size: 24);
      case 'Google':
        return Icon(Icons.search_rounded, color: site.color, size: 24);
      case 'YouTube':
        return Icon(Icons.play_circle_rounded, color: site.color, size: 24);
      case 'GitHub':
        return Icon(Icons.code_rounded, color: site.color, size: 24);
      case 'Wikipedia':
        return Icon(Icons.menu_book_rounded, color: site.color, size: 24);
      case 'Reddit':
        return Icon(Icons.forum_rounded, color: site.color, size: 24);
      default:
        return Icon(Icons.language_rounded, color: site.color, size: 24);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final isDark = theme.isDarkMode;

    final bgColor = isDark
        ? (_isHovered ? const Color(0xFF202035) : const Color(0xFF181828))
        : (_isHovered ? const Color(0xFFECECFA) : const Color(0xFFF5F5FA));

    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300), // smoother transition
          width: 180, // Size 180x140px
          height: 140,
          transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0), // translates 2px up on hover
          decoration: BoxDecoration(
            color: bgColor, // illuminates on hover
            borderRadius: BorderRadius.circular(16), // rounded 16px
            border: Border.all(
              color: _isHovered
                  ? widget.primaryColor.withOpacity(0.75) // bright border glow
                  : (isDark ? widget.primaryColor.withOpacity(0.3) : Colors.black12), // subtle border
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? widget.primaryColor.withOpacity(0.25) // soft glow
                    : Colors.black.withOpacity(0.1),
                blurRadius: _isHovered ? 16 : 8,
                spreadRadius: _isHovered ? 1 : 0,
                offset: Offset(0, _isHovered ? 6 : 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300), // smoother transition
                width: 44, // Container for icon
                height: 44,
                decoration: BoxDecoration(
                  color: widget.site.color.withOpacity(_isHovered ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _buildSiteIcon(widget.site),
              ),
              const SizedBox(height: 12),
              Text(
                widget.site.name,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DulceColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
