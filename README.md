# 🌌 DulceNav — Navegador Privado Inteligente Local
> Ecosistema Dulce Universe | Versión 1.8.1 Stable

[![Plataforma - Windows](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078d4?style=for-the-badge&logo=windows)](https://github.com/Dulce-universo/DulceNav)
[![Plataforma - Android](https://img.shields.io/badge/Platform-Android%208.0%20%2B-3ddc84?style=for-the-badge&logo=android)](https://github.com/Dulce-universo/DulceNav)
[![Version](https://img.shields.io/badge/Release-v1.8.1-morado?style=for-the-badge&color=8A2BE2)](https://github.com/Dulce-universo/DulceNav/releases)

**DulceNav** es un navegador web ultra-ligero y privado diseñado bajo la estética **DulceUI Ultra**. Incorpora **Inteligencia Artificial local autónoma (DulceMind v1.8.1)** 100% offline (sin Ollama ni apps externas), bloqueador cosmético de anuncios (ABP/uBlock), protección biométrica de credenciales y optimizador adaptativo de memoria RAM en tiempo real.

---

## 📥 INSTALADORES Y APKs (v1.8.1)

### 🖥️ Windows (10 / 11 de 64 bits)
| Archivo | Ubicación en Repo | Enlace Directo |
|---|---|---|
| **`DulceNav_v1.8.1_Setup.exe`** | `windows/` | [**⬇️ DESCARGAR PARA WINDOWS**](./windows/DulceNav_v1.8.1_Setup.exe) |

---

### 📱 Android (Oreo 8.0 o superior)
| Versión APK | Arquitectura | Ubicación en Repo | Enlace Directo |
|---|---|---|---|
| **APK Universal** | FAT (Todas) | `android/` | [**⬇️ DESCARGAR APK UNIVERSAL**](./android/app-release.apk) |
| **APK ARM64** | arm64-v8a | `android/` | [**⚡ DESCARGAR APK ARM64**](./android/app-arm64-v8a-release.apk) |
| **APK ARM32** | armeabi-v7a | `android/` | [**📦 DESCARGAR APK ARM32**](./android/app-armeabi-v7a-release.apk) |
| **APK x86_64** | x86_64 | `android/` | [**💻 DESCARGAR APK x86_64**](./android/app-x86_64-release.apk) |

---

## ✨ Características Principales (v1.8.1)

- 🤖 **IA Autónoma 100% Local (DulceMind):** Motor nativo GGUF in-process (`llama_cpp_dart`) sin Ollama ni dependencias externas. Descarga en 1 clic desde HuggingFace, importador de blobs de Ollama, autoliberación de memoria RAM tras 5 min de inactividad y switch de ocultación total.
- 🎨 **Interfaz Glassmorphic & Color Adaptativo (Safari/Vivaldi):** Pantalla de inicio con degradados dinámicos y elevación hover. La barra de navegación se adapta al `<meta name="theme-color">` del sitio actual con transición suave de 300ms y contraste dinámico de texto/iconos.
- 🔄 **Actualizaciones Incrementales In-Place:** Instalación transparente sobre versiones anteriores sin desinstalar. Garantiza la preservación del 100% de datos del usuario, contraseñas cifradas, marcadores y sesiones abiertas.
- 🔙 **Botón de Navegación Reactivo:** Evaluación en tiempo real de `canGoBack` con habilitación/deshabilitación visual e inserción automática de historial desde HomeScreen.
- 🧹 **Bloqueador Cosmético de Anuncios:** Elimina contenedores vacíos y huecos blancos dejados por anuncios (`display:none !important` + `MutationObserver`), compatible con reglas ABP/uBlock.
- 🛡️ **Seguridad, Cookies Cifradas y Biometría:** Autocompletado y almacenamiento de sesiones cifrado con **DPAPI / Android Keystore AES**, protección biométrica (**Windows Hello / Huella dactilar**), pestañas de incógnito blindadas (`FLAG_SECURE`) y DNS over HTTPS (Cloudflare/Quad9).
- ⚡ **Perfiles de Rendimiento Automáticos:** Hibernación inteligente de pestañas inactivas adaptada a la RAM y núcleos de tu equipo.

---

*Desarrollado con ❤️ por el equipo de **Dulce Universe** desde Colombia.*
