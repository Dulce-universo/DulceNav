// ==============================================================
// DulceNav - passwords_screen.dart
// Panel de gestión de contraseñas seguras con estética DulceUI.
// ==============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/password_service.dart';
import '../../core/services/theme_service.dart';

class PasswordsScreen extends StatefulWidget {
  const PasswordsScreen({super.key});

  @override
  State<PasswordsScreen> createState() => _PasswordsScreenState();
}

class _PasswordsScreenState extends State<PasswordsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _revealedKeys = {};

  @override
  void initState() {
    super.initState();
    PasswordService.instance.loadCredentials();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final passwordService = context.watch<PasswordService>();
    final entries = passwordService.entries.where((entry) {
      final query = _searchQuery.toLowerCase();
      return entry.domain.contains(query) || entry.username.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: Text(
          'Gestor de Contraseñas',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF1E1E2E).withOpacity(0.5),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra de busqueda
            TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar por sitio o usuario...',
                hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white30, size: 18),
                filled: true,
                fillColor: const Color(0xFF181828),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.activePrimaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
            const SizedBox(height: 20),

            // Encabezado informativo
            Row(
              children: [
                Icon(Icons.shield_rounded, color: DulceColors.safeGreen, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Tus contraseñas estan cifradas con AES-256 de forma nativa.',
                  style: TextStyle(fontFamily: 'Outfit', color: Colors.white.withOpacity(0.6), fontSize: 11),
                ),
                const Spacer(),
                if (entries.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    icon: Icon(Icons.delete_sweep_rounded, size: 16),
                    label: Text('Vaciar todo', style: TextStyle(fontFamily: 'Outfit', fontSize: 12)),
                    onPressed: _showClearAllConfirmDialog,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Lista de contraseñas
            Expanded(
              child: entries.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final uniqueKey = '${entry.domain}_${entry.username}';
                        final isRevealed = _revealedKeys.contains(uniqueKey);

                        return Card(
                          color: const Color(0xFF181828),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.white10),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Icono decorativo de dominio
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: theme.activePrimaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.lock_person_rounded, color: theme.activePrimaryColor, size: 18),
                                ),
                                const SizedBox(width: 14),

                                // Informacion de dominio y usuario
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.domain,
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        entry.username,
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Contraseña ofuscada / revelada
                                      Text(
                                        isRevealed ? entry.password : '••••••••',
                                        style: TextStyle(
                                          fontFamily: isRevealed ? 'Consolas' : 'Outfit',
                                          fontSize: 12,
                                          color: isRevealed ? Colors.white : Colors.white30,
                                          letterSpacing: isRevealed ? 0.5 : 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Acciones
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Revelar/Ocultar
                                    IconButton(
                                      icon: Icon(
                                        isRevealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      onPressed: () async {
                                        if (!isRevealed) {
                                          final verified = await PasswordService.instance.requestAccess(context, 'Confirmar identidad para revelar contraseña');
                                          if (!verified) return;
                                        }
                                        setState(() {
                                          if (isRevealed) {
                                            _revealedKeys.remove(uniqueKey);
                                          } else {
                                            _revealedKeys.add(uniqueKey);
                                          }
                                        });
                                      },
                                      tooltip: isRevealed ? 'Ocultar contraseña' : 'Mostrar contraseña',
                                    ),
                                    // Copiar
                                    IconButton(
                                      icon: Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                                      onPressed: () async {
                                        final verified = await PasswordService.instance.requestAccess(context, 'Confirmar identidad para copiar contraseña');
                                        if (!verified) return;
                                        PasswordService.instance.copyToClipboardSecure(entry.password);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('Contraseña copiada. Se limpiará en 30s', style: TextStyle(fontFamily: 'Outfit')),
                                              backgroundColor: const Color(0xFF1E1E2E),
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              width: 280,
                                            ),
                                          );
                                        }
                                      },
                                      tooltip: 'Copiar contraseña',
                                    ),
                                    // Eliminar
                                    IconButton(
                                      icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                      onPressed: () => _showDeleteConfirmDialog(entry),
                                      tooltip: 'Eliminar credencial',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.vpn_key_outlined, size: 48, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No se encontraron resultados para tu busqueda.' : 'No tienes contraseñas guardadas aun.',
            style: TextStyle(fontFamily: 'Outfit', color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty)
            Text(
              'Las credenciales que guardes en tus sitios se veran aqui.',
              style: TextStyle(fontFamily: 'Outfit', color: Colors.white30, fontSize: 11),
            ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(PasswordEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white10)),
          title: Text('Eliminar credencial', style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            '¿Deseas eliminar la contraseña guardada para "${entry.username}" en ${entry.domain}?',
            style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancelar', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                await PasswordService.instance.deleteCredentials(entry.domain, entry.username);
                if (mounted) Navigator.of(ctx).pop();
              },
              child: Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  void _showClearAllConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C0F14), // Dark red style
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.redAccent, width: 1.5)),
          title: Text('¡Advertencia!', style: TextStyle(fontFamily: 'Outfit', color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: Text(
            '¿Estas seguro de que deseas eliminar TODAS tus contraseñas guardadas?\nEsta accion es irreversible.',
            style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancelar', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                await PasswordService.instance.deleteAllCredentials();
                if (mounted) Navigator.of(ctx).pop();
              },
              child: Text('Eliminar todo'),
            ),
          ],
        );
      },
    );
  }
}
