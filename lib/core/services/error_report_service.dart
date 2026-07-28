// ==============================================================
// DulceNav - error_report_service.dart
// Captura y gestion de errores para generar informes de soporte.
// 100% privado y local: los logs permanecen en memoria.
// ==============================================================

import 'dart:collection';
import 'package:flutter/foundation.dart';

class ErrorLogEntry {
  final DateTime timestamp;
  final String error;
  final String stackTrace;

  ErrorLogEntry({
    required this.error,
    required this.stackTrace,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return '[${timestamp.toIso8601String()}] Error: $error\nStack:\n$stackTrace\n';
  }
}

class ErrorReportService {
  ErrorReportService._();
  static final ErrorReportService instance = ErrorReportService._();

  // Mantener ultimos 20 errores locales en memoria
  final ListQueue<ErrorLogEntry> _errors = ListQueue<ErrorLogEntry>();

  List<ErrorLogEntry> get errors => _errors.toList();

  // Inicializar captura global de errores de Flutter
  void init() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _logError(details.exceptionAsString(), details.stack?.toString() ?? '');
      originalOnError?.call(details);
    };

    final originalPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _logError(error.toString(), stack.toString());
      return originalPlatformOnError?.call(error, stack) ?? false;
    };
  }

  void _logError(String exception, String stack) {
    if (_errors.length >= 20) {
      _errors.removeFirst();
    }
    _errors.add(ErrorLogEntry(error: exception, stackTrace: stack));
    debugPrint('[ErrorReportService] Error capturado localmente.');
  }

  // Genera el texto plano en formato Markdown
  String generateReport(String description, String steps, bool includeLogs) {
    final buffer = StringBuffer();
    buffer.writeln('# INFORME DE ERROR - DULCENAV');
    buffer.writeln('Generado el: ${DateTime.now().toLocal()}\n');
    
    buffer.writeln('## DESCRIPCION DEL PROBLEMA');
    buffer.writeln('${description.trim().isNotEmpty ? description.trim() : "No provista."}\n');

    buffer.writeln('## PASOS PARA REPRODUCIR');
    buffer.writeln('${steps.trim().isNotEmpty ? steps.trim() : "No provistos."}\n');

    buffer.writeln('## INFORMACION DEL SISTEMA');
    buffer.writeln('- OS: Windows 10/11');
    buffer.writeln('- Versión DulceNav: 1.4.4');
    buffer.writeln('- Modo de Contraste: ${includeLogs ? "Consultar logs" : "N/A"}\n');

    if (includeLogs) {
      buffer.writeln('## REGISTROS TECNICOS DE ERROR (Ultimos 5)');
      if (_errors.isEmpty) {
        buffer.writeln('No se han registrado errores tecnicos en esta sesion.');
      } else {
        final logsToInclude = _errors.toList().reversed.take(5);
        for (final log in logsToInclude) {
          buffer.writeln('```');
          buffer.writeln(log.toString());
          buffer.writeln('```\n');
        }
      }
    } else {
      buffer.writeln('## REGISTROS TECNICOS');
      buffer.writeln('Excluidos por eleccion del usuario para proteger su privacidad.');
    }

    return buffer.toString();
  }
}
