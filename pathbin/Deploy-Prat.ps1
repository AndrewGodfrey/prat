using module ..\lib\TextFileEditor\TextFileEditor.psd1
using module ..\lib\Installers\Installers.psd1

param ([switch] $Force)

$ErrorActionPreference = "stop"

$it = $null

try {
    $it = Start-Installation "Deploy-Prat" -InstallationDatabaseLocation "$home\prat\auto\instDb" -Force:$Force

    Install-PsProfile $it
} catch {
    if ($null -ne $it) { $it.ReportErrorContext($error[0]) }
    throw
} finally {
    if ($null -ne $it) { $it.StopInstallation() }
}


