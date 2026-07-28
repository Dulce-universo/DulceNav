// ==============================================================
// DulceNav - dulce_address_bar.dart
// Barra de direccion URL con animaciones suaves DulceUI.
// v1.2.0: Muestra contador de bloqueados desde AdBlocker.
// ==============================================================

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/url_utils.dart';
import '../../features/security/ad_blocker.dart';
import '../../features/ai/dulcemind_service.dart';
import '../../core/services/tab_manager.dart';
import '../../core/services/theme_service.dart';

class DulceAddressBar extends StatefulWidget {
  final String currentUrl;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final VoidCallback? onStop;
  final VoidCallback? onBrainPressed;
  final Function(String url) onNavigate;
  final FocusNode? focusNode;

  const DulceAddressBar({
    super.key,
    required this.currentUrl,
    required this.isLoading,
    required this.onNavigate,
    this.onRefresh,
    this.onStop,
    this.onBrainPressed,
    this.focusNode,
  });

  @override
  State<DulceAddressBar> createState() => _DulceAddressBarState();
}

class _DulceAddressBarState extends State<DulceAddressBar> {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: UrlUtils.displayUrl(widget.currentUrl),
    );
    _focusNode = widget.focusNode ?? FocusNode();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _isEditing = true);
        _textController.text = widget.currentUrl == 'about:dulcenav'
            ? ''
            : widget.currentUrl;
        _textController.selectAll();
      } else {
        setState(() => _isEditing = false);
        _textController.text = UrlUtils.displayUrl(widget.currentUrl);
      }
    });
  }

  @override
  void didUpdateWidget(DulceAddressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.currentUrl != widget.currentUrl) {
      _textController.text = UrlUtils.displayUrl(widget.currentUrl);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onSubmitted(String input) {
    final String url = UrlUtils.processInput(input);
    widget.onNavigate(url);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final tabManager = context.watch<TabManager>();
    final bool activeTabIsIncognito = tabManager.activeTab.isIncognito;
    final primaryColor = activeTabIsIncognito ? const Color(0xFF00D4FF) : DulceColors.primary;
    final theme = context.watch<ThemeService>();
    final blurSigma = theme.blurSigma;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: theme.getSmartShadow(primaryColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            height: 52, // Height: 52px
            decoration: BoxDecoration(
              color: _isEditing
                  ? (activeTabIsIncognito
                      ? const Color(0xFF132035).withOpacity(theme.highContrast ? 1.0 : 0.85)
                      : const Color(0xFF232338).withOpacity(theme.highContrast ? 1.0 : 0.85))
                  : (activeTabIsIncognito
                      ? const Color(0xFF0A0F1D).withOpacity(theme.highContrast ? 1.0 : 0.7)
                      : const Color(0xFF1E1E2E).withOpacity(theme.highContrast ? 1.0 : 0.7)), // Background glassmorphism
              borderRadius: BorderRadius.circular(16), // Rounded 16px
              border: Border.all(
                color: _isEditing
                    ? primaryColor
                    : (activeTabIsIncognito
                        ? const Color(0xFF00D4FF).withOpacity(theme.highContrast ? 1.0 : 0.35)
                        : theme.activeBorderColor), // Border color
                width: 1.0,
              ),
            ),
            child: Row(
              children: <Widget>[
                // Icono de candado (estado seguridad)
                const SizedBox(width: 12),
                Icon(
                  Icons.lock_rounded, // lock rounded
                  size: 18, // slightly larger
                  color: activeTabIsIncognito ? const Color(0xFF00D4FF) : DulceColors.safeGreen,
                ),
                const SizedBox(width: 14), // text URL more separated

                // Campo de texto URL
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      hintText: AppStrings.searchHint,
                      hintStyle: TextStyle(
                        color: DulceColors.textDisabled,
                        fontSize: 14,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    style: TextStyle(
                      color: DulceColors.textPrimary,
                      fontSize: 14,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w400,
                    ),
                    textInputAction: TextInputAction.go,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onSubmitted: _onSubmitted,
                  ),
                ),

                // Contador de bloqueados (solo visible si hay elementos bloqueados)
                _BlockedCounterBadge(
                  currentUrl: widget.currentUrl,
                  primaryColor: primaryColor,
                ),

                // Boton Cerebro DulceMind (solo visible si esta listo y habilitado)
                Consumer<DulceMindService>(
                  builder: (BuildContext context, DulceMindService ai, Widget? child) {
                    if (!ai.isEnabled || ai.isHideFeature) return const SizedBox.shrink();
                    return IconButton(
                      icon: Icon(
                        Icons.psychology_rounded,
                        size: 20,
                        color: primaryColor,
                      ),
                      onPressed: widget.onBrainPressed,
                      tooltip: 'Preguntar a DulceMind',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
                    );
                  },
                ),
                const SizedBox(width: 4),

                 // Boton Recargar / Detener / Buscar
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: _isEditing
                      ? IconButton(
                          key: const ValueKey<String>('search_go'),
                          icon: Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: primaryColor,
                          ),
                          onPressed: () => _onSubmitted(_textController.text),
                          tooltip: 'Ir / Buscar',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
                        )
                      : widget.isLoading
                          ? IconButton(
                              key: const ValueKey<String>('stop'),
                              icon: Icon(
                                Icons.close_rounded,
                                size: 22, // larger icon
                                color: DulceColors.dangerRed, // more visible and clear red stop color
                              ),
                              onPressed: widget.onStop,
                              tooltip: AppStrings.stop,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(width: 38, height: 38),
                            )
                          : IconButton(
                              key: const ValueKey<String>('refresh'),
                              icon: Icon(
                                Icons.refresh_rounded,
                                size: 20,
                                color: DulceColors.textSecondary,
                              ),
                              onPressed: widget.onRefresh,
                              tooltip: AppStrings.refresh,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(width: 38, height: 38),
                            ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Badge compacto que muestra el numero de elementos bloqueados
class _BlockedCounterBadge extends StatelessWidget {
  final String currentUrl;
  final Color primaryColor;

  const _BlockedCounterBadge({
    required this.currentUrl,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    // No mostrar en la pagina de inicio
    if (UrlUtils.isHomePage(currentUrl)) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: context.read<AdBlocker>(),
      builder: (BuildContext ctx, Widget? _) {
        final int count = context.read<AdBlocker>().totalBlocked;
        final bool enabled = context.read<AdBlocker>().isEnabled;

        if (!enabled || count == 0) return const SizedBox.shrink();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.block_rounded,
                size: 10,
                color: primaryColor,
              ),
              const SizedBox(width: 3),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Extension para seleccionar todo el texto
extension TextEditingControllerExtension on TextEditingController {
  void selectAll() {
    selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
  }
}
