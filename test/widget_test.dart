// ==============================================================
// DulceNav - widget_test.dart
// Prueba de humo de la interfaz de usuario de DulceNavApp.
// ==============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dulcenav/app.dart';
import 'package:dulcenav/core/services/storage_service.dart';
import 'package:dulcenav/core/services/memory_manager.dart';
import 'package:dulcenav/core/services/tab_manager.dart';
import 'package:dulcenav/features/security/blocklist_manager.dart';
import 'package:dulcenav/features/security/site_classifier.dart';
import 'package:dulcenav/features/security/ad_blocker.dart';
import 'package:dulcenav/features/ai/dulcemind_service.dart';
import 'package:dulcenav/core/services/theme_service.dart';
import 'package:dulcenav/core/services/download_manager.dart';
import 'package:dulcenav/core/services/update_service.dart';

void main() {
  testWidgets('DulceNavApp smoke test', (WidgetTester tester) async {
    // Inicializar mock de SharedPreferences
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.instance.init();

    final BlocklistManager blocklistManager = BlocklistManager.instance;
    final SiteClassifier siteClassifier = SiteClassifier();

    await tester.pumpWidget(
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
          ChangeNotifierProvider<DownloadManager>(create: (_) => DownloadManager()),
          ChangeNotifierProvider<UpdateService>(create: (_) => UpdateService()),
        ],
        child: const DulceNavApp(),
      ),
    );

    // Verificar que el titulo "DulceNav" se renderiza en pantalla
    expect(find.text('DulceNav'), findsWidgets);
  });
}
