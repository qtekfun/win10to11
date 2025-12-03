<#
.SYNOPSIS
    Script de asistencia para actualizar a Windows 11 en hardware no soportado.

.DESCRIPTION
    Este script automatiza algunos pasos comunes (inyección de claves de registro
    y neutralización de appraiserres.dll) antes de lanzar `setup.exe` de una
    instalación de Windows 11.

    ADVERTENCIA: Usar este script es riesgoso. Hacer backup y entender las
    implicaciones legales y de soporte es responsabilidad del usuario.

.PARAMETER InstallerPath
    Ruta donde se han copiado los archivos de la ISO de Windows 11. Por defecto
    `C:\Win11_Source`.

.PARAMETER DryRun
    Simula las acciones sin modificarlas (no cambia el registro ni archivos).

.PARAMETER Force
    Omite prompts de confirmación.

.PARAMETER NoReboot
    Lanza el instalador con `/noreboot` (por defecto se usa `/noreboot`).

.PARAMETER BypassOnly
    Solo aplica los cambios de registro y sale (no modifica DLL ni ejecuta setup).

.PARAMETER Restore
    Restaura backups realizados por el script (restaura appraiserres.dll y borra
    las claves creadas por este script).

.EXAMPLE
    .\win10to11.ps1 -InstallerPath 'D:\Win11' -Force

NOTA: Ejecutar con privilegios de Administrador.
#>

[CmdletBinding(SupportsShouldProcess=$true,DefaultParameterSetName='Run')]
param(
    [Parameter(Position=0)]
    [string]$InstallerPath = 'C:\Win11_Source',

    [switch]$DryRun,
    [switch]$Force,
    [switch]$NoReboot,
    [switch]$BypassOnly,
    [switch]$Restore
)

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','DEBUG')][string]$Level = 'INFO'
    )
    $ts = (Get-Date).ToString('s')
    switch ($Level) {
        'INFO'  { Write-Host "$ts [INFO]  $Message" -ForegroundColor Cyan }
        'WARN'  { Write-Warning $Message }
        'ERROR' { Write-Host "$ts [ERROR] $Message" -ForegroundColor Red }
        'DEBUG' { if ($PSBoundParameters.ContainsKey('Verbose')) { Write-Host "$ts [DEBUG] $Message" -ForegroundColor DarkGray } }
    }
}

function Ensure-Administrator {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log 'Se requieren permisos de administrador. Reejecuta en una sesión elevada.' 'ERROR'
        throw 'No administrador'
    }
}

function Backup-File {
    param(
        [Parameter(Mandatory=$true)][string]$Path
    )
    if (Test-Path $Path) {
        $backupDir = Join-Path -Path (Split-Path -Path $Path -Parent) -ChildPath 'backup_win11_script'
        if (-not (Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory | Out-Null }
        $dest = Join-Path $backupDir -ChildPath ((Get-Item $Path).Name + '.' + (Get-Date -Format 'yyyyMMddHHmmss') + '.bak')
        Copy-Item -Path $Path -Destination $dest -Force
        Write-Log "Backup de '$Path' creado en: $dest" 'INFO'
        return $dest
    } else {
        Write-Log "No existe archivo para respaldar: $Path" 'WARN'
        return $null
    }
}

function Set-Registry-Bypass {
    param(
        [switch]$WhatIfMode
    )
    $RegPath1 = 'HKLM:\SYSTEM\Setup\LabConfig'
    $RegPath2 = 'HKLM:\SYSTEM\Setup\MoSetup'

    if ($WhatIfMode) { Write-Log 'Modo DryRun: no se modificarán las claves del registro.' 'INFO'; return }

    if (-not (Test-Path $RegPath1)) { New-Item -Path 'HKLM:\SYSTEM\Setup' -Name 'LabConfig' -Force | Out-Null }
    if (-not (Test-Path $RegPath2)) { New-Item -Path 'HKLM:\SYSTEM\Setup' -Name 'MoSetup' -Force | Out-Null }

    $BypassKeys = @(
        'BypassTPMCheck','BypassSecureBootCheck','BypassRAMCheck',
        'BypassCPUCheck','BypassStorageCheck','BypassDiskCheck'
    )

    foreach ($key in $BypassKeys) {
        New-ItemProperty -Path $RegPath1 -Name $key -Value 1 -PropertyType DWORD -Force | Out-Null
        Write-Log "Clave creada/actualizada: $RegPath1\$key = 1" 'DEBUG'
    }
    New-ItemProperty -Path $RegPath2 -Name 'AllowUpgradesWithUnsupportedTPMOrCPU' -Value 1 -PropertyType DWORD -Force | Out-Null
    Write-Log "Clave creada/actualizada: $RegPath2\AllowUpgradesWithUnsupportedTPMOrCPU = 1" 'DEBUG'
}

function Neutralize-Appraiser {
    param(
        [string]$InstallerPath,
        [switch]$WhatIfMode
    )
    $DllPath = Join-Path -Path $InstallerPath -ChildPath 'sources\appraiserres.dll'
    if (-not (Test-Path $DllPath)) { Write-Log "DLL no encontrada: $DllPath" 'WARN'; return }

    if ($WhatIfMode) { Write-Log "DryRun: se simula respaldo y neutralización de $DllPath" 'INFO'; return }

    $backup = Backup-File -Path $DllPath
    try {
        Move-Item -Path $DllPath -Destination ($backup + '.orig') -Force -ErrorAction Stop
        # Crear archivo vacío para evitar que el instalador falle por falta de archivo
        New-Item -Path $DllPath -ItemType File -Force | Out-Null
        Write-Log "Appraiser neutralizado. Backup en: $backup.orig" 'INFO'
    } catch {
        Write-Log "No se pudo mover/respaldar appraiserres.dll: $_" 'WARN'
    }
}

function Restore-AppraiserAndRegistry {
    param(
        [string]$InstallerPath
    )
    $DllPath = Join-Path -Path $InstallerPath -ChildPath 'sources\appraiserres.dll'
    $backupDir = Join-Path -Path (Split-Path -Path $DllPath -Parent) -ChildPath 'backup_win11_script'
    if (Test-Path $backupDir) {
        $orig = Get-ChildItem -Path $backupDir -Filter 'appraiserres.dll.*.bak' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($orig) {
            Copy-Item -Path $orig.FullName -Destination $DllPath -Force
            Write-Log "Restaurado appraiserres.dll desde $($orig.FullName)" 'INFO'
        } else {
            Write-Log 'No se encontró backup de appraiserres.dll para restaurar.' 'WARN'
        }
    } else {
        Write-Log 'No existe carpeta de backup. Nada que restaurar.' 'WARN'
    }

    # Borrar las claves que creó este script
    $RegPath1 = 'HKLM:\SYSTEM\Setup\LabConfig'
    $RegPath2 = 'HKLM:\SYSTEM\Setup\MoSetup'
    if (Test-Path $RegPath1) {
        $BypassKeys = @('BypassTPMCheck','BypassSecureBootCheck','BypassRAMCheck','BypassCPUCheck','BypassStorageCheck','BypassDiskCheck')
        foreach ($k in $BypassKeys) {
            Remove-ItemProperty -Path $RegPath1 -Name $k -ErrorAction SilentlyContinue
            Write-Log "Eliminada clave (si existía): $RegPath1\$k" 'DEBUG'
        }
    }
    if (Test-Path $RegPath2) {
        Remove-ItemProperty -Path $RegPath2 -Name 'AllowUpgradesWithUnsupportedTPMOrCPU' -ErrorAction SilentlyContinue
        Write-Log "Eliminada clave (si existía): $RegPath2\AllowUpgradesWithUnsupportedTPMOrCPU" 'DEBUG'
    }
}

try {
    Ensure-Administrator
} catch {
    exit 1
}

Clear-Host
Write-Log 'INICIANDO PROTOCOLO DE ACTUALIZACION A WINDOWS 11 (PARA HARDWARE NO SOPORTADO)' 'INFO'

$SetupFile = Join-Path -Path $InstallerPath -ChildPath 'setup.exe'

if ($Restore) {
    Write-Log 'Modo RESTAURACION seleccionado.' 'INFO'
    try {
        Restore-AppraiserAndRegistry -InstallerPath $InstallerPath
        Write-Log 'Restauración completada.' 'INFO'
    } catch {
        Write-Log "Error durante restauración: $_" 'ERROR'
    }
    exit 0
}

if (-not (Test-Path $SetupFile)) {
    Write-Log "No se encuentra el instalador en: $InstallerPath" 'ERROR'
    Write-Host 'Por favor copia los archivos de la ISO a esa carpeta antes de ejecutar este script.' -ForegroundColor Red
    exit 2
}

if ($BypassOnly) {
    Write-Log 'Aplicando solo las claves de bypass en el registro (BypassOnly).' 'INFO'
    if ($DryRun) { Set-Registry-Bypass -WhatIfMode } else { Set-Registry-Bypass }
    Write-Log 'Operación completada.' 'INFO'
    exit 0
}

# 1) Inyectar claves de registro
Write-Log '[1/4] Inyectando claves de bypass en el Registro...' 'INFO'
if ($DryRun) { Set-Registry-Bypass -WhatIfMode } else { Set-Registry-Bypass }

# 2) Neutralizar appraiserres.dll con respaldo
Write-Log '[2/4] Neutralizando evaluador de hardware (appraiserres.dll)...' 'INFO'
if ($DryRun) { Neutralize-Appraiser -InstallerPath $InstallerPath -WhatIfMode } else { Neutralize-Appraiser -InstallerPath $InstallerPath }

# 3) Preparar y lanzar setup.exe (en background por defecto)
Write-Log '[3/4] Preparando ejecución de setup.exe...' 'INFO'
$Argumentos = '/auto upgrade /quiet'
if ($NoReboot) { $Argumentos += ' /noreboot' } else { $Argumentos += ' /noreboot' }
$Argumentos += ' /DynamicUpdate disable /ShowOOBE none /Compat IgnoreWarning'

Write-Log "Argumentos: $Argumentos" 'DEBUG'

if ($DryRun) {
    Write-Log "DryRun: se simula ejecución: $SetupFile $Argumentos" 'INFO'
    Write-Log 'Proceso finalizado en modo DryRun.' 'INFO'
    exit 0
}

try {
    Start-Process -FilePath $SetupFile -ArgumentList $Argumentos -WindowStyle Hidden -ErrorAction Stop
    Write-Log '[4/4] PROCESO INICIADO CORRECTAMENTE.' 'INFO'
    Write-Host '---------------------------------------------------------'
    Write-Host 'ESTADO: El instalador está corriendo en background.'
    Write-Host "ACCION: Cuando el proceso 'setup.exe' desaparezca del Administrador de Tareas, reinicia el equipo para aplicar la actualización."
    Write-Host '---------------------------------------------------------'
} catch {
    Write-Log "Error al ejecutar setup.exe: $_" 'ERROR'
    exit 3
}

exit 0