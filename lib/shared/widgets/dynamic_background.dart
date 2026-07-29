// ============================================================
// DulceNav — dynamic_background.dart
// Contenedor de fondo con degradados dinamicos y animados.
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/theme_service.dart';

class DynamicBackground extends StatefulWidget {
  final Widget child;
  final bool isIncognito;

  const DynamicBackground({
    super.key,
    required this.child,
    this.isIncognito = false,
  });

  @override
  State<DynamicBackground> createState() => _DynamicBackgroundState();
}

class _DynamicBackgroundState extends State<DynamicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final isHighContrast = theme.highContrast;

    if (widget.isIncognito) {
      if (isHighContrast) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF131324),
                Color(0xFF01020C),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: widget.child,
        );
      }
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * 2 * math.pi;
          final alignStart = Alignment(math.cos(angle), math.sin(angle));
          final alignEnd = Alignment(-math.cos(angle), -math.sin(angle));

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [
                  Color(0xFF131324),
                  Color(0xFF01020C),
                ],
                begin: alignStart,
                end: alignEnd,
              ),
            ),
            child: widget.child,
          );
        },
      );
    }

    if (isHighContrast) {
      return Container(
        color: theme.activeBackgroundColor,
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * 2 * math.pi;
        final alignStart = Alignment(math.cos(angle), math.sin(angle));
        final alignEnd = Alignment(-math.cos(angle), -math.sin(angle));

        final Color baseColor = theme.activeBackgroundColor;
        final Color primaryColor = theme.activePrimaryColor;

        // Mezclar sutilmente el color primario con el fondo para crear armonia
        final Color shiftedColor = Color.alphaBlend(
          primaryColor.withOpacity(0.04),
          baseColor,
        );

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                baseColor,
                shiftedColor,
              ],
              begin: alignStart,
              end: alignEnd,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}
