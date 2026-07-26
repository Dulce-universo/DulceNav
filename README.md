# 🌌 DulceNav — Navegador Privado Inteligente Local
> Ecosistema Dulce Universe | Versión 1.8.1 Stable

[![Plataforma - Windows](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078d4?style=for-the-badge&logo=windows)](https://github.com/Dulce-universo/DulceNav)
[![Plataforma - Android](https://img.shields.io/badge/Platform-Android%208.0%20%2B-3ddc84?style=for-the-badge&logo=android)](https://github.com/Dulce-universo/DulceNav)
[![Version](https://img.shields.io/badge/Release-v1.8.1-morado?style=for-the-badge&color=8A2BE2)](https://github.com/Dulce-universo/DulceNav/releases)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

**DulceNav** es un navegador web premium, ultra-ligero y centrado en la privacidad absoluta del usuario. Diseñado bajo la estética **DulceUI Ultra** con efectos de glassmorphism interactivos, ofrece una suite de **Inteligencia Artificial local autónoma (DulceMind v1.8.1)** impulsada por un motor GGUF in-process 100% offline (sin Ollama ni apps externas), bloqueador cosmético de anuncios (estilo ABP/uBlock), protección biométrica de credenciales y un optimizador de recursos que adapta el navegador a tu hardware en tiempo real.

---

## 📥 Enlaces de Descarga (Releases Oficiales v1.8.1)

Puedes descargar los instaladores listos para usar directamente desde los siguientes enlaces:

### 🖥️ Windows (10 / 11 de 64 bits)
* [**Descargar Instalador Clásico v1.8.1 (.exe)**](https://github.com/Dulce-universo/DulceNav/releases/download/v1.8.1/DulceNav_v1.8.1_Setup.exe)  
  *Instalación rápida y segura con soporte de accesos directos y Edge WebView2 integrado.*

### 📱 Android (Oreo 8.0 o superior)
* [**Descargar APK Universal (FAT)**](https://github.com/Dulce-universo/DulceNav/releases/download/v1.8.1/app-release.apk) (Ideal para distribución general y pruebas rápidas)
* [**Descargar APK ARM64 (64-bits)**](https://github.com/Dulce-universo/DulceNav/releases/download/v1.8.1/app-arm64-v8a-release.apk) (Recomendado para la gran mayoría de dispositivos modernos)
* [**Descargar APK ARM32 (32-bits)**](https://github.com/Dulce-universo/DulceNav/releases/download/v1.8.1/app-armeabi-v7a-release.apk) (Para dispositivos Android antiguos o de gama de entrada)
* [**Descargar APK x86_64 (64-bits)**](https://github.com/Dulce-universo/DulceNav/releases/download/v1.8.1/app-x86_64-release.apk) (Para emuladores y tabletas Intel/AMD)

---

## ✨ Características Principalmente Destacadas (v1.8.1)

### 🤖 1. DulceMind v1.8.1: Inteligencia Artificial Autónoma In-Process
* **100% Independiente (Sin Ollama):** Ejecución nativa in-process de modelos GGUF vía bindings FFI (`llama_cpp_dart`). No requiere consolas, procesos en segundo plano ni puertos HTTP.
* **Descarga en 1 Clic desde HuggingFace:**
  - **Llama 3.2 1B Instruct (Q4_K_M)** (~1.2 GB, recomendado por defecto).
  - **Qwen 2.5 1.5B Instruct (Q4_K_M)** (~1.3 GB, alta precisión en español).
  - Progreso de descarga en tiempo real (porcentaje %, MB/s, bytes) con soporte de reanudación y validación por hash SHA-256.
* **Importador de Ollama Previa (1 Clic):** Escanea automáticamente la carpeta de blobs de Ollama local (`.ollama/models/blobs`) permitiendo importar modelos `.gguf` en 1 clic sin volver a descargarlos.
* **Liberación Automática de Memoria RAM (5 min):** El modelo no se carga al iniciar la app. Se carga perezosamente en RAM al solicitar una acción y se libera automáticamente tras 5 min de inactividad, ahorrando ~1.2 GB de RAM.
* **Switch de Ocultación Total:** Opción en Ajustes para ocultar completamente la IA del navegador (desaparecen botones y menús).
* **Acciones Rápidas en Página (Chips Contextuales):** Resumir (Corto, Detallado, Puntos clave), Explicar (Sencillo con analogías o Técnico), Traducir (Inglés, Portugués, Francés, Alemán), y Extraer (Fechas, Cifras, Pasos).

### 🧹 2. Bloqueador Cosmético de Anuncios (v1.8.0)
* **Eliminación de Huecos Blancos:** Capa cosmética independiente que oculta los elementos y contenedores donde solían cargar anuncios usando `display:none !important` y `MutationObserver` para anuncios dinámicos.
* **Reglas Personalizadas ABP/uBlock:** Soporte de sintaxis estándar `||dominio.com##.selector` y reglas locales personalizadas desde Ajustes.

### 🛡️ 3. Seguridad Blindada & DulcePrivacy
* **Autocompletado y Protección Biométrica / PIN:** El gestor de contraseñas requiere **Windows Hello / Huella dactilar** para desbloquear y autocompletar credenciales.
* **Pestañas de Incógnito Blindadas:** Aislamiento absoluto de cookies/caché y bloqueo nativo de capturas de pantalla (`FLAG_SECURE`) en Android.
* **DoH (DNS over HTTPS):** Cifrado de consultas DNS mediante Cloudflare (1.1.1.1), Google (8.8.8.8) o Quad9.

### ⚡ 4. Detección de Hardware & Ajustes Adaptativos
* **Perfiles Inteligentes:** Ahorro de Recursos (RAM < 4 GB), Equilibrado (RAM 4-8 GB), Rendimiento Máximo (RAM > 8 GB) y Privacidad Máxima.

---

<<<<<<< HEAD
=======
## 🛠️ Entorno de Desarrollo y Compilación

Requisitos mínimos:
* **Flutter SDK** >= 3.24.0 (Canal Estable)
* **Android SDK** API 34 + NDK 27.0.12077973
* **C++ Build Tools** (para Windows)

---

>>>>>>> 16a3a7d (v1.8.1: Bloqueador cosmetico v1.8.0 + Motor IA Autonomo GGUF v1.8.1 + Actualizacion de README)
## 📄 Licencia

DulceNav se distribuye bajo la licencia **MIT**. Consulta [LICENSE](LICENSE) para más detalles.

---
*Desarrollado con ❤️ por el equipo de **Dulce Universe**, Desde colombia.
