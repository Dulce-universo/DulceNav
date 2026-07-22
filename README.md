# 🌌 DulceNav — Navegador Privado Inteligente Local
> Ecosistema Dulce Universe | Versión 1.7.0 Stable

[![Plataforma - Windows](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078d4?style=for-the-badge&logo=windows)](https://github.com/Dulce-universo/DulceNav)
[![Plataforma - Android](https://img.shields.io/badge/Platform-Android%208.0%20%2B-3ddc84?style=for-the-badge&logo=android)](https://github.com/Dulce-universo/DulceNav)
[![Version](https://img.shields.io/badge/Release-v1.7.0-morado?style=for-the-badge&color=8A2BE2)](https://github.com/Dulce-universo/DulceNav/releases)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

**DulceNav** es un navegador web premium, ultra-ligero y centrado en la privacidad absoluta del usuario. Diseñado bajo la estética **DulceUI Ultra** con efectos de glassmorphism interactivos, ofrece una suite de **Inteligencia Artificial local (DulceMind)** impulsada por Ollama 100% offline, protección biométrica de credenciales y un optimizador de recursos que adapta el navegador a tu hardware en tiempo real.

---

## 📥 Enlaces de Descarga (Releases Oficiales)

Puedes descargar los instaladores listos para usar directamente desde los siguientes enlaces:

### 🖥️ Windows (10 / 11 de 64 bits)
* [**Descargar Instalador Clásico (.exe)**](https://github.com/Dulce-universo/DulceNav/releases/download/v1.7.0/DulceNav_v1.7.0_Setup.exe)  
  *Instalación rápida y segura con soporte de accesos directos y Edge WebView2 integrado.*

### 📱 Android (Oreo 8.0 o superior)
* [**Descargar APK Universal (FAT)**](https://github.com/Dulce-universo/DulceNav/releases/download/v1.7.0/app-release.apk) (Ideal para distribución general y pruebas rápidas)
* [**Descargar APK ARM64 (64-bits)**](https://github.com/Dulce-universo/DulceNav/releases/download/v1.7.0/app-arm64-v8a-release.apk) (Recomendado para la gran mayoría de dispositivos modernos)
* [**Descargar APK ARM32 (32-bits)**](https://github.com/Dulce-universo/DulceNav/releases/download/v1.7.0/app-armeabi-v7a-release.apk) (Para dispositivos Android antiguos o de gama de entrada)

---

## ✨ Características Premium (v1.7.0)

### 🤖 1. DulceMind: Inteligencia Artificial Local y Offline
* **100% Privado y Local:** Integración con **Ollama** (`http://localhost:11434`) para ejecutar modelos avanzados de lenguaje de forma local. Tus datos nunca viajan a servidores externos.
* **Sugerencias de Modelos por Hardware:** Detecta de forma inteligente la RAM del equipo y recomienda el modelo ideal:
  - **RAM < 8 GB:** Recomienda modelos súper optimizados como `Llama 3.2 1B` o `Qwen 2.5 1.5B`.
  - **RAM ≥ 8 GB:** Sugiere modelos con mayor razonamiento lógico de 3B como `Llama 3.2 3B` o `Qwen 2.5 3B`.
* **Acciones Rápidas en Página (Chips Contextuales):**
  - **Resumir:** Genera resúmenes cortos (3 oraciones), detallados o puntos clave numerados.
  - **Explicar:** Describe palabras o artículos en lenguaje sencillo (metáforas cotidianas) o nivel técnico estructurado.
  - **Traducir:** Traducción bidireccional al Inglés, Portugués, Francés o Alemán conservando el sentido.
  - **Extraer:** Identifica automáticamente Fechas, Datos numéricos relevantes o Pasos de tutoriales.
* **Cofre de Chat Dinámico:** UI esmerilada con indicador LED de estado de Ollama en tiempo real, guía interactiva de configuración y comandos de terminal si el servidor no está corriendo.

### 🛡️ 2. Seguridad Blindada & DulcePrivacy
* **Protección Biométrica / PIN:** El gestor de contraseñas y autocompletado requiere autenticación mediante **Windows Hello / Huella dactilar** en el dispositivo. En su defecto, permite establecer un PIN cifrado localmente con SHA-256.
* **Pestañas de Incógnito Blindadas:** Aislamiento absoluto de cookies y caché por pestaña. En Android, bloquea de forma nativa las capturas de pantalla y previene que el navegador se visualice en la vista de aplicaciones recientes.
* **DoH (DNS over HTTPS):** Cifrado de consultas DNS mediante Cloudflare (1.1.1.1), Google (8.8.8.8) o Quad9 para evitar la interceptación y rastreo del ISP.
* **Portapapeles Seguro:** Limpieza automatica de contraseñas copiadas de la memoria del portapapeles tras 30 segundos.

### ⚡ 3. Detección de Hardware & Ajustes Adaptativos
* **Monitoreo de Sistema:** Diagnóstico interactivo en Ajustes que detalla el Sistema Operativo, Procesador, Núcleos lógicos, RAM total instalada, almacenamiento libre y resolución de pantalla.
* **Perfiles de Rendimiento Inteligentes:**
  - **Ahorro de Recursos (RAM < 4 GB):** Activa hibernación rápida a los 5 min, adblocker máximo, desactiva efectos visuales (blurs) y apaga DoH para aligerar la carga del procesador.
  - **Equilibrado (RAM 4-8 GB):** Balance entre efectos premium e hibernación moderada (15 min) con DoH activo.
  - **Rendimiento Máximo (RAM > 8 GB y CPU ≥ 8 Cores):** Carga completa del sistema, efectos visuales de alta gama e Site Isolation activo.
  - **Privacidad Máxima (Manual):** Bloqueo máximo, DoH en Quad9, Site Isolation y borrado al salir activados.
* **Protección de Personalizaciones:** Si realizas cambios manuales a los interruptores de Ajustes, el navegador lo recuerda para no sobrescribir tus preferencias al cambiar de perfil sin confirmación previa.

### 🎨 4. DulceUI Ultra & Diseños Fluidos
* **Diseño Glassmorphic:** Fondos con desenfoque de fondo dinámico y niveles de opacidad personalizables.
* **Barra URL Adaptativa:** Mapea el color dominante de la página web visitada y transiciona suavemente el fondo de la barra del navegador (Safari/Vivaldi style), adaptando automáticamente el contraste de texto/iconos (blanco/negro) según la luminosidad del sitio.
* **Barra de Favoritos Premium:** Acceso rápido y esmerilado con menú contextual para editar y organizar tus enlaces.

---

## 📄 Licencia

DulceNav se distribuye bajo la licencia **MIT**. Puedes consultar el archivo [LICENSE](LICENSE) para más detalles.

---
*Desarrollado con ❤️ por el equipo de **Dulce Universe**, Desde colombia.
