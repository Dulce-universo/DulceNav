// ==============================================================
// DulceNav - security_badge.dart
// Indicador visual de seguridad del sitio actual.
// v1.2.0: Conectado con SiteClassifier via ListenableBuilder.
// Colores: verde=seguro / amarillo=riesgo / rojo=peligroso
// ==============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../features/security/ad_blocker.dart';
import '../../features/security/site_classifier.dart';

// Enum de estado del sitio (usado en toda la app)
enum SiteStatus { safe, warning, danger, unknown }

class SecurityBadge extends StatelessWidget {
  // Se puede pasar status manualmente (para pantallas sin Provider)
  // o leer automaticamente de SiteClassifier cuando useProvider=true.
  final SiteStatus? status;
  final int? blockedCount;
  final VoidCallback? onTap;
  final bool useProvider;

  const SecurityBadge({
    super.key,
    this.status,
    this.blockedCount,
    this.onTap,
    this.useProvider = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!useProvider) {
      return _BadgeContent(
        status: status ?? SiteStatus.unknown,
        blockedCount: blockedCount ?? 0,
        onTap: onTap,
      );
    }

    // Leer estado en tiempo real desde SiteClassifier y AdBlocker
    return ListenableBuilder(
      listenable: Listenable.merge(<ChangeNotifier>[
        context.read<SiteClassifier>(),
        context.read<AdBlocker>(),
      ]),
      builder: (BuildContext ctx, Widget? _) {
        final SiteStatus liveStatus =
            context.read<SiteClassifier>().currentStatus;
        final int liveBlocked = context.read<AdBlocker>().totalBlocked;

        return _BadgeContent(
          status: liveStatus,
          blockedCount: liveBlocked,
          onTap: onTap,
        );
      },
    );
  }
}

// Widget de contenido del badge (sin Provider, puro UI)
class _BadgeContent extends StatelessWidget {
  final SiteStatus status;
  final int blockedCount;
  final VoidCallback? onTap;

  const _BadgeContent({
    required this.status,
    required this.blockedCount,
    this.onTap,
  });

  Color get _color {
    switch (status) {
      case SiteStatus.safe:
        return DulceColors.safeGreen;
      case SiteStatus.warning:
        return DulceColors.warningYellow;
      case SiteStatus.danger:
        return DulceColors.dangerRed;
      case SiteStatus.unknown:
        return DulceColors.textDisabled;
    }
  }

  Color get _bgColor {
    switch (status) {
      case SiteStatus.safe:
        return DulceColors.safeGreenAlpha;
      case SiteStatus.warning:
        return DulceColors.warningYellowAlpha;
      case SiteStatus.danger:
        return DulceColors.dangerRedAlpha;
      case SiteStatus.unknown:
        return DulceColors.surfaceElevated;
    }
  }

  String get _label {
    switch (status) {
      case SiteStatus.safe:
        return AppStrings.siteStatusSafe;
      case SiteStatus.warning:
        return AppStrings.siteStatusWarning;
      case SiteStatus.danger:
        return AppStrings.siteStatusDanger;
      case SiteStatus.unknown:
        return AppStrings.siteStatusUnknown;
    }
  }

  Widget _buildIcon(Color color) {
    switch (status) {
      case SiteStatus.safe:
        return Icon(Icons.lock_rounded, size: 13, color: color);
      case SiteStatus.warning:
        return Icon(Icons.lock_open_rounded, size: 13, color: color);
      case SiteStatus.danger:
        return Icon(Icons.gpp_bad_rounded, size: 13, color: color);
      case SiteStatus.unknown:
        return Icon(Icons.lock_outline, size: 13, color: color);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildIcon(_color),
            const SizedBox(width: 5),
            Text(
              _label,
              style: TextStyle(
                color: _color,
                fontSize: 11,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
              ),
            ),
            // Contador de elementos bloqueados
            if (blockedCount > 0) ...<Widget>[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$blockedCount',
                  style: TextStyle(
                    color: _color,
                    fontSize: 10,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
