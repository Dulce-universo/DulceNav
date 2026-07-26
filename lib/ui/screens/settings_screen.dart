// ==============================================================
// DulceNav - settings_screen.dart
// Pantalla de ajustes completa. Disenho premium DulceUI.
// v1.3.4 - Integracion completa de secciones, temas y descargas.
// ==============================================================

import 'dart:io' show Platform, Process;
import 'dart:ui' show ImageFilter;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import '../../core/services/password_service.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/permission_manager.dart';
import '../../core/services/auth_service.dart';
import '../../features/security/ad_blocker.dart';
import '../../features/security/cosmetic_blocker.dart';
import '../../features/ai/dulcemind_service.dart';
import '../../core/services/update_service.dart';
import '../../core/services/download_manager.dart';
import '../../core/services/performance_service.dart';
import '../../core/services/hardware_profile_service.dart';
import '../../platform/windows/windows_webview.dart';
import 'error_report_screen.dart';
import 'passwords_screen.dart';
import 'sync_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService.instance;
  final TextEditingController _cookieWhitelistController = TextEditingController();
  final TextEditingController _cosmeticUserRulesController = TextEditingController();
  DeviceHardwareInfo? _hardwareInfo;

  @override
  void initState() {
    super.initState();
    _cosmeticUserRulesController.text = _storage.cosmeticUserRules;
    _hardwareInfo = HardwareProfileService.instance.cachedInfo;
    HardwareProfileService.instance.detect(context: context).then((info) {
      if (mounted) {
        setState(() {
          _hardwareInfo = info;
        });
      }
    });
  }

  @override
  void dispose() {
    _cookieWhitelistController.dispose();
    _cosmeticUserRulesController.dispose();
    super.dispose();
  }

  // Motores de busqueda disponibles
  static const Map<String, String> _searchEngines = {
    'https://duckduckgo.com/?q=': 'DuckDuckGo (Recomendado)',
    'https://www.google.com/search?q=': 'Google',
    'https://www.bing.com/search?q=': 'Bing',
    'https://www.ecosia.org/search?q=': 'Ecosia',
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final adBlocker = context.watch<AdBlocker>();
    final ai = context.watch<DulceMindService>();
    final perf = context.watch<PerformanceService>();
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: Colors.transparent, // Let gradient show
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121A).withOpacity(0.6),
        elevation: 0,
        title: Text(
          'Ajustes del Sistema',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: DulceColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: DulceColors.primary.withOpacity(0.2)),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: DulceColors.backgroundGradient,
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // ── SECCION 1: DULCEMIND IA LOCAL ──────────────────────
              _buildSectionCard(
                context,
                title: 'DulceMind IA Local',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      activeColor: DulceColors.primary,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Activar asistente inteligente',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        '100% local, sin internet, resume paginas y responde preguntas.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: ai.isEnabled,
                      onChanged: (val) {
                        ai.toggleEnabled(val);
                      },
                    ),
                    if (ai.isEnabled) ...[
                      const Divider(height: 24, color: Colors.white12),
                      SwitchListTile(
                        activeColor: DulceColors.primary,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Guardar historial de conversacion',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          'Conserva tu historial de chat localmente entre sesiones.',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            color: DulceColors.textSecondary,
                          ),
                        ),
                        value: _storage.aiPersistentHistory,
                        onChanged: (val) async {
                          await ai.togglePersistentHistory(val);
                          setState(() {});
                        },
                      ),
                      const Divider(height: 24, color: Colors.white12),
                      Row(
                        children: [
                          ai.isReady
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: DulceColors.safeGreen,
                                  size: 16,
                                )
                              : Icon(
                                  Icons.downloading_rounded,
                                  color: DulceColors.primary,
                                  size: 16,
                                ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ai.isReady ? 'Modelo cargado / Listo' : ai.statusMessage,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                color: ai.isReady ? DulceColors.safeGreen : Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (ai.isDownloading) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: ai.downloadProgress,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(DulceColors.primary),
                        ),
                      ],
                      if (ai.isReady) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DulceColors.dangerRed.withOpacity(0.2),
                              foregroundColor: DulceColors.dangerRed,
                              side: BorderSide(color: DulceColors.dangerRed.withOpacity(0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: Icon(Icons.delete_forever_rounded, size: 18),
                            label: Text('Borrar modelo y liberar espacio'),
                            onPressed: () => _confirmDeleteAiModel(context, ai),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── SECCION 2: MOTOR DE BUSQUEDA ──────────────────────
              _buildSectionCard(
                context,
                title: 'Motor de busqueda predeterminado',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _searchEngines.entries.map((entry) {
                    final isSelected = _storage.searchEngine == entry.key;
                    return RadioListTile<String>(
                      activeColor: DulceColors.primary,
                      contentPadding: EdgeInsets.zero,
                      value: entry.key,
                      groupValue: _storage.searchEngine,
                      title: Text(
                        entry.value,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          color: isSelected ? Colors.white : DulceColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      onChanged: (val) async {
                        if (val != null) {
                          await _storage.setSearchEngine(val);
                          setState(() {});
                        }
                      },
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // ── SECCION 3: PRIVACIDAD Y BLOQUEO ───────────────────
              _buildSectionCard(
                context,
                title: 'Proteccion y Bloqueador',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Activar bloqueador de publicidad',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Bloquea anuncios, ventanas emergentes y seguimiento en todas las paginas.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: adBlocker.isEnabled,
                      onChanged: (val) async {
                        await _storage.setAdBlockEnabled(val);
                        await _storage.setPerformanceSettingsModified(true);
                        adBlocker.setEnabled(val);
                      },
                    ),
                    const Divider(height: 24, color: Colors.white12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Elementos bloqueados hasta ahora:',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            color: DulceColors.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.activePrimaryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: theme.activePrimaryColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            '${adBlocker.totalBlocked}',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: theme.activePrimaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Colors.white12),
                    // ── Bloqueo Cosmético ──────────────────────────────────────
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Bloqueo cosmético (ocultar huecos)',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Elimina los espacios en blanco que dejan los anuncios bloqueados.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: _storage.cosmeticBlockEnabled,
                      onChanged: (val) async {
                        await _storage.setCosmeticBlockEnabled(val);
                        setState(() {});
                      },
                    ),
                    if (_storage.cosmeticBlockEnabled) ...[
                      const SizedBox(height: 4),
                      SwitchListTile(
                        activeColor: theme.activePrimaryColor,
                        contentPadding: const EdgeInsets.only(left: 16),
                        title: Text(
                          'Usar reglas de las listas oficiales',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                        subtitle: Text(
                          'EasyList, EasyPrivacy y AdGuard Mobile.',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            color: DulceColors.textSecondary,
                          ),
                        ),
                        value: _storage.cosmeticUseOfficialRules,
                        onChanged: (val) async {
                          await _storage.setCosmeticUseOfficialRules(val);
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                      // Reglas personalizadas
                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          title: Text(
                            '✏️  Mis reglas personalizadas',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: theme.activePrimaryColor,
                            ),
                          ),
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              'Una regla por línea. Formato AdBlock Plus:\n'
                              '  ##.selector   → todos los sitios\n'
                              '  dominio.com##.selector  → solo ese sitio',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                color: DulceColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _cosmeticUserRulesController,
                              maxLines: 6,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: '##.ad-banner\nyoutube.com##.ytp-ad-module',
                                hintStyle: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  color: Colors.white24,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.white12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.white12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: theme.activePrimaryColor),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () async {
                                  await CosmeticBlocker.instance.updateUserRules(
                                    _cosmeticUserRulesController.text,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Reglas personalizadas guardadas.',
                                          style: TextStyle(fontFamily: 'Outfit'),
                                        ),
                                        backgroundColor: theme.activePrimaryColor,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.save_rounded, size: 16),
                                label: const Text(
                                  'Guardar reglas',
                                  style: TextStyle(fontFamily: 'Outfit', fontSize: 13),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.activePrimaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Sitios excluidos del cosmético
                      Builder(builder: (context) {
                        final excluded = _storage.cosmeticExcludedDomains;
                        if (excluded.isEmpty) return const SizedBox.shrink();
                        return Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: EdgeInsets.zero,
                            title: Text(
                              '🚫  Sitios excluidos del cosmético (${excluded.length})',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.orange.shade300,
                              ),
                            ),
                            children: [
                              const SizedBox(height: 4),
                              ...excluded.map((domain) => ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                dense: true,
                                title: Text(
                                  domain,
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.redAccent, size: 18),
                                  onPressed: () async {
                                    await CosmeticBlocker.instance.removeExclusion(domain);
                                    setState(() {});
                                  },
                                ),
                              )),
                            ],
                          ),
                        );
                      }),
                    ],
                    const Divider(height: 24, color: Colors.white12),
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Limpieza total al cerrar',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Elimina cookies y cache del navegador automaticamente al salir.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: _storage.clearOnClose,
                      onChanged: (val) async {
                        await _storage.setClearOnClose(val);
                        await _storage.setPerformanceSettingsModified(true);
                        setState(() {});
                      },
                    ),
                    const Divider(height: 24, color: Colors.white12),
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Aislamiento de sitios (Site Isolation)',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Limpia cookies de dominios no confiables al cambiar de pagina.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: _storage.siteIsolation,
                      onChanged: (val) async {
                        await _storage.setSiteIsolation(val);
                        await _storage.setPerformanceSettingsModified(true);
                        setState(() {});
                      },
                    ),

                    const Divider(height: 24, color: Colors.white12),
                    DropdownButtonFormField<String>(
                      value: _storage.secureDnsMode,
                      dropdownColor: const Color(0xFF1E1E2E),
                      decoration: InputDecoration(
                        labelText: 'Servidor DNS seguro (DoH):',
                        labelStyle: TextStyle(color: Colors.white70, fontSize: 13),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      items: const [
                        DropdownMenuItem(value: 'off', child: Text('Desactivado (Sistema)')),
                        DropdownMenuItem(value: 'cloudflare', child: Text('Cloudflare (1.1.1.1)')),
                        DropdownMenuItem(value: 'google', child: Text('Google (8.8.8.8)')),
                        DropdownMenuItem(value: 'quad9', child: Text('Quad9 (9.9.9.9)')),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          await _storage.setSecureDnsMode(val);
                          await _storage.setPerformanceSettingsModified(true);
                          setState(() {});
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('El DNS seguro se aplicará al reiniciar la aplicación'),
                                backgroundColor: Color(0xFF1E1E2E),
                              ),
                            );
                          }
                        }
                      },
                    ),

                    const Divider(height: 24, color: Colors.white12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.key_rounded, color: theme.activePrimaryColor, size: 20),
                      title: Text(
                        'Administrar contraseñas guardadas',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Ver, buscar, revelar y eliminar tus contraseñas cifradas de forma nativa.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: Colors.white70),
                      onTap: () async {
                        final verified = await PasswordService.instance.requestAccess(context, 'Confirmar identidad para ver contraseñas');
                        if (verified && context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const PasswordsScreen()),
                          );
                        }
                      },
                    ),
                    const Divider(height: 24, color: Colors.white12),
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Proteger mis contraseñas',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Bloquea el acceso al gestor y el autocompletado con biometria o clave.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: _storage.passwordProtectionEnabled,
                      onChanged: (val) async {
                        if (val) {
                          final verified = await PasswordService.instance.requestAccess(context, 'Verifica tu identidad para activar la proteccion');
                          if (!verified) return;
                        }
                        await _storage.setPasswordProtectionEnabled(val);
                        setState(() {});
                      },
                    ),
                    if (_storage.passwordProtectionEnabled) ...[
                      const Divider(height: 24, color: Colors.white12),
                      DropdownButtonFormField<int>(
                        value: _storage.passwordGracePeriodMinutes,
                        dropdownColor: const Color(0xFF1E1E2E),
                        decoration: InputDecoration(
                          labelText: 'Solicitar verificacion cada:',
                          labelStyle: TextStyle(color: Colors.white70, fontSize: 13),
                          border: InputBorder.none,
                        ),
                        style: TextStyle(color: Colors.white, fontSize: 14),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 minuto')),
                          DropdownMenuItem(value: 5, child: Text('5 minutos')),
                          DropdownMenuItem(value: 15, child: Text('15 minutos')),
                          DropdownMenuItem(value: -1, child: Text('Solo al abrir la app')),
                        ],
                        onChanged: (val) async {
                          if (val != null) {
                            await _storage.setPasswordGracePeriodMinutes(val);
                            PasswordService.instance.resetGracePeriod();
                            setState(() {});
                          }
                        },
                      ),
                      const Divider(height: 24, color: Colors.white12),
                      SwitchListTile(
                        activeColor: theme.activePrimaryColor,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Usar solo clave propia (sin biometria)',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        value: _storage.passwordCustomPinOnly,
                        onChanged: (val) async {
                          await _storage.setPasswordCustomPinOnly(val);
                          setState(() {});
                        },
                      ),
                      const Divider(height: 24, color: Colors.white12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.pin_rounded, color: theme.activePrimaryColor, size: 20),
                        title: Text(
                          _storage.passwordCustomPinHash.isEmpty
                              ? 'Configurar clave propia de DulceNav'
                              : 'Cambiar clave propia de DulceNav',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right_rounded, color: Colors.white70),
                        onTap: () => _showConfigurePinDialog(context),
                      ),
                    ],
                    const Divider(height: 24, color: Colors.white12),

                    // ── Autocompletar Credenciales ─────────────
                    Text(
                      'Autocompletar Credenciales',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: theme.activePrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Activar autocompletar credenciales',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: const Text(
                        'Detecta campos de inicio de sesión y ofrece autocompletado rápido.',
                        style: TextStyle(color: Colors.white30, fontSize: 11),
                      ),
                      value: _storage.autofillEnabled,
                      onChanged: (val) async {
                        await _storage.setAutofillEnabled(val);
                        setState(() {});
                      },
                    ),
                    if (_storage.autofillEnabled) ...[
                      const Divider(height: 24, color: Colors.white12),
                      SwitchListTile(
                        activeColor: theme.activePrimaryColor,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Desactivar en modo incógnito',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: const Text(
                          'Evita ofrecer autocompletado al navegar en pestañas de incógnito.',
                          style: TextStyle(color: Colors.white30, fontSize: 11),
                        ),
                        value: _storage.autofillDisableInIncognito,
                        onChanged: (val) async {
                          await _storage.setAutofillDisableInIncognito(val);
                          setState(() {});
                        },
                      ),
                      const Divider(height: 24, color: Colors.white12),
                      
                      // Sitios excluidos de autocompletado
                      Text(
                        'Sitios excluidos del autocompletado:',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      (() {
                        final excluded = _storage.autofillExcludedDomains;
                        if (excluded.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No hay sitios excluidos.',
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          );
                        }
                        return Column(
                          children: excluded.map((domain) {
                            return Card(
                              color: Colors.black26,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        domain,
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                      onPressed: () async {
                                        await _storage.removeAutofillExcludedDomain(domain);
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      })(),
                    ],
                    const Divider(height: 24, color: Colors.white12),
                    
                    // Gestion de permisos de sitios
                    ListenableBuilder(
                      listenable: PermissionManager.instance,
                      builder: (context, _) {
                        final manager = PermissionManager.instance;
                        final rules = manager.siteRules;
                        if (rules.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No hay permisos especificos de sitios guardados.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text('Permisos de sitios:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            ...rules.entries.map((entry) {
                              final domain = entry.key;
                              final perms = entry.value;
                              return Card(
                                color: Colors.black26,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(domain, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                            const SizedBox(height: 2),
                                            Text(
                                              perms.entries.map((e) => '${e.key}: ${e.value.name}').join(', '),
                                              style: TextStyle(color: Colors.white70, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                        onPressed: () {
                                          manager.revokeAllForDomain(domain);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      }
                    ),

                    // Lista blanca de cookies
                    StatefulBuilder(
                      builder: (context, setSubState) {
                        final list = _storage.cookieWhitelist;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 24, color: Colors.white12),
                            Text('Lista blanca de Cookies:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 8),
                            if (list.isEmpty)
                              Text('No hay dominios en la lista blanca.', style: TextStyle(color: Colors.white60, fontSize: 12))
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: list.map((domain) {
                                  return Chip(
                                    backgroundColor: Colors.white10,
                                    label: Text(domain, style: TextStyle(color: Colors.white, fontSize: 12)),
                                    deleteIcon: Icon(Icons.close_rounded, size: 14, color: Colors.white70),
                                    onDeleted: () async {
                                      final newList = List<String>.from(list)..remove(domain);
                                      await _storage.setCookieWhitelist(newList);
                                      setSubState(() {});
                                      setState(() {});
                                    },
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _cookieWhitelistController,
                                    style: TextStyle(color: Colors.white, fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'ej. google.com',
                                      hintStyle: TextStyle(color: Colors.white30),
                                      filled: true,
                                      fillColor: Colors.black26,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white10)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.activePrimaryColor)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.activePrimaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  onPressed: () async {
                                    final val = _cookieWhitelistController.text.trim().toLowerCase();
                                    if (val.isNotEmpty && !list.contains(val)) {
                                      final newList = List<String>.from(list)..add(val);
                                      await _storage.setCookieWhitelist(newList);
                                      _cookieWhitelistController.clear();
                                      setSubState(() {});
                                      setState(() {});
                                    }
                                  },
                                  child: Icon(Icons.add_rounded, size: 18),
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── SECCION EXTRA: MENU CONTEXTUAL Y BUSQUEDA ──────────
              _buildSectionCard(
                context,
                title: 'Menu Contextual y Busquedas',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Activar menu contextual personalizado',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Reemplaza el menu de Windows con un menu DulceUI disenado para links, imagenes y texto.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: _storage.contextMenuEnabled,
                      onChanged: (val) async {
                        await _storage.setContextMenuEnabled(val);
                        setState(() {});
                      },
                    ),
                    const Divider(height: 24, color: Colors.white12),
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Optimizar busquedas sobre seleccion',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Limpia caracteres especiales y espacios multiples al buscar texto seleccionado.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: _storage.searchOptimizerEnabled,
                      onChanged: (val) async {
                        await _storage.setSearchOptimizerEnabled(val);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── SECCION 4: DESCARGAS ──────────────────────────────
              _buildSectionCard(
                context,
                title: 'Ubicacion de descargas',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      activeColor: DulceColors.primary,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Preguntar donde guardar cada archivo',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Muestra un dialogo de confirmacion antes de iniciar cada descarga.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: _storage.askDownloadLocation,
                      onChanged: (val) async {
                        await _storage.setAskDownloadLocation(val);
                        setState(() {});
                      },
                    ),
                    const Divider(height: 24, color: Colors.white12),
                    Text(
                      'Carpeta de destino actual:',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: DulceColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        _storage.downloadPath,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DulceColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: Icon(Icons.folder_open_rounded, size: 18),
                        label: Text('Cambiar carpeta...'),
                        onPressed: () => _showChangeDownloadPathDialog(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── SECCION 5: APARIENCIA ─────────────────────────────
              _buildSectionCard(
                context,
                title: 'Tema y Estilo',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preajustes de tema:',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceAround,
                        children: [
                          _buildColorPresetOption(theme, ThemePreset.dulceClassic, const Color(0xFF6C63FF), 'Clasico'),
                          _buildColorPresetOption(theme, ThemePreset.deepOcean, const Color(0xFF0091FF), 'Oceanico'),
                          _buildColorPresetOption(theme, ThemePreset.emerald, const Color(0xFF00FFB2), 'Esmeralda'),
                          _buildColorPresetOption(theme, ThemePreset.ruby, const Color(0xFFFF2D55), 'Rubi'),
                          _buildColorPresetOption(theme, ThemePreset.absoluteNight, const Color(0xFFE0E0E0), 'Noche'),
                          _buildColorPresetOption(theme, ThemePreset.auto, const Color(0xFF8A2BE2), 'Auto', icon: Icon(Icons.color_lens_rounded)),
                        ],
                      ),
                    ),
                     const Divider(height: 32, color: Colors.white12),
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Modo Oscuro',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: DulceColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Alterna entre el tema claro (luminoso) y oscuro (protección visual).',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: theme.isDarkMode,
                      onChanged: (val) {
                        theme.setDarkMode(val);
                      },
                    ),
                    const Divider(height: 32, color: Colors.white12),
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Modo Alto Contraste',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Aumenta la opacidad de los colores de fondo y hace mas visibles los bordes.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: theme.highContrast,
                      onChanged: (val) {
                        theme.setHighContrast(val);
                      },
                    ),
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Usar colores adaptativos del sitio web',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Cambia sutilmente el color de la barra superior y de pestañas para coincidir con la web actual.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: _storage.adaptiveThemeEnabled,
                      onChanged: (val) async {
                        await _storage.setAdaptiveThemeEnabled(val);
                        await _storage.setPerformanceSettingsModified(true);
                        setState(() {});
                      },
                    ),
                    const Divider(height: 32, color: Colors.white12),
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Mostrar barra de favoritos',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Muestra la barra de marcadores de forma horizontal debajo de la barra URL.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: _storage.showBookmarksBar,
                      onChanged: (val) async {
                        await _storage.setShowBookmarksBar(val);
                        setState(() {});
                      },
                    ),
                    const Divider(height: 32, color: Colors.white12),
                    Text(
                      'Intensidad del Desenfoque (Efecto Vidrio):',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildBlurOption(theme, BlurIntensity.light, 'Suave'),
                        const SizedBox(width: 12),
                        _buildBlurOption(theme, BlurIntensity.medium, 'Medio'),
                        const SizedBox(width: 12),
                        _buildBlurOption(theme, BlurIntensity.intense, 'Intenso'),
                      ],
                    ),
                    const Divider(height: 32, color: Colors.white12),
                    Text(
                      'Escala de interfaz:',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildScaleOption(theme, 1.0, '100%'),
                        const SizedBox(width: 12),
                        _buildScaleOption(theme, 1.1, '110%'),
                        const SizedBox(width: 12),
                        _buildScaleOption(theme, 1.2, '120%'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── SECCION 6: TECLADO Y ATAJOS ───────────────────────
              _buildSectionCard(
                context,
                title: 'Teclado y Atajos',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lista completa de combinaciones disponibles:',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: DulceColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildShortcutRow('Ctrl + T', 'Nueva pestana (pantalla de inicio)'),
                    _buildShortcutRow('Ctrl + Shift + N', 'Nueva pestana de incognito (navegacion privada)'),
                    _buildShortcutRow('Ctrl + W / Ctrl + F4', 'Cerrar pestana actual'),
                    _buildShortcutRow('Ctrl + Tab', 'Siguiente pestana'),
                    _buildShortcutRow('Ctrl + Shift + Tab', 'Pestana anterior'),
                    _buildShortcutRow('Ctrl + H', 'Abrir / Cerrar Historial'),
                    _buildShortcutRow('Ctrl + D', 'Agregar pagina actual a favoritos'),
                    _buildShortcutRow('Ctrl + J', 'Abrir gestor de descargas'),
                    _buildShortcutRow('Ctrl + R / F5', 'Recargar pagina'),
                    _buildShortcutRow('Ctrl + Shift + R', 'Recargar pagina sin cache'),
                    _buildShortcutRow('Alt + Izquierda / Derecha', 'Ir a pagina anterior / siguiente'),
                    _buildShortcutRow('Ctrl + L / F6', 'Seleccionar barra de direcciones'),
                    _buildShortcutRow('Ctrl + + / Ctrl + -', 'Aumentar / Reducir zoom'),
                    _buildShortcutRow('Ctrl + 0', 'Restablecer zoom al 100%'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── SECCION 7: NAVEGACION PRIVADA ─────────────────────
              _buildSectionCard(
                context,
                title: 'Navegacion Privada / Modo Incognito',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DulceNav incluye una sesion especial aislada donde:',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildIncognitoFeatureRow(Icon(Icons.history_toggle_off_rounded), 'No se guarda historial de navegacion.'),
                    _buildIncognitoFeatureRow(Icon(Icons.cookie_outlined), 'No se guardan cookies ni sesiones de inicio de sesion.'),
                    _buildIncognitoFeatureRow(Icon(Icons.cleaning_services_rounded), 'No se guarda cache ni archivos temporales.'),
                    _buildIncognitoFeatureRow(Icon(Icons.download_done_rounded), 'Las descargas no se muestran en el gestor.'),
                    _buildIncognitoFeatureRow(Icon(Icons.auto_delete_rounded), 'Al cerrar la pestana, se borra todo rastro.'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── SECCION 8: RENDIMIENTO Y RECURSOS ─────────────────
              _buildSectionCard(
                context,
                title: 'Rendimiento y Recursos',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Modo Juego / Transmision',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Limita los FPS a 30 y optimiza el uso de CPU/RAM para no interferir con juegos o transmisiones.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: perf.isGameModeActive,
                      onChanged: (val) {
                        perf.setGameMode(val, manual: true);
                      },
                    ),
                    const Divider(height: 24, color: Colors.white12),
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Activar hibernación de pestañas',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Suspende automáticamente las pestañas en segundo plano inactivas para ahorrar RAM y batería.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: _storage.tabHibernateEnabled,
                      onChanged: (val) async {
                        await _storage.setTabHibernateEnabled(val);
                        await _storage.setPerformanceSettingsModified(true);
                        setState(() {});
                      },
                    ),
                    if (_storage.tabHibernateEnabled) ...[
                      const Divider(height: 24, color: Colors.white12),
                      DropdownButtonFormField<int>(
                        value: const [5, 15, 30, 60].contains(_storage.tabHibernateMinutes) ? _storage.tabHibernateMinutes : 15,
                        dropdownColor: const Color(0xFF1E1E2E),
                        decoration: InputDecoration(
                          labelText: 'Suspender pestañas tras inactividad de:',
                          labelStyle: TextStyle(color: Colors.white70, fontSize: 13),
                          border: InputBorder.none,
                        ),
                        style: TextStyle(color: Colors.white, fontSize: 14),
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5 minutos')),
                          DropdownMenuItem(value: 15, child: Text('15 minutos')),
                          DropdownMenuItem(value: 30, child: Text('30 minutos')),
                          DropdownMenuItem(value: 60, child: Text('60 minutos')),
                        ],
                        onChanged: (val) async {
                          if (val != null) {
                            await _storage.setTabHibernateMinutes(val);
                            await _storage.setPerformanceSettingsModified(true);
                            setState(() {});
                          }
                        },
                      ),
                    ],
                    const Divider(height: 24, color: Colors.white12),
                    DropdownButtonFormField<int>(
                      value: _storage.maxCacheSizeMb,
                      dropdownColor: const Color(0xFF1E1E2E),
                      decoration: InputDecoration(
                        labelText: 'Limite maximo de cache en disco:',
                        labelStyle: TextStyle(color: Colors.white70, fontSize: 13),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      items: const [
                        DropdownMenuItem(value: 40, child: Text('40 MB')),
                        DropdownMenuItem(value: 80, child: Text('80 MB (Recomendado)')),
                        DropdownMenuItem(value: 120, child: Text('120 MB')),
                        DropdownMenuItem(value: 200, child: Text('200 MB')),
                        DropdownMenuItem(value: 500, child: Text('500 MB')),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          await _storage.setMaxCacheSizeMb(val);
                          setState(() {});
                        }
                      },
                    ),
                    const Divider(height: 24, color: Colors.white12),
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Limpieza automatica de cache',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Borra automaticamente archivos de cache con mas de 7 dias de antiguedad al iniciar.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: _storage.autoCleanCache,
                      onChanged: (val) async {
                        await _storage.setAutoCleanCache(val);
                        setState(() {});
                      },
                    ),
                    const Divider(height: 24, color: Colors.white12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.activePrimaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: Icon(Icons.cleaning_services_rounded, size: 18),
                        label: Text('Limpiar cache ahora'),
                        onPressed: () async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          );
                          await WindowsWebView.clearCacheNow();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Cache limpia correctamente',
                                  style: TextStyle(fontFamily: 'Outfit', color: Colors.white),
                                ),
                                backgroundColor: const Color(0xFF1E1E2E),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── SECCION 8B: PERFIL DEL DISPOSITIVO ────────────────
              _buildSectionCard(
                context,
                title: 'Perfil del dispositivo',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Resumen de Hardware
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: _hardwareInfo == null
                          ? const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Detectando hardware...',
                                  style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.devices_other_rounded, color: Colors.white70, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Hardware Detectado:',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '• Sistema Operativo: ${_hardwareInfo!.osName}',
                                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.white70),
                                ),
                                Text(
                                  '• Procesador: ${_hardwareInfo!.cpuName} (${_hardwareInfo!.cpuCores} nucleos)',
                                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.white70),
                                ),
                                Text(
                                  '• Memoria RAM: ${_hardwareInfo!.totalRamGb.toStringAsFixed(1)} GB',
                                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.white70),
                                ),
                                Text(
                                  '• Resolucion: ${_hardwareInfo!.screenResolution}',
                                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.white70),
                                ),
                                Text(
                                  '• Espacio en C:: ${_hardwareInfo!.freeStorageGb.toStringAsFixed(1)} GB libres',
                                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ),
                    ),

                    const SizedBox(height: 4),
                    Text(
                      'Elige un perfil para optimizar la velocidad y seguridad de forma automatica:',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12.5,
                        color: DulceColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Tarjetas de perfiles
                    _buildProfileCard(
                      title: 'Ahorro de Recursos',
                      description: 'Ideal para dispositivos con menos de 4 GB de RAM o maquinas antiguas.',
                      icon: Icons.battery_saver_rounded,
                      color: Colors.orangeAccent,
                      details: const [
                        '• Hibernacion de pestañas: 5 minutos',
                        '• Bloqueador de publicidad: Maximo',
                        '• Colores adaptativos y desenfoque: Desactivado',
                        '• DNS sobre HTTPS: Desactivado (Sistema)',
                      ],
                      isSelected: _storage.performanceProfile == 'ahorroRecursos' || 
                          (_storage.performanceProfile == 'auto' && _hardwareInfo != null && 
                           HardwareProfileService.instance.recommendProfile(_hardwareInfo!) == PerformanceProfile.ahorroRecursos),
                      onTap: () => _changeProfile(PerformanceProfile.ahorroRecursos),
                    ),

                    _buildProfileCard(
                      title: 'Equilibrado',
                      description: 'Ideal para equipos de 4 a 8 GB de RAM. Balance optimo de velocidad y efectos visuales.',
                      icon: Icons.balance_rounded,
                      color: Colors.lightBlueAccent,
                      details: const [
                        '• Hibernacion de pestañas: 15 minutos',
                        '• Bloqueador de publicidad: Estandar',
                        '• Colores adaptativos y desenfoque: Habilitado (Medio)',
                        '• DNS sobre HTTPS: Cloudflare (1.1.1.1)',
                      ],
                      isSelected: _storage.performanceProfile == 'equilibrado' || 
                          (_storage.performanceProfile == 'auto' && _hardwareInfo != null && 
                           HardwareProfileService.instance.recommendProfile(_hardwareInfo!) == PerformanceProfile.equilibrado),
                      onTap: () => _changeProfile(PerformanceProfile.equilibrado),
                    ),

                    _buildProfileCard(
                      title: 'Rendimiento Maximo',
                      description: 'Para equipos potentes con mas de 8 GB de RAM y mas de 8 nucleos.',
                      icon: Icons.bolt_rounded,
                      color: Colors.amberAccent,
                      details: const [
                        '• Hibernacion de pestañas: 30 minutos',
                        '• Bloqueador de publicidad: Estandar',
                        '• Colores adaptativos y desenfoque: Habilitado (Intenso)',
                        '• DNS sobre HTTPS: Cloudflare (1.1.1.1)',
                      ],
                      isSelected: _storage.performanceProfile == 'rendimientoMaximo' || 
                          (_storage.performanceProfile == 'auto' && _hardwareInfo != null && 
                           HardwareProfileService.instance.recommendProfile(_hardwareInfo!) == PerformanceProfile.rendimientoMaximo),
                      onTap: () => _changeProfile(PerformanceProfile.rendimientoMaximo),
                    ),

                    _buildProfileCard(
                      title: 'Privacidad Maxima',
                      description: 'Enfoque total en proteger tu identidad, borrar sesiones y navegar blindado.',
                      icon: Icons.security_rounded,
                      color: Colors.greenAccent,
                      details: const [
                        '• Hibernacion de pestañas: 15 minutos',
                        '• Bloqueador de publicidad: Maximo',
                        '• DNS sobre HTTPS: Quad9 (9.9.9.9)',
                        '• Aislamiento de sitios y borrar al cerrar: Habilitado',
                      ],
                      isSelected: _storage.performanceProfile == 'privacidadMaxima',
                      onTap: () => _changeProfile(PerformanceProfile.privacidadMaxima),
                    ),

                    const SizedBox(height: 8),

                    // 3. Boton restaurar recomendacion automatica
                    if (_hardwareInfo != null)
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: DulceColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: DulceColors.primary.withOpacity(0.2)),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            'Restaurar recomendacion automatica',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _restoreRecommendedProfile,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── SECCION 8C: INTELIGENCIA ARTIFICIAL LOCAL (DULCEMIND) ──
              _buildSectionCard(
                context,
                title: 'Inteligencia Artificial Local (DulceMind)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Activar DulceMind IA',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Habilita el asistente inteligente 100% local para resumir, explicar y chatear sin internet.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: _storage.aiEnabled,
                      onChanged: (val) async {
                        await ai.toggleEnabled(val);
                        setState(() {});
                      },
                    ),

                    SwitchListTile(
                      activeColor: theme.activePrimaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Ocultar completamente la función de IA',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Oculta todos los botones, atajos y menús de IA de la barra de direcciones y del navegador.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: _storage.aiHideFeature,
                      onChanged: (val) async {
                        await ai.toggleHideFeature(val);
                        setState(() {});
                      },
                    ),

                    if (_storage.aiEnabled && !_storage.aiHideFeature) ...[
                      const Divider(height: 24, color: Colors.white12),

                      // Tarjeta informativa de IA Opcional
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.activePrimaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.activePrimaryColor.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '🤖 Función 100% Opcional y Privada',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            const Text(
                              'La IA funciona dentro de tu dispositivo. No requiere Ollama ni servicios externos. Si no la usas, el navegador funciona exactamente igual.',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11.5,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ESTADO DEL MODELO
                      Row(
                        children: [
                          Icon(
                            ai.isModelDownloaded ? Icons.check_circle_rounded : Icons.file_download_rounded,
                            color: ai.isModelDownloaded ? DulceColors.safeGreen : DulceColors.warningYellow,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ai.statusMessage,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // PROGRESO DE DESCARGA
                      if (ai.isDownloading) ...[
                        LinearProgressIndicator(
                          value: ai.downloadProgress > 0 ? ai.downloadProgress : null,
                          backgroundColor: Colors.white12,
                          color: theme.activePrimaryColor,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(ai.downloadProgress * 100).toStringAsFixed(1)}% | ${ai.downloadSpeed}',
                              style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.white70),
                            ),
                            TextButton(
                              onPressed: () => ai.cancelDownload(),
                              child: const Text('Cancelar', style: TextStyle(color: DulceColors.dangerRed, fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // BOTONES DE DESCARGA / GESTION
                      if (!ai.isModelDownloaded && !ai.isDownloading) ...[
                        Text(
                          'Descargar modelo local recomendado (1 clic):',
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: DulceColors.textSecondary),
                        ),
                        const SizedBox(height: 8),

                        ...DulceMindService.recommendedModels.map((m) {
                          final isRec = ai.recommendModel() == m['id'];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isRec ? theme.activePrimaryColor : Colors.white10,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.download_rounded, size: 18),
                                label: Text(
                                  'Descargar ${m['name']} (${m['size']}) ${isRec ? "★" : ""}',
                                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => ai.downloadModel(m),
                              ),
                            ),
                          );
                        }),
                      ],

                      // BOTON DE ELIMINAR MODELO
                      if (ai.isModelDownloaded && !ai.isDownloading) ...[
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: DulceColors.dangerRed,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: DulceColors.dangerRed.withOpacity(0.3)),
                              ),
                            ),
                            icon: const Icon(Icons.delete_forever_rounded, size: 18),
                            label: const Text(
                              'Eliminar modelo descargado para liberar espacio',
                              style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _confirmDeleteAiModel(context, ai),
                          ),
                        ),
                      ],

                      const Divider(height: 24, color: Colors.white12),

                      SwitchListTile(
                        activeColor: theme.activePrimaryColor,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Mantener modelo cargado en memoria RAM',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          'OFF por defecto. Si se desactiva, el modelo se descarga automáticamente tras 5 min de inactividad.',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            color: DulceColors.textSecondary,
                          ),
                        ),
                        value: _storage.aiKeepLoaded,
                        onChanged: (val) async {
                          await ai.toggleKeepLoaded(val);
                          setState(() {});
                        },
                      ),

                      const Divider(height: 24, color: Colors.white12),

                      if (ai.chatHistory.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: DulceColors.dangerRed,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: DulceColors.dangerRed.withOpacity(0.2)),
                              ),
                            ),
                            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                            label: const Text(
                              'Borrar historial de chat',
                              style: TextStyle(fontFamily: 'Outfit', fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              await ai.clearChatHistory();
                              setState(() {});
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── SECCION 9: SISTEMA Y ACTUALIZACIONES ──────────────
              _buildSectionCard(
                context,
                title: 'Sistema y Actualizaciones',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSystemInfoRow('Version instalada', UpdateService.currentVersion),
                    _buildSystemInfoRow('Arquitectura', 'x64'),
                    _buildSystemInfoRow('Carpeta de instalacion', _getInstallationFolder()),
                    const Divider(height: 24, color: Colors.white12),

                    // Estado de actualizacion reactivo
                    Consumer<UpdateService>(
                      builder: (context, updateService, _) {
                        if (updateService.state == UpdateState.checking) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white70)),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Buscando actualizaciones...',
                                  style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Colors.white70),
                                ),
                              ],
                            ),
                          );
                        }

                        if (updateService.state == UpdateState.updateAvailable) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D4FF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Actualizacion disponible: v${updateService.latestVersion}',
                                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF00D4FF)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      updateService.notes,
                                      style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00D4FF),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: Icon(Icons.download_rounded, size: 18),
                                  label: Text('Descargar actualizacion ahora'),
                                  onPressed: () {
                                    final dm = context.read<DownloadManager>();
                                    updateService.startDownloadUpdate(dm);
                                  },
                                ),
                              ),
                            ],
                          );
                        }

                        if (updateService.state == UpdateState.downloading) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LinearProgressIndicator(
                                value: updateService.progress,
                                backgroundColor: Colors.white10,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Descargando actualizacion: ${(updateService.progress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          );
                        }

                        if (updateService.state == UpdateState.downloaded) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Actualizacion lista para instalar.',
                                style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: DulceColors.safeGreen),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: DulceColors.safeGreen,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: Icon(Icons.install_desktop_rounded, size: 18),
                                  label: Text('Instalar ahora y reiniciar'),
                                  onPressed: () => updateService.installAndRestart(),
                                ),
                              ),
                            ],
                          );
                        }

                        if (updateService.state == UpdateState.noUpdate) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: DulceColors.safeGreen, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'DulceNav esta actualizado',
                                  style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: DulceColors.safeGreen, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }

                        // Caso idle o error
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (updateService.errorMessage != null) ...[
                              Text(
                                updateService.errorMessage!,
                                style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: DulceColors.dangerRed),
                              ),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DulceColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: Icon(Icons.refresh_rounded, size: 18),
                                label: Text('Buscar actualizaciones ahora'),
                                onPressed: () => updateService.checkForUpdates(manual: true),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: Icon(Icons.folder_open_rounded, size: 18),
                            label: Text('Abrir carpeta'),
                            onPressed: _openInstallationFolder,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: Icon(Icons.info_outline_rounded, size: 18),
                            label: Text('Acerca de'),
                            onPressed: () => _showAboutDialogInSettings(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: BorderSide(color: Colors.redAccent, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: Icon(Icons.bug_report_rounded, size: 18),
                        label: Text('Reportar un problema', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => ErrorReportScreen(
                              onOpenUrl: (url) {
                                Process.start('explorer', [url]);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // -- SECCION: CUENTAS Y SESIONES ---------------------------
              _buildSectionCard(
                context,
                title: 'Cuentas y Sesiones',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Toggles de configuracion
                    SwitchListTile(
                      activeColor: DulceColors.primary,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Guardar sesiones automaticamente',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Detecta y registra logins en sitios web para persistir sesiones.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: auth.autoSaveSessions,
                      onChanged: (val) async {
                        await auth.setAutoSaveSessions(val);
                        setState(() {});
                      },
                    ),
                    const Divider(height: 24, color: Colors.white12),
                    SwitchListTile(
                      activeColor: DulceColors.primary,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Notificar cuando se detecta un login',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Muestra un aviso cuando DulceNav detecta que iniciaste sesion.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      value: auth.loginNotifications,
                      onChanged: (val) async {
                        await auth.setLoginNotifications(val);
                        setState(() {});
                      },
                    ),
                    const Divider(height: 24, color: Colors.white12),
                    // Header de sesiones activas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sesiones activas (${auth.sessionCount})',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        if (auth.hasSavedSessions)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: DulceColors.dangerRed,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            icon: Icon(Icons.logout_rounded, size: 14),
                            label: Text(
                              'Cerrar todas',
                              style: TextStyle(fontFamily: 'Outfit', fontSize: 12),
                            ),
                            onPressed: () async {
                              await auth.clearAllSessions();
                              if (mounted) setState(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Lista de dominios con sesion activa
                    if (!auth.hasSavedSessions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No hay sesiones guardadas.',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            color: DulceColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      ...auth.sessionDomains.map((domain) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                size: 14,
                                color: DulceColors.safeGreen,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  domain,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.white38,
                                ),
                                tooltip: 'Cerrar sesion de $domain',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  await auth.clearSession(domain);
                                  if (mounted) setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    const Divider(height: 24, color: Colors.white12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.sync_rounded, color: DulceColors.primary),
                      title: Text(
                        'Sincronización Cifrada (AES-256)',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Sincroniza favoritos, contraseñas e historial de forma segura entre tus dispositivos.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: DulceColors.textSecondary,
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white30),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SyncSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Construye una tarjeta esmerilada premium (glassmorphism)
  Widget _buildSectionCard(BuildContext context, {required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: DulceColors.primary.withOpacity(0.08), // Dynamic glow
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF181828).withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: DulceColors.primary.withOpacity(0.3),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Opcion de color circular interactiva para preajustes
  Widget _buildColorPresetOption(ThemeService theme, ThemePreset preset, Color color, String label, {Widget? icon}) {
    final isSelected = theme.preset == preset;
    return GestureDetector(
      onTap: () {
        theme.setPreset(preset);
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: preset == ThemePreset.absoluteNight ? Colors.grey[900] : color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white12,
                width: isSelected ? 2.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(isSelected ? 0.6 : 0.2),
                  blurRadius: isSelected ? 12 : 4,
                  spreadRadius: isSelected ? 1 : 0,
                )
              ],
            ),
            child: icon != null
                ? IconTheme(
                    data: IconThemeData(
                      color: isSelected ? Colors.white : Colors.white70,
                      size: 18,
                    ),
                    child: icon,
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: isSelected ? Colors.white : DulceColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // Opcion de desenfoque interactiva
  Widget _buildBlurOption(ThemeService theme, BlurIntensity intensity, String label) {
    final isSelected = theme.blur == intensity;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          theme.setBlur(intensity);
          await _storage.setPerformanceSettingsModified(true);
          setState(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.activePrimaryColor : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.white24 : Colors.white10,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: isSelected ? Colors.white : DulceColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // Opcion de escala interactiva
  Widget _buildScaleOption(ThemeService theme, double scale, String label) {
    final isSelected = (theme.uiScale - scale).abs() < 0.01;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          theme.setUiScale(scale);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.activePrimaryColor : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.white24 : Colors.white10,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: isSelected ? Colors.white : DulceColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // Dialogo para cambiar la ruta de descargas de forma manual
  void _showChangeDownloadPathDialog(BuildContext context) {
    final controller = TextEditingController(text: _storage.downloadPath);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white12),
          ),
          title: Text(
            'Ruta de Descargas',
            style: TextStyle(
              fontFamily: 'Outfit',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresa la ruta fisica en tu sistema:',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: DulceColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black26,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: DulceColors.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancelar', style: TextStyle(color: DulceColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DulceColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final path = controller.text.trim();
                if (path.isNotEmpty) {
                  // Asegurar que termine en barra invertida si es Windows
                  var finalPath = path;
                  if (!finalPath.endsWith('\\') && !finalPath.endsWith('/')) {
                    finalPath += '\\';
                  }
                  await _storage.setDownloadPath(finalPath);
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  if (mounted) {
                    setState(() {});
                  }
                }
              },
              child: Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  // Dialogo para confirmar borrado del modelo de IA
  void _confirmDeleteAiModel(BuildContext context, DulceMindService ai) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white12),
          ),
          title: Text(
            'Borrar modelo de IA',
            style: TextStyle(
              fontFamily: 'Outfit',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '¿Está seguro de que desea eliminar el modelo DulceMind local de su almacenamiento y liberar ~1.2 GB en disco?',
            style: TextStyle(
              fontFamily: 'Outfit',
              color: DulceColors.textSecondary,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancelar', style: TextStyle(color: DulceColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DulceColors.dangerRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                await ai.deleteDownloadedModel();
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
              },
              child: Text('Borrar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildShortcutRow(String keys, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              keys,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: DulceColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              action,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncognitoFeatureRow(Widget icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          IconTheme(
            data: IconThemeData(
              size: 16,
              color: Color(0xFF00D4FF),
            ),
            child: icon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                color: DulceColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInstallationFolder() {
    try {
      final exePath = Platform.resolvedExecutable;
      return p.dirname(exePath);
    } catch (_) {
      return 'Desconocida';
    }
  }

  void _openInstallationFolder() {
    if (Platform.isWindows) {
      final folder = _getInstallationFolder();
      Process.run('explorer.exe', [folder]);
    }
  }

  void _showAboutDialogInSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white12),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: DulceColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.travel_explore_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Acerca de DulceNav',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DulceNav - Navegador Privado',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version: v${UpdateService.currentVersion}',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: DulceColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Desarrollado con tecnologia Flutter y WebView2.\n'
                'Navegacion rapida, segura y 100% privada.',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: DulceColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DulceColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _showConfigurePinDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
        title: Row(
          children: [
            Icon(Icons.pin_rounded, color: DulceColors.primary),
            const SizedBox(width: 8),
            const Text(
              'Configurar Clave',
              style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa una clave o PIN de respaldo personalizado para proteger tus contraseñas:',
              style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nueva Clave / PIN',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DulceColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                final bytes = utf8.encode(val);
                final digest = sha256.convert(bytes);
                await _storage.setPasswordCustomPinHash(digest.toString());
                if (ctx.mounted) Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Clave configurada exitosamente'),
                    backgroundColor: Color(0xFF1E1E2E),
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeProfile(PerformanceProfile profile) async {
    if (_storage.performanceSettingsModified) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              const Text(
                '¿Sobrescribir ajustes?',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Has personalizado tus ajustes de rendimiento y seguridad. Si aplicas este perfil, se sobrescribiran tus cambios manuales. ¿Deseas continuar?',
            style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DulceColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Aplicar y sobrescribir'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    await HardwareProfileService.instance.applyProfile(profile, overwrite: true);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Perfil ${profile.name} aplicado con exito.',
            style: const TextStyle(fontFamily: 'Outfit'),
          ),
          backgroundColor: DulceColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _restoreRecommendedProfile() async {
    final info = _hardwareInfo;
    if (info == null) return;
    final recommended = HardwareProfileService.instance.recommendProfile(info);
    await HardwareProfileService.instance.applyProfile(recommended, overwrite: true);
    await _storage.setPerformanceProfile('auto');
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restaurado al perfil recomendado (${recommended.name}) automaticamente.',
            style: const TextStyle(fontFamily: 'Outfit'),
          ),
          backgroundColor: DulceColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildProfileCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required List<String> details,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.white10,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.12),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Activo',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11.5,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: details
                  .map(
                    (detail) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Text(
                        detail,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10.5,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
