using module ..\..\TextFileEditor\TextFileEditor.psd1
using module ..\..\Installers\Installers.psd1

param($project, [hashtable]$CommandParameters = @{})

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
}

function instSchTasks($it) {
    $stage = $it.StartStage('schTasks')

    Install-DailyScheduledTask $stage "test" "Prat - test task" $PSScriptRoot\..\..\schtasks\daily_test.ps1 "1:08AM"
    Install-DailyScheduledTask $stage "cleanManagedDirectories" "Prat - Clean managed directories"  $PSScriptRoot\..\..\schtasks\daily_cleanManagedDirectories.ps1 "1:30AM"
    $onLogonScripts = & (Resolve-PratLibFile "lib/schtasks/Get-OnLogonScripts.ps1")
    if ($onLogonScripts.Count -gt 0) {
        Install-AtLogonScheduledTask $stage "onLogonScripts" "Prat - invoke on-logon scripts" $PSScriptRoot\..\..\schtasks\onLogon_Invoke-OnLogonScripts.ps1
    }

    $it.EndStage($stage)
}

function instInteractiveAliases($it) {
    # If any of these aliases prove objectionable, they can be made opt-in using pratPackages.
    # For an example see the package "df", which aliases to Get-DiskFreeSpace.
    
    $stage = $it.StartStage("interactive aliases")
    Install-InteractiveAlias $stage 'pb' 'Prebuild-Codebase'
    Install-InteractiveAlias $stage 'b' 'Build-Codebase'
    Install-InteractiveAlias $stage 't' 'Test-Project'
    Install-InteractiveAlias $stage 'd' 'Deploy-Codebase'
    Install-InteractiveAlias $stage 'x' 'Start-CodebaseDevLoop'
    Install-InteractiveAlias $stage 'c' 'Set-LocationUsingShortcut'
    Install-InteractiveAlias $stage 'ow' 'Open-ProjectWorkspace'
    Install-InteractiveAlias $stage 'gtfe' 'Get-TextFileEncoding'
    Install-InteractiveAlias $stage 'gll' 'GitLog-Local'
    Install-InteractiveAlias $stage 'glp' 'GitLog-Pretty'
    Install-InteractiveAlias $stage 'e' 'Open-FileInEditor'
    Install-InteractiveAlias $stage 'lsl' 'Get-LatestFiles'
    Install-InteractiveAlias $stage 'ude' 'Update-DevEnvironment'
    Install-InteractiveAlias $stage 'ch' 'Compare-Hash'
    Install-InteractiveAlias $stage 'aext' 'Analyze-FileExtensions'
    Install-InteractiveAlias $stage 'filever' 'Get-FileVersionInfo'
    Install-InteractiveAlias $stage 'hex' 'Format-NumberAsHex'
    Install-InteractiveAlias $stage 'ec' 'Enter-Codebase'
    Install-InteractiveAlias $stage 'pt' 'Push-UnitTestDirectory'
    Install-InteractiveAlias $stage 'on' 'Invoke-InlineCommandOnHost'
    Install-InteractiveAlias $stage 'gcr' 'Get-CoverageReport'
    $it.EndStage($stage)
}

main $CommandParameters['Force']