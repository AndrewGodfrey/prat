using module ..\lib\TextFileEditor\TextFileEditor.psd1
using module ..\lib\Installers\Installers.psd1

param ([switch] $Force)

$ErrorActionPreference = "stop"

$it = $null

function instSchTasks($it) {
    $stage = $it.StartStage('schTasks')

    Install-DailyScheduledTask $stage "test" "Prat - test task" $PSScriptRoot\..\lib\schtasks\daily_test.ps1 "1:08AM"
    Install-DailyScheduledTask $stage "cleanManagedDirectories" "Prat - Clean managed directories"  $PSScriptRoot\..\lib\schtasks\daily_cleanManagedDirectories.ps1 "1:30AM"
    $onLogonScripts = & (Resolve-PratLibFile "lib/schtasks/Get-OnLogonScripts.ps1")
    if ($onLogonScripts.Count -gt 0) {
        Install-AtLogonScheduledTask $stage "onLogonScripts" "Prat - invoke on-logon scripts" $PSScriptRoot\..\lib\schtasks\onLogon_Invoke-OnLogonScripts.ps1
    }

    $it.EndStage($stage)
}

try {
    $it = Start-Installation "Deploy-Prat" -InstallationDatabaseLocation "$home\prat\auto\instDb" -Force:$Force

    Install-PsProfile $it
    
    instSchTasks $it

    # This is already done in Install-PratPhase3.ps1. Just putting it here for ease of Prat development.
    Install-PratPackage $it "pester"
} catch {
    if ($null -ne $it) { $it.ReportErrorContext($error[0]) }
    throw
} finally {
    if ($null -ne $it) { $it.StopInstallation() }
}


