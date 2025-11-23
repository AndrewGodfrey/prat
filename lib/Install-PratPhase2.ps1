# Part 2 of Install-Prat.ps1
#
# This needs to install Powershell Core.
using module ..\lib\Installers\Installers.psd1

param([switch] $SkipDeployStep)

. $PSScriptRoot\profile\scriptProfile.ps1

$it = $null

try {
    $it = Start-Installation "Install-PratPhase2" -InstallationDatabaseLocation "$home\prat\auto\instDb"

    Install-PratPackage $it "pwsh"
} catch {
    if ($null -ne $it) { $it.ReportErrorContext($error[0]) }
    throw
} finally {
    if ($null -ne $it) { $it.StopInstallation() }
}

pwsh $home\prat\lib\Install-PratPhase3.ps1 -SkipDeployStep:$SkipDeployStep
