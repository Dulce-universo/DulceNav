// ==============================================================
// DulceNav - autofill_popup.dart
// Widget de autocompletado flotante para credenciales en formularios.
// Diseñado con DulceUI (glassmorphism y Outfit).
// ==============================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/services/password_service.dart';
import '../../core/constants/app_colors.dart';

class AutofillPopup extends StatelessWidget {
  final List<PasswordEntry> entries;
  final String domain;
  final Function(PasswordEntry entry) onSelect;
  final VoidCallback onDismiss;
  final VoidCallback onExcludeSite;

  const AutofillPopup({
    super.key,
    required this.entries,
    required this.domain,
    required this.onSelect,
    required this.onDismiss,
    required this.onExcludeSite,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E).withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera del popup
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.vpn_key_rounded, color: Colors.amber, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Autocompletar en $domain',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onDismiss,
                      child: const Icon(Icons.close_rounded, color: Colors.white38, size: 14),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              
              // Lista de credenciales
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onSelect(entry),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: DulceColors.primary.withOpacity(0.2),
                                child: const Icon(Icons.person_rounded, size: 12, color: Colors.white70),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white30),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const Divider(height: 1, color: Colors.white10),
              
              // Botón "Nunca en este sitio"
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onExcludeSite,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.block_rounded, color: Colors.redAccent, size: 12),
                        SizedBox(width: 6),
                        Text(
                          'Nunca en este sitio',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
