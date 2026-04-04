using module .\TextFileEditor\TextFileEditor.psd1
using module .\Installers\Installers.psd1

param([switch]$Force)

function main($Force) {
    $ErrorActionPreference = "stop"

    $it = $null

    try {
        $it = Start-Installation "prat deploy" -InstallationDatabaseLocation "$home\prat\auto\instDb" -Force:$Force

        Install-PsProfile $it
        instInteractiveAliases $it

        instSchTasks $it

        # This is already done in Install-PratPhase3.ps1. Just putting it here for ease of Prat development.
        Install-PratPackage $it "pester"
    } catch {
        if ($null -ne $it) { $it.ReportErrorContext($error[0]) }
        throw
    } finally {
        if ($null -ne $it) { $it.StopInstallation() }
    }

    updateModuleHashes
}

function updateModuleHashes {
    # Update hash files so open sessions detect that their loaded modules are stale.
    # Must run after a successful deploy (not in finally) so we don't signal staleness on a failed deploy.
    . "$PSScriptRoot/moduleHashes.ps1"
    pratWriteModuleHash 'PratBase'       "$PSScriptRoot/PratBase"
    pratWriteModuleHash 'TextFileEditor' "$PSScriptRoot/TextFileEditor"
    pratWriteModuleHash 'Installers'     "$PSScriptRoot/Installers"
}

function instSchTasks($it) {
    $stage = $it.StartStage('schTasks')

    Install-DailyScheduledTask $stage "test" "Prat - test task" $PSScriptRoot\schtasks\daily_test.ps1 "1:08AM"
    Install-DailyScheduledTask $stage "cleanManagedDirectories" "Prat - Clean managed directories"  $PSScriptRoot\schtasks\daily_cleanManagedDirectories.ps1 "1:30AM"
    $onLogonScripts = & (Resolve-PratLibFile "lib/schtasks/Get-OnLogonScripts.ps1")
    if ($onLogonScripts.Count -gt 0) {
        Install-AtLogonScheduledTask $stage "onLogonScripts" "Prat - invoke on-logon scripts" $PSScriptRoot\schtasks\onLogon_Invoke-OnLogonScripts.ps1
    }

    $it.EndStage($stage)
}

function instInteractiveAliases($it) {
    # If any of these aliases prove objectionable, they can be made opt-in using pratPackages.
    # For an example see the package "df", which aliases to Get-DiskFreeSpace.

    $stage = $it.StartStage("interactive aliases")
    Install-InteractiveAlias $stage 'pb' 'Prebuild-Codebase'
    Install-InteractiveAlias $stage 'b' 'Build-Codebase'
    Install-InteractiveAlias $stage 't' 'Test-Codebase'
    Install-InteractiveAlias $stage 'd' 'Deploy-Codebase'
    Install-InteractiveAlias $stage 'x' 'Start-CodebaseDevLoop'

    Install-InteractiveAlias $stage 'aext' 'Analyze-FileExtensions'
    Install-InteractiveAlias $stage 'c' 'Set-LocationUsingShortcut'
    Install-InteractiveAlias $stage 'ch' 'Compare-Hash'
    Install-InteractiveAlias $stage 'e' 'Open-FileInEditor'
    Install-InteractiveAlias $stage 'ec' 'Enter-Codebase'
    Install-InteractiveAlias $stage 'filever' 'Get-FileVersionInfo'
    Install-InteractiveAlias $stage 'gcr' 'Get-CoverageReport'
    Install-InteractiveAlias $stage 'gll' 'GitLog-Local'
    Install-InteractiveAlias $stage 'glp' 'GitLog-Pretty'
    Install-InteractiveAlias $stage 'gtfe' 'Get-TextFileEncoding'
    Install-InteractiveAlias $stage 'hex' 'Format-NumberAsHex'
    Install-InteractiveAlias $stage 'lsl' 'Get-LatestFiles'
    Install-InteractiveAlias $stage 'on' 'Invoke-InlineCommandOnHost'
    Install-InteractiveAlias $stage 'ow' 'Open-Workspace'
    Install-InteractiveAlias $stage 'pt' 'Push-UnitTestDirectory'
    Install-InteractiveAlias $stage 'rppr' 'Remove-PratPackageRecord'
    Install-InteractiveAlias $stage 'spfc' 'Save-PngFromClipboard'
    Install-InteractiveAlias $stage 'ude' 'Update-DevEnvironment'
    Install-InteractiveAlias $stage 'rs' 'Restart-Shell'
    $it.EndStage($stage)
}

main $Force
