using module ..\lib\TextFileEditor\TextFileEditor.psd1
using module ..\lib\Installers\Installers.psd1

param ([switch] $Force)

$ErrorActionPreference = "stop"

$it = $null

function instSchTasks($it) {
    $stage = $it.StartStage('schTasks')
    Install-DailyScheduledTask $stage "test" "Prat - test task" $PSScriptRoot\..\lib\schtasks\daily_test.ps1 "1:08AM"
    $it.EndStage($stage)
}

try {
    $it = Start-Installation "Deploy-Prat" -InstallationDatabaseLocation "$home\prat\auto\instDb" -Force:$Force

    Install-PsProfile $it
    
    instSchTasks $it
} catch {
    if ($null -ne $it) { $it.ReportErrorContext($error[0]) }
    throw
} finally {
    if ($null -ne $it) { $it.StopInstallation() }
}


