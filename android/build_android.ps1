# ==============================================================
# DulceNav - build_android.ps1
# Script de automatización para empaquetado de Android (APKs de distribución).
# ==============================================================

Write-Host "==================================================" -ForegroundColor Magenta
Write-Host " Iniciando compilación de DulceNav v1.8.1 para Android" -ForegroundColor Magenta
Write-Host "==================================================" -ForegroundColor Magenta

# 1. Ejecutar flutter pub get por si acaso
Write-Host "1. Verificando dependencias..." -ForegroundColor Cyan
flutter pub get

if ($LASTEXITCODE -ne 0) {
    Write-Error "Error al ejecutar 'flutter pub get'."
    Exit 1
}

# 2. Compilar APKs de producción divididos por arquitectura (tamaño minimizado)
Write-Host "2. Generando APKs compilados por arquitectura (--release --split-per-abi)..." -ForegroundColor Cyan
flutter build apk --release --split-per-abi

if ($LASTEXITCODE -ne 0) {
    Write-Error "Error al generar los APKs por arquitectura."
    Exit 1
}

# 3. Compilar APK Universal "FAT APK" (ideal para distribución directa y testing rápido)
Write-Host "3. Generando APK Universal de instalación rápida (--release)..." -ForegroundColor Cyan
flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Error "Error al generar el APK Universal."
    Exit 1
}

# NOTA SOBRE GOOGLE PLAY STORE (AAB):
# Si desea publicar en Google Play Store y requiere el App Bundle (AAB), puede ejecutar:
#   flutter build appbundle --release
# Nota: Si este comando reporta fallas en "strip debug symbols", verifique su instalación local
# de Android Studio / llvm-strip del NDK mediante "flutter doctor -v".

Write-Host "==================================================" -ForegroundColor Green
Write-Host " ¡Compilación de Android completada!" -ForegroundColor Green
Write-Host " Los archivos APK de distribución están listos en:" -ForegroundColor Green
Write-Host " - APK Universal: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Yellow
Write-Host " - APK ARM64:     build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" -ForegroundColor Yellow
Write-Host " - APK ARM32:     build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Green
