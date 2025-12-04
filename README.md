# win10to11

Script de ayuda para intentar actualizar equipos con hardware no soportado a Windows 11.

IMPORTANTE: Este repositorio contiene un script que aplica bypasses y modifica
componentes de instalación. Usarlo puede causar pérdida de soporte, problemas
de estabilidad o fallos en el sistema. EJECUTA BAJO TU RESPONSABILIDAD.

## Contenido

- `win10to11.ps1` : Script principal para aplicar claves de registro, crear
  backups de `appraiserres.dll` y lanzar `setup.exe` de Windows 11.

## Requisitos

- PowerShell (ejecutar en sesión con privilegios de Administrador).
- El script puede usar una carpeta con los archivos de la ISO o montar un
  archivo `.iso` y usar la unidad montada. Puedes pasar `-InstallerPath` con
  la carpeta de los archivos o `-ISOPath` con el archivo `.iso`. Si no pasas
  ninguno, el script intentará detectar una `.iso` en el directorio actual
  y montarla automáticamente.

## Uso básico

Abrir PowerShell como administrador y ejecutar. Ejemplos:

```powershell
# Usar una carpeta con archivos descomprimidos
.\win10to11.ps1 -InstallerPath 'D:\Win11' -Force

# Montar y usar un archivo ISO (se desmonta automáticamente al terminar)
.\win10to11.ps1 -ISOPath 'D:\ISOs\Win11_Pro.iso' -Force

# Ejecutar desde la carpeta que contiene la .iso (el script intentará detectarla)
.\win10to11.ps1 -Force
```

Opciones principales:

- `-InstallerPath <ruta>` : Ruta donde están los archivos de la ISO (carpeta con `setup.exe`).
- `-ISOPath <ruta.iso>` : Ruta al archivo `.iso`; el script lo montará y usará la unidad montada.
- `-DryRun` : Simula las acciones sin modificar el sistema ni archivos.
- `-Force` : Omite prompts de confirmación (el script ya intenta ser no
  interactivo en la mayoría de los pasos).
- `-NoReboot` : Lanza el instalador con `/noreboot` (comportamiento por defecto).
- `-BypassOnly` : Solo aplica los cambios de registro necesarios para el bypass.
- `-Restore` : Intenta restaurar `appraiserres.dll` desde backups creados y
  eliminar las claves de registro creadas por el script.

Ejemplos:

- Dry run, revisar qué haría el script:

```powershell
.\win10to11.ps1 -InstallerPath 'D:\Win11' -DryRun
```

- Aplicar solo las claves de bypass en el registro:

```powershell
.\win10to11.ps1 -InstallerPath 'D:\Win11' -BypassOnly
```

- Restaurar cambios (si se hicieron backups):

```powershell
.\win10to11.ps1 -InstallerPath 'D:\Win11' -Restore
```

## Cómo funciona (resumen)

- Comprueba que `setup.exe` exista en la ruta indicada.
- Inyecta claves en `HKLM:\SYSTEM\Setup\LabConfig` y `HKLM:\SYSTEM\Setup\MoSetup`.
- Hace backup de `sources\appraiserres.dll` y lo reemplaza por un archivo vacío
  para evitar que el instalador bloquee la actualización.
- Lanza `setup.exe` con argumentos silenciosos y `DynamicUpdate` deshabilitado.

## Riesgos y consejos

- Siempre crea una copia completa del sistema (imagen/backup) antes de probar.
- Prueba primero en una máquina virtual o equipo no crítico.
- La eliminación o modificación de DLLs y claves del registro tiene riesgo de
  dejar el sistema en estado inestable.
- El uso de este script puede violar los términos de soporte de Microsoft.

## Contribuir

Si quieres mejorar el script, abre un issue o un pull request con tus cambios.

## Licencia

Este repositorio no incluye una licencia específica; asume responsabilidad del
uso en tu entorno. Añade una licencia si quieres permitir contribuciones con
condiciones claras.

**Uso remoto (descarga y ejecución directa — este repo)**

Si prefieres ejecutar el script directamente desde este repositorio remoto, puedes
usar `irm | iex` apuntando al `raw` de este mismo repo. Ten extremo cuidado: ejecutar
código remoto con `iex` es peligroso si no confías plenamente en el origen.

Ejemplo (PowerShell, ejecutar como Administrador):

```powershell
irm https://raw.githubusercontent.com/qtekfun/win10to11/master/win10to11.ps1 | iex
```

Comando alternativo (ejecutar en un proceso PowerShell temporal con política Bypass):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://raw.githubusercontent.com/qtekfun/win10to11/master/win10to11.ps1' | iex"
```

Recomendación segura (descargar, revisar, ejecutar):

```powershell
irm https://raw.githubusercontent.com/qtekfun/win10to11/master/win10to11.ps1 | Out-File .\temp_win10to11.ps1
notepad .\temp_win10to11.ps1   # revisar manualmente
powershell -NoProfile -ExecutionPolicy Bypass -File .\temp_win10to11.ps1 -InstallerPath 'D:\Win11' -DryRun
```

Advertencias:
- Verifica el contenido del script antes de ejecutarlo. Descargar y revisar localmente es la opción más segura.
- Ejecutar `iex` con URLs no verificadas puede comprometer el sistema.
- Usa `-DryRun` y prueba en una VM antes de ejecutar en equipos de producción.

Cómo habilitar la ejecución de scripts (opciones):

- Habilitar permanentemente para el usuario actual (RemoteSigned recomendado):

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

- Habilitar solo para un comando (no cambia la configuración del sistema):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm '<URL>' | iex"
```

- Para mayor seguridad, descarga primero y verifica el hash antes de ejecutar:

```powershell
irm https://raw.githubusercontent.com/qtekfun/win10to11/master/win10to11.ps1 -OutFile .\temp_win10to11.ps1
Get-FileHash .\temp_win10to11.ps1 -Algorithm SHA256
# Revisar el archivo manualmente y comparar hash con el publicado (si existe)
```

Notas finales:
- El script requiere ejecución en una sesión con privilegios de Administrador.
- Preferible probar en un entorno controlado/VM antes de usar en producción.
