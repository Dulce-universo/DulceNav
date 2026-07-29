# ==============================================================
# DulceNav - build_windows.ps1
# Script de automatización para instalador ejecutable profesional (Inno Setup).
# ==============================================================

Write-Host "==================================================" -ForegroundColor Magenta
Write-Host " Iniciando compilación de DulceNav v1.8.1 para Windows" -ForegroundColor Magenta
Write-Host "==================================================" -ForegroundColor Magenta

# 1. Ejecutar flutter pub get por si acaso
Write-Host "1. Verificando dependencias..." -ForegroundColor Cyan
flutter pub get

if ($LASTEXITCODE -ne 0) {
    Write-Error "Error al ejecutar 'flutter pub get'."
    Exit 1
}

# 2. Generar icono .ico multi-resolución a partir de app_icon.png
Write-Host "2. Generando icono .ico multi-resolución (16, 24, 32, 48, 64, 128, 256 px)..." -ForegroundColor Cyan
python -c @"
from PIL import Image
import sys

src = 'assets/icons/app_icon.png'
dst = 'assets/icons/app_icon.ico'

try:
    img = Image.open(src).convert('RGBA')
    sizes = [(16,16), (24,24), (32,32), (48,48), (64,64), (128,128), (256,256)]
    imgs = [img.resize(s, Image.LANCZOS) for s in sizes]
    imgs[0].save(dst, format='ICO', sizes=sizes, append_images=imgs[1:])
    print('Icono ICO generado con exito: ' + dst)
except Exception as e:
    print('Error generando ICO: ' + str(e))
    sys.exit(1)
"@

if ($LASTEXITCODE -ne 0) {
    Write-Warning "No se pudo generar el icono .ico usando Python Pillow. Verifique su entorno."
}


# 3. Compilar aplicación en modo Release
Write-Host "3. Compilando aplicación en modo Release..." -ForegroundColor Cyan
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Error "Error en 'flutter build windows'."
    Exit 1
}

# 4. Verificar e instalar Inno Setup si no está presente
Write-Host "4. Verificando instalación de Inno Setup 6..." -ForegroundColor Cyan
$isccPath = ""

# Rutas candidatas
$candidates = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)

foreach ($c in $candidates) {
    if (Test-Path $c) {
        $isccPath = $c
        break
    }
}

if ($isccPath -eq "") {
    # Buscar en el PATH
    $isccCmd = Get-Command iscc -ErrorAction SilentlyContinue
    if ($isccCmd) {
        $isccPath = $isccCmd.Source
    } else {
        Write-Host "Inno Setup no detectado. Intentando instalar mediante winget..." -ForegroundColor Yellow
        winget install JRSoftware.InnoSetup --silent --accept-package-agreements --accept-source-agreements
        
        # Volver a comprobar candidatos tras la instalación
        foreach ($c in $candidates) {
            if (Test-Path $c) {
                $isccPath = $c
                break
            }
        }
        
        if ($isccPath -eq "") {
            Write-Error "Inno Setup no pudo ser instalado automáticamente. Por favor instálelo de forma manual desde: https://jrsoftware.org/isdl.php"
            Exit 1
        }
    }
}

# 5. Generar instalador EXE clásico
Write-Host "5. Generando instalador EXE profesional..." -ForegroundColor Cyan
& $isccPath windows/DulceNav_Setup.iss

if ($LASTEXITCODE -ne 0) {
    Write-Error "Error al generar el instalador clásico EXE."
    Exit 1
}

Write-Host "==================================================" -ForegroundColor Green
Write-Host " ¡Compilación e Instalador EXE completado con éxito!" -ForegroundColor Green
Write-Host " El instalador clásico está listo para distribución en:" -ForegroundColor Green
Write-Host " build\windows\installer\DulceNav_v1.8.1_Setup.exe" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Green
