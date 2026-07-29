// ==============================================================
// DulceNav - app.dart
// Raiz de la aplicacion. Configura tema, rutas y navegacion.
// ==============================================================

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'features/browser/browser_screen.dart';
import 'features/home/home_screen.dart';
import 'shared/theme/dulce_theme.dart';
import 'core/services/theme_service.dart';

class DulceNavApp extends StatelessWidget {
  const DulceNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (BuildContext context, ThemeService theme, Widget? child) {
        return MaterialApp.router(
          title: 'DulceNav',
          debugShowCheckedModeBanner: false,
          theme: DulceTheme.light,
          darkTheme: DulceTheme.dark,
          themeMode: theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          routerConfig: _router,
          builder: (BuildContext context, Widget? child) {
            final MediaQueryData mediaQueryData = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQueryData.copyWith(
                devicePixelRatio: Platform.isWindows
                    ? theme.uiScale
                    : mediaQueryData.devicePixelRatio * theme.uiScale,
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}

// Router de la aplicacion
final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      name: 'home',
      builder: (BuildContext context, GoRouterState state) {
        return const HomeScreen();
      },
    ),
    GoRoute(
      path: '/browser',
      name: 'browser',
      builder: (BuildContext context, GoRouterState state) {
        final String url =
            state.uri.queryParameters['url'] ?? 'about:dulcenav';
        return BrowserScreen(initialUrl: url);
      },
    ),
  ],
);
