# Script de Backup Local para el Proyecto Flutter
# Uso: .\scripts\backup-project.ps1

$ErrorActionPreference = "Stop"

# Configuracion
$projectPath = $PSScriptRoot + "\.."
$backupBasePath = "D:\carposv\apps\taxi\backups"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupFolder = "$backupBasePath\backup_$timestamp"

# Archivos y carpetas a excluir del backup
$excludeItems = @(
    "build",
    ".dart_tool",
    ".flutter-plugins-dependencies",
    "android\app\build",
    "android\build",
    "android\.gradle",
    "ios\Flutter\ephemeral",
    "ios\Pods",
    "ios\.symlinks",
    "node_modules",
    ".git",
    "*.log",
    "*.iml"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BACKUP LOCAL DEL PROYECTO" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Crear directorio de backup si no existe
if (-not (Test-Path $backupBasePath)) {
    New-Item -ItemType Directory -Path $backupBasePath -Force | Out-Null
    Write-Host "OK: Directorio de backup creado: $backupBasePath" -ForegroundColor Green
}

# Crear carpeta de backup con timestamp
New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
Write-Host "Creando backup en: $backupFolder" -ForegroundColor Yellow
Write-Host ""

# Funcion para copiar archivos excluyendo los especificados
function Copy-ProjectFiles {
    param(
        [string]$Source,
        [string]$Destination,
        [string[]]$Exclude
    )
    
    $sourcePath = (Resolve-Path $Source).Path
    if (-not $sourcePath.EndsWith("\")) {
        $sourcePath += "\"
    }
    
    Get-ChildItem -Path $Source -Recurse | ForEach-Object {
        $fullPath = $_.FullName
        if ($fullPath.StartsWith($sourcePath)) {
            $relativePath = $fullPath.Substring($sourcePath.Length)
        } else {
            $relativePath = $_.Name
        }
        
        $shouldExclude = $false
        
        foreach ($excludeItem in $Exclude) {
            if ($relativePath -like "*\$excludeItem\*" -or $relativePath -like "$excludeItem\*" -or $relativePath -eq $excludeItem) {
                $shouldExclude = $true
                break
            }
        }
        
        if (-not $shouldExclude) {
            $destPath = Join-Path $Destination $relativePath
            
            if ($_.PSIsContainer) {
                if (-not (Test-Path $destPath)) {
                    New-Item -ItemType Directory -Path $destPath -Force | Out-Null
                }
            } else {
                $destDir = Split-Path $destPath -Parent
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item $_.FullName -Destination $destPath -Force
            }
        }
    }
}

# Copiar archivos del proyecto
Write-Host "Copiando archivos del proyecto..." -ForegroundColor Yellow
try {
    Copy-ProjectFiles -Source $projectPath -Destination $backupFolder -Exclude $excludeItems
    Write-Host "OK: Archivos copiados exitosamente" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Error al copiar archivos: $_" -ForegroundColor Red
    exit 1
}

# Crear archivo de informacion del backup
$backupInfo = @"
BACKUP DEL PROYECTO FZKT_OPENSTREET
====================================
Fecha: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Ubicacion: $backupFolder
Proyecto: $projectPath

Archivos excluidos:
- build/
- .dart_tool/
- node_modules/
- Archivos de compilacion

Para restaurar este backup:
1. Copia todos los archivos de esta carpeta a la ubicacion del proyecto
2. Ejecuta: flutter pub get
3. Ejecuta: flutter clean (opcional)
"@

$backupInfo | Out-File -FilePath "$backupFolder\BACKUP_INFO.txt" -Encoding UTF8

# Comprimir el backup (opcional)
Write-Host ""
Write-Host "Deseas comprimir el backup? (S/N): " -ForegroundColor Yellow -NoNewline
$compress = Read-Host

if ($compress -eq "S" -or $compress -eq "s" -or $compress -eq "Y" -or $compress -eq "y") {
    $zipPath = "$backupBasePath\backup_$timestamp.zip"
    Write-Host "Comprimiendo backup..." -ForegroundColor Yellow
    
    try {
        Compress-Archive -Path "$backupFolder\*" -DestinationPath $zipPath -Force
        Write-Host "OK: Backup comprimido: $zipPath" -ForegroundColor Green
        
        # Eliminar carpeta sin comprimir para ahorrar espacio
        Write-Host "Eliminar carpeta sin comprimir? (S/N): " -ForegroundColor Yellow -NoNewline
        $delete = Read-Host
        if ($delete -eq "S" -or $delete -eq "s" -or $delete -eq "Y" -or $delete -eq "y") {
            Remove-Item -Path $backupFolder -Recurse -Force
            Write-Host "OK: Carpeta eliminada" -ForegroundColor Green
        }
    } catch {
        Write-Host "ADVERTENCIA: No se pudo comprimir: $_" -ForegroundColor Yellow
        Write-Host "   El backup esta disponible en: $backupFolder" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  OK: BACKUP COMPLETADO" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Ubicacion del backup:" -ForegroundColor White
if (Test-Path $zipPath) {
    Write-Host "  $zipPath" -ForegroundColor Cyan
} else {
    Write-Host "  $backupFolder" -ForegroundColor Cyan
}
Write-Host ""
