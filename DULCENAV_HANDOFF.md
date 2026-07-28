# DULCENAV - DOCUMENTO DE TRANSFERENCIA DE CONTEXTO v1.8.1
## Para agente IA que continúe el trabajo
## Versión actual: v1.8.1 Stable | Bloqueador Cosmético v1.8.0 + Motor IA GGUF v1.8.1 + Revisión General & UI v1.8.1

---

## IDENTIDAD DEL PROYECTO

**DulceNav** es un navegador web ultra-ligero, seguro y eficiente.
Parte del ecosistema **Dulce Universe** (DulceOP, DulcePlay, DulceBot, DulceNav).
Sitio del ecosistema: https://dulceapps.lovable.app

Stack: Flutter + Dart. Plataforma actual: Windows 10/11 y Android 8.0+.

---

## ESTADO AL CIERRE DE ESTA SESION

| Item | Estado |
|---|---|
| Fase 1 — Núcleo WebView | COMPLETA v1.1.0 |
| Fase 2 — Motor de Bloqueo | COMPLETA v1.2.1 OPTIMIZADA |
| setup_env.ps1 | CORREGIDO v1.2.1 — ZIP validation + auto-redownload |
| flutter pub get | COMPLETA v1.8.1 |
| flutter run -d windows | COMPLETA v1.8.1 (Clean compile, EXE y APKs empaquetados v1.8.1) |
| Fase 3 — DulceMind IA | COMPLETA v1.8.1 MOTOR NATIVO FFI GGUF IN-PROCESS (Sin Ollama) |
| Fase 4 — UI Escritorio y Lujo | COMPLETA v1.3.9 (Pestañas, Historial, Descargas y Actualizador) |
| Fase 5 — Optimización & Seguridad | COMPLETA v1.8.0 (Bloqueador Cosmético, Biometría, Ahorro Inteligente, DoH) |
| Mejoras Profesionales e IA | COMPLETA v1.8.1 (Descarga 1-clic, SHA256, Auto-RAM 5 min, Switch Ocultar) |
| Optimización de Espacio y RAM | COMPLETA v1.4.2 (Subsetting manual, Caché límites y Modo Juego) |
| Fase 6 — Sesiones y Login | COMPLETA v1.4.3 (Mounted checks, AuthService y cookies cifradas) |
| Fase 7 — Multiplataforma & Sync | COMPLETA v1.8.1 (Android InAppWebView, Keystore AES nativo, Inno Setup EXE & Android Split/FAT APKs) |
| Fase 8 — Navegación & Recientes | COMPLETA v1.6.0 (IndexedStack tab state, GPS clima geolocator) |
| Fase 9 — Perfiles HW, IA & UI | COMPLETA v1.8.1 (Detección HW, Descargas HuggingFace, Glassmorphism, Botón Retroceso Reactivo, C++ Fixes) |

---

## PASOS INMEDIATOS PARA EL SIGUIENTE AGENTE

```powershell
cd D:\Proyectos\DulceNav
flutter pub get

# Correr en Windows:
flutter run -d windows

# Correr en Android:
flutter run -d android

# Re-compilar instaladores v1.8.1:
powershell -ExecutionPolicy Bypass -File .\windows\build_windows.ps1
flutter build apk --split-per-abi
flutter build apk
```

---

## UBICACIONES Y ARCHIVOS CLAVE DE v1.8.1

| Recurso / Componente | Ruta / Archivo |
|---|---|
| Proyecto DulceNav | `D:\Proyectos\DulceNav\` |
| Motor IA Autónomo | [`lib/features/ai/dulcemind_service.dart`](file:///d:/Proyectos/DulceNav/lib/features/ai/dulcemind_service.dart) |
| Configuración de Modelos GGUF | [`lib/core/constants/app_config.dart`](file:///d:/Proyectos/DulceNav/lib/core/constants/app_config.dart) |
| Bloqueador Cosmético | [`lib/features/security/cosmetic_blocker.dart`](file:///d:/Proyectos/DulceNav/lib/features/security/cosmetic_blocker.dart) |
| Panel de Ajustes Rediseñado | [`lib/ui/screens/settings_screen.dart`](file:///d:/Proyectos/DulceNav/lib/ui/screens/settings_screen.dart) |
| Pantalla de Inicio Glassmorphic | [`lib/features/home/home_screen.dart`](file:///d:/Proyectos/DulceNav/lib/features/home/home_screen.dart) |
| C++ Runner Win32 Corregido | [`windows/runner/win32_window.cpp`](file:///d:/Proyectos/DulceNav/windows/runner/win32_window.cpp) |
| Instalador Windows EXE v1.8.1 | `build\windows\installer\DulceNav_v1.8.1_Setup.exe` |
| APKs Android v1.8.1 | `build\app\outputs\flutter-apk\` |

---

## DECISIONES DE ARQUITECTURA (NO CAMBIAR)

| Decisión | Razón |
|---|---|
| Inferencia GGUF In-Process | Elimina dependencias externas (Ollama/consola), garantizando privacidad 100% local |
| Descarga de RAM a los 5 min | Previene que el modelo consuma 1.2 GB de RAM cuando el usuario no utiliza la IA |
| Bloqueador Cosmético independiente | Separa el bloqueo de red (Domain DB) de la manipulación visual DOM (display:none) |
| Fachada unificada DulceWebView | Aísla la implementación del WebView nativo según la plataforma (WebView2 / InAppWebView) |
| Android Keystore en Kotlin | Proporciona cifrado seguro en hardware nativo libre de dependencias de terceros |

---

*Generado por ANTIGRAVITY | DulceNav v1.8.1 | 2026-07-27*
