# Part 2 of Install-Prat.ps1
#
# This needs to install:
# - Anything needed to run Build-Codebase or Test-Codebase for prat.
using module ..\lib\TextFileEditor\TextFileEditor.psd1
using module ..\lib\Installers\Installers.psd1

param([switch] $SkipDeployStep)

. $PSScriptRoot\profile\scriptProfile.ps1

$it = $null

try {
    $it = Start-Installation "Install-Prat" -InstallationDatabaseLocation "$home\prat\auto\instDb"

    Install-PratPackage $it "pester"
} catch {
    if ($null -ne $it) { $it.ReportErrorContext($error[0]) }
    throw
} finally {
    if ($null -ne $it) { $it.StopInstallation() }
}

if (!$SkipDeployStep) {
    # Build, test, deploy:
    Start-CodebaseDevLoop
}

