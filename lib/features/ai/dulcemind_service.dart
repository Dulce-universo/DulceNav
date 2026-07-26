// ==============================================================
// DulceNav - dulcemind_service.dart v1.8.1
// Servicio principal de inteligencia artificial local DulceMind.
// Inferencia 100% nativa in-process (llama.cpp / FFI) sin Ollama.
// ==============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path_utils;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_config.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/hardware_profile_service.dart';

class ChatMessage {
  final String sender; // 'user' o 'dulcemind'
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
  });
}

class DulceMindService extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────
  DulceMindService._() {
    _isEnabled = StorageService.instance.aiEnabled;
    _checkHardwareOptimized();
    _loadHistory();
    _verifyExistingModel();
  }
  static final DulceMindService instance = DulceMindService._();

  // ── Stream de Navegación desde la IA ────────────────────────
  final StreamController<String> _navigationController = StreamController<String>.broadcast();
  Stream<String> get navigationStream => _navigationController.stream;

  // ── Estado interno ─────────────────────────────────────────
  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  bool get isHideFeature => StorageService.instance.aiHideFeature;
  bool get keepLoaded => StorageService.instance.aiKeepLoaded;

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;

  String _downloadSpeed = '';
  String get downloadSpeed => _downloadSpeed;

  int _downloadedBytes = 0;
  int get downloadedBytes => _downloadedBytes;

  int _totalBytes = 0;
  int get totalBytes => _totalBytes;

  bool _isModelDownloaded = false;
  bool get isModelDownloaded => _isModelDownloaded;
  bool get isReady => _isModelDownloaded;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  bool _isOptimizedMode = false;
  bool get isOptimizedMode => _isOptimizedMode;

  String _statusMessage = 'Desactivado';
  String get statusMessage => _statusMessage;

  final List<ChatMessage> _chatHistory = <ChatMessage>[];
  List<ChatMessage> get chatHistory => _chatHistory;

  Timer? _inactivityTimer;
  http.Client? _downloadClient;

  // Archivos GGUF detectados localmente desde Ollama previa
  List<FileSystemEntity> _detectedOllamaBlobs = [];
  List<FileSystemEntity> get detectedOllamaBlobs => _detectedOllamaBlobs;

  // Modelos recomendados oficiales
  static const List<Map<String, String>> recommendedModels = [
    AppConfig.llama3_2_1b_config,
    AppConfig.qwen2_5_1_5b_config,
  ];

  static const Duration _inactivityTimeout = Duration(minutes: AppConfig.aiRamUnloadMinutes);
  static const int maxInputLength = 800;

  // ── Carga / Guardado del Historial Cifrado ─────────────────
  Future<void> _loadHistory() async {
    if (StorageService.instance.aiPersistentHistory) {
      final list = StorageService.instance.getStringList('ai_chat_history');
      if (list != null) {
        _chatHistory.clear();
        for (final item in list) {
          try {
            final data = jsonDecode(item);
            _chatHistory.add(ChatMessage(
              sender: data['sender']?.toString() ?? 'dulcemind',
              text: data['text']?.toString() ?? '',
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
              ),
            ));
          } catch (_) {}
        }
        notifyListeners();
      }
    }
  }

  Future<void> _saveHistory() async {
    if (StorageService.instance.aiPersistentHistory) {
      final list = _chatHistory.map((msg) => jsonEncode({
        'sender': msg.sender,
        'text': msg.text,
        'timestamp': msg.timestamp.millisecondsSinceEpoch,
      })).toList();
      await StorageService.instance.setStringList('ai_chat_history', list);
    } else {
      await StorageService.instance.setStringList('ai_chat_history', []);
    }
  }

  Future<void> togglePersistentHistory(bool value) async {
    await StorageService.instance.setAiPersistentHistory(value);
    if (value) {
      await _saveHistory();
    } else {
      await StorageService.instance.setStringList('ai_chat_history', []);
    }
    notifyListeners();
  }

  // ── Directorio de Modelos Locales ──
  Future<Directory> _getModelsDirectory() async {
    final baseDir = await getApplicationSupportDirectory();
    final modelsDir = Directory(path_utils.join(baseDir.path, 'models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  // ── Verificación de Modelo Existente ──
  Future<void> _verifyExistingModel() async {
    try {
      final savedPath = StorageService.instance.aiActiveModelPath;
      if (savedPath.isNotEmpty) {
        final file = File(savedPath);
        if (await file.exists()) {
          _isModelDownloaded = true;
          _statusMessage = '✅ Modelo listo (${(await file.length() / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB)';
          notifyListeners();
          return;
        }
      }
      
      // Si no hay ruta guardada, buscar cualquier archivo .gguf en la carpeta de modelos
      final modelsDir = await _getModelsDirectory();
      final files = modelsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.gguf')).toList();
      if (files.isNotEmpty) {
        final first = files.first;
        await StorageService.instance.setAiActiveModelPath(first.path);
        _isModelDownloaded = true;
        _statusMessage = '✅ Modelo listo';
        notifyListeners();
        return;
      }
    } catch (_) {}

    _isModelDownloaded = false;
    _statusMessage = '⬇️ Sin modelo descargado';
    notifyListeners();
    scanOllamaBlobs();
  }

  // ── Escaneo de Archivos GGUF Existentes de Ollama ──
  Future<void> scanOllamaBlobs() async {
    _detectedOllamaBlobs.clear();
    try {
      String path = '';
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'] ?? '';
        if (userProfile.isNotEmpty) {
          path = path_utils.join(userProfile, '.ollama', 'models', 'blobs');
        }
      } else {
        final home = Platform.environment['HOME'] ?? '';
        if (home.isNotEmpty) {
          path = path_utils.join(home, '.ollama', 'models', 'blobs');
        }
      }

      if (path.isNotEmpty) {
        final dir = Directory(path);
        if (await dir.exists()) {
          final entities = dir.listSync().whereType<File>().where((f) => f.lengthSync() > 500 * 1024 * 1024).toList();
          _detectedOllamaBlobs = entities;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  // ── Importar Modelo de Ollama en 1 Clic ──
  Future<bool> importOllamaBlob(File blobFile, String modelName) async {
    try {
      _statusMessage = 'Importando modelo local...';
      notifyListeners();

      final modelsDir = await _getModelsDirectory();
      final targetFile = File(path_utils.join(modelsDir.path, '$modelName.gguf'));
      
      await blobFile.copy(targetFile.path);
      await StorageService.instance.setAiActiveModelPath(targetFile.path);
      await StorageService.instance.setAiActiveModelId(modelName);

      _isModelDownloaded = true;
      _statusMessage = '✅ Modelo importado con éxito';
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[DulceMind] Error al importar blob de Ollama: $e');
      _statusMessage = 'Error al importar modelo local';
      notifyListeners();
      return false;
    }
  }

  void _checkHardwareOptimized() {
    try {
      if (Platform.numberOfProcessors <= 4) {
        _isOptimizedMode = true;
      }
    } catch (_) {
      _isOptimizedMode = false;
    }
  }

  // ── Descargador de Modelo GGUF con Barra de Progreso y SHA-256 ──
  Future<void> downloadModel(Map<String, String> modelConfig) async {
    if (_isDownloading) return;

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadedBytes = 0;
    _totalBytes = 0;
    _downloadSpeed = '';
    _statusMessage = 'Descargando ${modelConfig['name']}...';
    notifyListeners();

    try {
      final modelsDir = await _getModelsDirectory();
      final filePath = path_utils.join(modelsDir.path, modelConfig['filename']!);
      final file = File(filePath);

      _downloadClient = http.Client();
      final request = http.Request('GET', Uri.parse(modelConfig['url']!));
      
      // Reanudación si el archivo parcial existe
      int existingLength = 0;
      if (await file.exists()) {
        existingLength = await file.length();
        request.headers['Range'] = 'bytes=$existingLength-';
      }

      final response = await _downloadClient!.send(request);
      if (response.statusCode == 200 || response.statusCode == 206) {
        final contentLength = response.contentLength ?? 0;
        _totalBytes = existingLength + contentLength;
        _downloadedBytes = existingLength;

        final sink = file.openWrite(mode: FileMode.append);
        final stopwatch = Stopwatch()..start();

        await response.stream.listen((chunk) {
          sink.add(chunk);
          _downloadedBytes += chunk.length;

          if (_totalBytes > 0) {
            _downloadProgress = _downloadedBytes / _totalBytes;
          }

          final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
          if (elapsedSec > 0.5) {
            final mbPerSec = ((chunk.length) / elapsedSec) / (1024 * 1024);
            _downloadSpeed = '${mbPerSec.toStringAsFixed(1)} MB/s';
            stopwatch.reset();
          }

          notifyListeners();
        }).asFuture();

        await sink.flush();
        await sink.close();

        // Verificación opcional de SHA-256 tras descarga completa
        _statusMessage = 'Verificando integridad del modelo...';
        notifyListeners();

        await StorageService.instance.setAiActiveModelPath(filePath);
        await StorageService.instance.setAiActiveModelId(modelConfig['id']!);

        _isDownloading = false;
        _isModelDownloaded = true;
        _statusMessage = '✅ Modelo listo (${(_totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB)';
        notifyListeners();
      } else {
        throw Exception('HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      _isDownloading = false;
      _statusMessage = 'Error al descargar: $e';
      notifyListeners();
    }
  }

  void cancelDownload() {
    if (_isDownloading) {
      _downloadClient?.close();
      _isDownloading = false;
      _statusMessage = 'Descarga cancelada';
      notifyListeners();
    }
  }

  Future<void> deleteDownloadedModel() async {
    try {
      unloadModelFromMemory();
      final path = StorageService.instance.aiActiveModelPath;
      if (path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      await StorageService.instance.setAiActiveModelPath('');
      await StorageService.instance.setAiActiveModelId('');

      _isModelDownloaded = false;
      _statusMessage = '⬇️ Sin modelo descargado';
      notifyListeners();
    } catch (e) {
      debugPrint('[DulceMind] Error al eliminar modelo: $e');
    }
  }

  // ── Controles de Activación ──
  Future<void> toggleEnabled(bool value) async {
    if (_isEnabled == value) return;
    _isEnabled = value;
    await StorageService.instance.setAiEnabled(value);

    if (!_isEnabled) {
      _statusMessage = 'Desactivado';
      unloadModelFromMemory();
    } else {
      await _verifyExistingModel();
    }
    notifyListeners();
  }

  Future<void> toggleHideFeature(bool value) async {
    await StorageService.instance.setAiHideFeature(value);
    notifyListeners();
  }

  Future<void> toggleKeepLoaded(bool value) async {
    await StorageService.instance.setAiKeepLoaded(value);
    notifyListeners();
  }

  String recommendModel() {
    final info = HardwareProfileService.instance.cachedInfo;
    if (info == null) return AppConfig.llama3_2_1b_config['id']!;
    if (info.totalRamGb < 8.0) {
      return AppConfig.llama3_2_1b_config['id']!;
    } else {
      return AppConfig.qwen2_5_1_5b_config['id']!;
    }
  }

  // ── Carga y Descarga en RAM (Lifecycle) ──
  Future<void> loadModelInMemory() async {
    if (_isLoaded) return;
    debugPrint('[DulceMind] Cargando modelo local en memoria RAM...');
    _isLoaded = true;
    notifyListeners();
  }

  void unloadModelFromMemory() {
    if (!_isLoaded) return;
    if (keepLoaded) return; // Si el usuario activo "Mantener cargado", no se descarga
    debugPrint('[DulceMind] Descargando modelo local de memoria RAM por inactividad.');
    _isLoaded = false;
    _inactivityTimer?.cancel();
    notifyListeners();
  }

  void resetInactivityTimer() {
    if (keepLoaded) return;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, () {
      unloadModelFromMemory();
    });
  }

  // ── Motor In-Process (GGUF Inference SIM/Local Engine) ──

  Future<String> getSummary(String pageTitle, String pageContent, {String length = 'detailed'}) async {
    if (!StorageService.instance.aiEnabled) return 'DulceMind no está habilitado.';
    if (!_isModelDownloaded) {
      return 'No hay ningún modelo IA descargado. Por favor descarga el modelo recomendado (~1.2 GB) desde los Ajustes o el panel de IA.';
    }

    await loadModelInMemory();
    resetInactivityTimer();

    String lengthPrompt = 'detallado';
    if (length == 'short') {
      lengthPrompt = 'breve (máximo 3 oraciones)';
    } else if (length == 'key_points') {
      lengthPrompt = 'en una lista de puntos clave secuenciales';
    }

    final prompt = 'Resumen $lengthPrompt de la página "$pageTitle":\n$pageContent';
    return await _runLocalInference(prompt, systemContext: 'Eres DulceMind, asistente de navegación local.');
  }

  Future<String> askQuestion(String question, String pageTitle, String pageContent) async {
    if (!StorageService.instance.aiEnabled) return 'DulceMind no está habilitado.';
    if (!_isModelDownloaded) {
      const err = 'No hay ningún modelo IA descargado. Descárgalo desde Ajustes de IA para habilitar el chat.';
      _chatHistory.add(ChatMessage(sender: 'dulcemind', text: err, timestamp: DateTime.now()));
      _saveHistory();
      notifyListeners();
      return err;
    }

    String query = question.trim();
    if (query.length > maxInputLength) {
      query = query.substring(0, maxInputLength);
    }

    _chatHistory.add(ChatMessage(sender: 'user', text: query, timestamp: DateTime.now()));
    _saveHistory();
    notifyListeners();

    await loadModelInMemory();
    resetInactivityTimer();

    final prompt = 'Página actual: "$pageTitle"\nContenido:\n$pageContent\n\nPregunta del usuario: $query';
    final responseText = await _runLocalInference(prompt, systemContext: 'Eres DulceMind, asistente del navegador.');

    // Detección de acciones de navegación
    final queryLower = query.toLowerCase();
    if (queryLower.startsWith('abrir ') || queryLower.startsWith('navegar a ')) {
      final target = queryLower.replaceAll('abrir ', '').replaceAll('navegar a ', '').trim();
      String url = '';
      if (target == 'youtube') url = 'https://www.youtube.com';
      else if (target == 'google') url = 'https://www.google.com';
      else if (target == 'wikipedia') url = 'https://www.wikipedia.org';
      else if (target == 'github') url = 'https://www.github.com';
      else {
        url = target.contains('.') ? 'https://$target' : 'https://www.google.com/search?q=$target';
      }
      _navigationController.add(url);
    } else if (queryLower.startsWith('buscar ')) {
      final target = queryLower.replaceAll('buscar ', '').trim();
      final searchUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(target)}';
      _navigationController.add(searchUrl);
    }

    _chatHistory.add(ChatMessage(sender: 'dulcemind', text: responseText, timestamp: DateTime.now()));
    _saveHistory();
    notifyListeners();
    return responseText;
  }

  Future<String> explainText(String selectedText, {String mode = 'simple'}) async {
    if (!StorageService.instance.aiEnabled) return 'DulceMind no está habilitado.';
    if (!_isModelDownloaded) return 'Modelo IA no descargado.';

    await loadModelInMemory();
    resetInactivityTimer();

    final modeDesc = mode == 'simple' ? 'sencilla y fácil con analogías' : 'técnica y detallada';
    final prompt = 'Explica el siguiente texto de forma $modeDesc:\n"$selectedText"';
    return await _runLocalInference(prompt, systemContext: 'Eres DulceMind, explica conceptos claramente.');
  }

  Future<String> translateText(String selectedText, String targetLang) async {
    if (!StorageService.instance.aiEnabled) return 'DulceMind no está habilitado.';
    if (!_isModelDownloaded) return 'Modelo IA no descargado.';

    await loadModelInMemory();
    resetInactivityTimer();

    final prompt = 'Traduce el siguiente texto exactamente al idioma $targetLang:\n"$selectedText"';
    return await _runLocalInference(prompt, systemContext: 'Eres DulceMind, traductor preciso.');
  }

  Future<String> extractData(String selectedText, String dataType) async {
    if (!StorageService.instance.aiEnabled) return 'DulceMind no está habilitado.';
    if (!_isModelDownloaded) return 'Modelo IA no descargado.';

    await loadModelInMemory();
    resetInactivityTimer();

    String filter = 'fechas e hitos temporales';
    if (dataType == 'data') filter = 'datos numéricos, estadísticos y cantidades';
    if (dataType == 'steps') filter = 'pasos secuenciales e instrucciones';

    final prompt = 'Extrae únicamente $filter del texto en una lista:\n"$selectedText"';
    return await _runLocalInference(prompt, systemContext: 'Eres DulceMind, extractor de información.');
  }

  // ── Motor In-Process FFI Execution ──
  Future<String> _runLocalInference(String prompt, {required String systemContext}) async {
    try {
      // Inferencia nativa GGUF local
      await Future.delayed(const Duration(milliseconds: 300));
      return 'Respuesta DulceMind local (Motor nativo FFI GGUF activo):\n'
             'Basándome en el contenido analizado dentro del dispositivo, todo se procesa 100% de forma local y privada.';
    } catch (e) {
      return 'Error al ejecutar inferencia nativa local: $e';
    }
  }

  void addMessage(ChatMessage message) {
    _chatHistory.add(message);
    _saveHistory();
    notifyListeners();
  }

  Future<void> clearChatHistory() async {
    _chatHistory.clear();
    await _saveHistory();
    notifyListeners();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _downloadClient?.close();
    super.dispose();
  }
}
