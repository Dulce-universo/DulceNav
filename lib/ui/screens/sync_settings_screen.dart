// ==============================================================
// DulceNav - sync_settings_screen.dart
// Interfaz premium para la sincronización cifrada multiplataforma.
// Estilo DulceUI con soporte para exportar/importar y sync LAN.
// ==============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/dulce_sync_service.dart';
import '../../core/services/storage_service.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final _passphraseController = TextEditingController();
  final _importController = TextEditingController();
  final _syncService = DulceSyncService.instance;

  String _statusMessage = 'Ingrese su frase de seguridad para comenzar.';
  bool _isLoading = false;
  bool _showPassphrase = false;

  @override
  void initState() {
    super.initState();
    // Cargar frase de seguridad por defecto si existe guardada
    _passphraseController.text = StorageService.instance.searchEngine.contains('dulce') ? 'dulce_default_phrase' : '';
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    _importController.dispose();
    _syncService.stopLanServer();
    super.dispose();
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(fontFamily: 'Outfit', color: Colors.white),
        ),
        backgroundColor: isError ? DulceColors.dangerRed : DulceColors.safeGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Exportar datos locales a texto cifrado
  Future<void> _handleExport() async {
    final phrase = _passphraseController.text.trim();
    if (phrase.isEmpty) {
      _showToast('Por favor, ingrese una frase de seguridad.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Cifrando datos locales...';
    });

    final payload = await _syncService.exportData(phrase);

    setState(() {
      _isLoading = false;
    });

    if (payload != null) {
      // Intentar guardar como archivo físico en la carpeta de descargas del navegador
      try {
        final downloadDir = Directory(StorageService.instance.downloadPath);
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        final file = File('${downloadDir.path}dulcenav_sync.dulcesync');
        await file.writeAsString(payload);
        _statusMessage = 'Archivo guardado en: ${file.path}';
      } catch (e) {
        _statusMessage = 'No se pudo escribir el archivo local. Puede copiar el codigo de abajo.';
      }

      // Mostrar diálogo con el código para copiar
      if (mounted) {
        _showExportPayloadDialog(payload);
      }
    } else {
      setState(() {
        _statusMessage = 'Error al exportar los datos.';
      });
      _showToast('Error al exportar datos.', isError: true);
    }
  }

  // Importar datos desde texto cifrado
  Future<void> _handleImport() async {
    final phrase = _passphraseController.text.trim();
    final encrypted = _importController.text.trim();

    if (phrase.isEmpty) {
      _showToast('Por favor, ingrese la frase de seguridad.', isError: true);
      return;
    }
    if (encrypted.isEmpty) {
      _showToast('Por favor, pegue el codigo cifrado de sincronizacion.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Descifrando y cargando datos...';
    });

    final success = await _syncService.importData(phrase, encrypted);

    setState(() {
      _isLoading = false;
    });

    if (success) {
      _statusMessage = '¡Sincronizacion completada con exito! Datos importados.';
      _showToast('¡Datos importados con éxito!');
      _importController.clear();
    } else {
      _statusMessage = 'Error al descifrar. Verifique que la frase de seguridad sea la correcta.';
      _showToast('Fallo en la importación de datos.', isError: true);
    }
  }

  // Iniciar servidor local TCP para enviar datos
  void _startLanServer() {
    final phrase = _passphraseController.text.trim();
    if (phrase.isEmpty) {
      _showToast('Por favor, ingrese una frase de seguridad.', isError: true);
      return;
    }

    _syncService.startLanServer(
      phrase,
      onProgress: (status) {
        setState(() {
          _statusMessage = status;
        });
      },
      onSuccess: () {
        _showToast('¡Envio LAN completado!');
      },
      onError: (err) {
        setState(() {
          _statusMessage = 'Error LAN: $err';
        });
        _showToast('Error de sincronización LAN.', isError: true);
      },
    );
  }

  // Buscar dispositivo servidor local TCP para recibir datos
  void _syncFromLanDevice() {
    final phrase = _passphraseController.text.trim();
    if (phrase.isEmpty) {
      _showToast('Por favor, ingrese la frase de seguridad.', isError: true);
      return;
    }

    _syncService.syncFromLanDevice(
      phrase,
      onProgress: (status) {
        setState(() {
          _statusMessage = status;
        });
      },
      onSuccess: () {
        _showToast('¡Sincronizacion LAN completada con exito!');
      },
      onError: (err) {
        setState(() {
          _statusMessage = 'Error LAN: $err';
        });
        _showToast('Error de busqueda LAN.', isError: true);
      },
    );
  }

  void _showExportPayloadDialog(String payload) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF14141F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white10),
          ),
          title: Text(
            'Código de Sincronización',
            style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Copie este código cifrado y péguelo en su otro dispositivo para importar sus datos.',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    payload,
                    style: TextStyle(fontFamily: 'monospace', color: Colors.white54, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cerrar', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DulceColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: payload));
                _showToast('Código copiado al portapapeles.');
                Navigator.of(ctx).pop();
              },
              child: Text('Copiar Código'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DulceColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Sincronización Cifrada',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Fondo degradado DulceUI
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F0C20),
                    Color(0xFF0A0A0F),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tarjeta 1: Frase de Seguridad
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.vpn_key_rounded, color: DulceColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Frase de Seguridad Obligatoria',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Los datos se encriptan con AES-256 localmente antes de salir de su equipo. Esta frase es necesaria para descifrar los datos en el receptor.',
                        style: TextStyle(fontFamily: 'Outfit', color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passphraseController,
                        obscureText: !_showPassphrase,
                        style: TextStyle(fontFamily: 'Outfit', color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Ej. MiClaveSecretaSuperSegura2026!',
                          hintStyle: TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: DulceColors.primary),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassphrase ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: Colors.white38,
                            ),
                            onPressed: () => setState(() => _showPassphrase = !_showPassphrase),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tarjeta 2: Sincronización Rápida LAN (Red Local)
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.wifi_rounded, color: DulceColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Sincronización por Red Local (LAN)',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Conecte ambos dispositivos a la misma red Wifi para transferir directamente favoritos, contraseñas e historial.',
                        style: TextStyle(fontFamily: 'Outfit', color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _syncService.isServerRunning ? DulceColors.dangerRed : DulceColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _syncService.isServerRunning ? _syncService.stopLanServer : _startLanServer,
                              icon: Icon(
                                _syncService.isServerRunning ? Icons.stop_rounded : Icons.sensors_rounded,
                                color: Colors.white,
                              ),
                              label: Text(
                                _syncService.isServerRunning ? 'Detener Envío' : 'Enviar Datos (Host)',
                                style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: DulceColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _syncFromLanDevice,
                              icon: Icon(Icons.search_rounded, color: DulceColors.primary),
                              label: Text(
                                'Buscar y Recibir',
                                style: TextStyle(fontFamily: 'Outfit', color: DulceColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tarjeta 3: Importación / Exportación Manual (.dulcesync)
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.swap_horizontal_circle_rounded, color: DulceColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Importación / Exportación Manual',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E2C3F),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _handleExport,
                              icon: Icon(Icons.file_upload_rounded, color: Colors.white),
                              label: Text(
                                'Exportar Datos',
                                style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      Text(
                        'Pegar código cifrado para Importar:',
                        style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _importController,
                        maxLines: 3,
                        style: TextStyle(fontFamily: 'monospace', color: Colors.white70, fontSize: 11),
                        decoration: InputDecoration(
                          hintText: 'Pegue el codigo Base64 cifrado aqui...',
                          hintStyle: TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: DulceColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14C882),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _handleImport,
                          icon: Icon(Icons.file_download_rounded, color: Colors.white),
                          label: Text(
                            'Descifrar e Importar',
                            style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Consola / Estado de sincronización
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      if (_isLoading)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: DulceColors.primary,
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(Icons.info_outline_rounded, color: DulceColors.primary, size: 18),
                        ),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A26).withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }
}
