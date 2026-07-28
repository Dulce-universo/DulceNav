// ==============================================================
// DulceNav - error_report_screen.dart
// Formulario de reporte de errores (DulceUI) adaptado a las pautas de estilo.
// ==============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/error_report_service.dart';
import '../../core/services/theme_service.dart';

class ErrorReportScreen extends StatefulWidget {
  final Function(String url) onOpenUrl;

  const ErrorReportScreen({
    super.key,
    required this.onOpenUrl,
  });

  @override
  State<ErrorReportScreen> createState() => _ErrorReportScreenState();
}

class _ErrorReportScreenState extends State<ErrorReportScreen> {
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();
  bool _includeLogs = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService.instance;

    return Dialog(
      backgroundColor: const Color(0xFF181828),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.activeBorderColor,
          width: 1.2,
        ),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bug_report_rounded, color: DulceColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Reportar un problema',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Describe lo que ocurrio para ayudarnos a mejorar DulceNav de forma continua.',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: DulceColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              Text('¿Que paso?', style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'ej. Al intentar entrar a X sitio el navegador se cerro de golpe.',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                  filled: true,
                  fillColor: Colors.black26,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.activePrimaryColor)),
                ),
              ),
              const SizedBox(height: 16),

              Text('Pasos para reproducirlo (opcional):', style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _stepsController,
                maxLines: 2,
                style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'ej. 1. Entrar a ddg.com, 2. Buscar dulce, 3. Dar click en primer link.',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                  filled: true,
                  fillColor: Colors.black26,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.activePrimaryColor)),
                ),
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                activeColor: theme.activePrimaryColor,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Incluir logs de errores recientes',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  'Añade registros tecnicos capturados localmente en esta sesion para diagnosticar fallas de forma precisa.',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    color: DulceColors.textSecondary,
                  ),
                ),
                value: _includeLogs,
                onChanged: (val) {
                  setState(() => _includeLogs = val);
                },
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancelar', style: TextStyle(color: Colors.white60)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(Icons.copy_rounded, size: 14),
                    label: Text('Copiar informe'),
                    onPressed: _copyReport,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.activePrimaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(Icons.open_in_new_rounded, size: 14),
                    label: Text('Reportar en GitHub'),
                    onPressed: _openInGitHub,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyReport() {
    final report = ErrorReportService.instance.generateReport(
      _descriptionController.text,
      _stepsController.text,
      _includeLogs,
    );
    Clipboard.setData(ClipboardData(text: report)).then((_) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Informe de error copiado al portapapeles', style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: const Color(0xFF1E1E2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    });
  }

  void _openInGitHub() {
    final report = ErrorReportService.instance.generateReport(
      _descriptionController.text,
      _stepsController.text,
      _includeLogs,
    );
    final url = 'https://github.com/dulceuniverse/dulcenav/issues/new?title=Reporte%20de%20Error%20v1.4.4&body=${Uri.encodeComponent(report)}';
    widget.onOpenUrl(url);
    Navigator.of(context).pop();
  }
}
