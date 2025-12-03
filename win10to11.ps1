# ================================================================
#  SCRIPT DE DESPLIEGUE REMOTO WINDOWS 11 (UNSUPPORTED HARDWARE)
#  Uso: irm https://raw.github... | iex
# ================================================================

$InstallerPath = "C:\Win11_Source"
$SetupFile     = "$InstallerPath\setup.exe"

# 1. VERIFICAR PERMISOS DE ADMINISTRADOR
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Este script requiere permisos de Administrador."
    Exit
}

Clear-Host
Write-Host "INICIANDO PROTOCOLO DE ACTUALIZACION FORZADA A WINDOWS 11" -ForegroundColor Cyan
Write-Host "---------------------------------------------------------"

# 2. VERIFICAR SI EXISTEN LOS ARCHIVOS DE INSTALACION
if (-not (Test-Path $SetupFile)) {
    Write-Error "No se encuentra el instalador en: $InstallerPath"
    Write-Host "Por favor, copia los archivos de la ISO a esa carpeta antes de ejecutar este script." -ForegroundColor Red
    Exit
}

# 3. INYECTAR CLAVES DE REGISTRO (BYPASS TOTAL)
Write-Host "[1/4] Inyectando claves de bypass en el Registro..." -ForegroundColor Yellow

$RegPath1 = "HKLM:\SYSTEM\Setup\LabConfig"
$RegPath2 = "HKLM:\SYSTEM\Setup\MoSetup"

# Crear rutas si no existen
if (!(Test-Path $RegPath1)) { New-Item -Path "HKLM:\SYSTEM\Setup" -Name "LabConfig" -Force | Out-Null }
if (!(Test-Path $RegPath2)) { New-Item -Path "HKLM:\SYSTEM\Setup" -Name "MoSetup" -Force | Out-Null }

# Lista de bloqueos a eliminar
$BypassKeys = @(
    "BypassTPMCheck", "BypassSecureBootCheck", "BypassRAMCheck",
    "BypassCPUCheck", "BypassStorageCheck", "BypassDiskCheck"
)

foreach ($key in $BypassKeys) {
    New-ItemProperty -Path $RegPath1 -Name $key -Value 1 -PropertyType DWORD -Force | Out-Null
}
New-ItemProperty -Path $RegPath2 -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -Value 1 -PropertyType DWORD -Force | Out-Null

# 4. TRUCO SUCIO: ELIMINAR APPRAISERRES.DLL (DOBLE SEGURIDAD)
# Esto evita que el instalador cargue la librería de evaluación de hardware
Write-Host "[2/4] Neutralizando evaluador de hardware (appraiserres.dll)..." -ForegroundColor Yellow
$DllPath = "$InstallerPath\sources\appraiserres.dll"
if (Test-Path $DllPath) {
    try {
        Remove-Item -Path $DllPath -Force -ErrorAction SilentlyContinue
        # Creamos un archivo vacio para engañar al installer
        New-Item -Path $DllPath -ItemType File -Force | Out-Null
        Write-Host "      -> Archivo neutralizado con éxito." -ForegroundColor Green
    } catch {
        Write-Warning "      -> No se pudo modificar el archivo DLL. Confiando solo en el registro."
    }
}

# 5. LANZAR INSTALACION SILENCIOSA
Write-Host "[3/4] Ejecutando Setup.exe en segundo plano..." -ForegroundColor Yellow
Write-Host "      El usuario NO verá nada en pantalla. No reiniciar aun." -ForegroundColor Gray

$Argumentos = "/auto upgrade /quiet /noreboot /DynamicUpdate disable /ShowOOBE none /Compat IgnoreWarning"

try {
    Start-Process -FilePath $SetupFile -ArgumentList $Argumentos -WindowStyle Hidden

    Write-Host "`n[4/4] PROCESO INICIADO CORRECTAMENTE." -ForegroundColor Green
    Write-Host "---------------------------------------------------------"
    Write-Host "ESTADO: El instalador esta corriendo en background."
    Write-Host "ACCION: Cuando el proceso 'setup.exe' desaparezca del Task Manager,"
    Write-Host "        reinicia el equipo para aplicar la actualizacion."
    Write-Host "---------------------------------------------------------"
} catch {
    Write-Error "Error al ejecutar setup.exe: $_"
}