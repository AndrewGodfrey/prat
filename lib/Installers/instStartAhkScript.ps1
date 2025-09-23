# Launch an AutoHotKey script if not already running
function Install-StartAutoHotKeyScript($stage, [string] $scriptFile) {
    $stage.SetSubstage("Install-StartAutoHotKeyScript($scriptFile)")

    if (-not (Test-Path $scriptFile)) { throw "Script file not found: $scriptFile" }

    $runningInstances = Get-PsCommandLine.ps1 AutoHotkey64.exe
    if ($runningInstances.Count -gt 0) {
        $runningInstances = $runningInstances | ? {$_.CommandLine.Contains($scriptFile)}
    }
    if ($runningInstances.Count -eq 0) {
        if (Get-CurrentUserIsElevated) {
            Write-Warning "User is elevated; can't launch AutoHotKey script"
        } else {
            $stage.OnChange()
            &$scriptFile
        }
    }
}

