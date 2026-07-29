// ==============================================================
// DulceNav - main.dart
// Punto de entrada. Filosofia: CERO recursos sin autorizacion.
// Plataforma actual: Windows 10/11 (Android se integra en Fase 5)
// v1.2.0 - Fase 2: registra BlocklistManager, SiteClassifier y AdBlocker
// ==============================================================

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/services/memory_manager.dart';
import 'core/services/storage_service.dart';
import 'core/services/tab_manager.dart';
import 'core/services/theme_service.dart';
import 'features/security/ad_blocker.dart';
import 'features/security/blocklist_manager.dart';
import 'features/security/cosmetic_blocker.dart';
import 'features/security/site_classifier.dart';
import 'features/ai/dulcemind_service.dart';
import 'core/services/download_manager.dart';
import 'core/services/update_service.dart';
import 'core/services/permission_manager.dart';
import 'core/services/performance_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/error_report_service.dart';
import 'core/services/password_service.dart';
import 'platform/windows/windows_webview.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorReportService.instance.init();

  // Orientaciones: solo en Android/iOS (en Windows no aplica)
  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Inicializar preferencias de usuario
  await StorageService.instance.init();

  if (Platform.isWindows) {
    await WindowsWebView.ensureEnvironmentInitialized();
  }

  // Cargar color primario inicial y configuraciones de tema
  ThemeService.instance;

  // Inicializar BlocklistManager en segundo plano
  // (carga listas guardadas o descarga por primera vez)
  final BlocklistManager blocklistManager = BlocklistManager.instance;
  final SiteClassifier siteClassifier = SiteClassifier();

  // No esperamos a que terminen: la UI arranca inmediatamente.
  // El bloqueador se activa en cuanto las listas esten listas.
  blocklistManager.initialize();
  // CosmeticBlocker usa su propia DB y se inicializa en paralelo.
  CosmeticBlocker.instance.initialize();
  PasswordService.instance.loadCredentials();

  runApp(
    MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<TabManager>(create: (_) => TabManager()),
        ChangeNotifierProvider<MemoryManager>(create: (_) => MemoryManager()),
        ChangeNotifierProvider<BlocklistManager>.value(value: blocklistManager),
        ChangeNotifierProvider<SiteClassifier>.value(value: siteClassifier),
        ChangeNotifierProvider<AdBlocker>(
          create: (_) => AdBlocker(
            blocklistManager: blocklistManager,
            siteClassifier: siteClassifier,
          ),
        ),
        ChangeNotifierProvider<DulceMindService>.value(value: DulceMindService.instance),
        ChangeNotifierProvider<ThemeService>.value(value: ThemeService.instance),
        ChangeNotifierProvider<PermissionManager>.value(value: PermissionManager.instance),
        ChangeNotifierProvider<DownloadManager>(create: (_) => DownloadManager()),
        ChangeNotifierProvider<UpdateService>(create: (_) => UpdateService()..checkForUpdates()),
        ChangeNotifierProvider<PerformanceService>.value(value: PerformanceService.instance),
        ChangeNotifierProvider<AuthService>.value(value: AuthService.instance),
        ChangeNotifierProvider<PasswordService>.value(value: PasswordService.instance),
        ChangeNotifierProvider<CosmeticBlocker>.value(value: CosmeticBlocker.instance),
      ],
      child: const DulceNavApp(),
    ),
  );
}
