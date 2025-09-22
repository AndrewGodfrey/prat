# .SYNOPSIS
# Steps that need to be run every time I log in (because they launch a program that I want running).
# Steps that throw do not prevent later steps from running.
#
# .NOTES
# If the overridable script Get-OnLogonScripts.ps1 returns an empty list,
# Deploy-Prat.ps1 won't install a scheduled task for this at all. But the empty case is still supported in case it was already installed from
# a previous non-empty state.

$logFolder = "$home\prat\auto\log"
if (-not (Test-Path $logFolder)) { md $logFolder >$null}
$logFolder = "$logFolder\onLogon_Invoke-OnLogonScripts"
if (-not (Test-Path $logFolder)) { md $logFolder >$null}

Start-Transcript -OutputDirectory $logFolder > $null

$onLogonScripts = & (Resolve-PratLibFile "lib/schtasks/Get-OnLogonScripts.ps1")

foreach ($onLogonScript in $onLogonScripts) {
    $scriptDescription = $onLogonScript.description
    try {
        echo "Starting: $scriptDescription"
        &$onLogonScript.script
    } catch {
        echo "Failed: $scriptDescription"
    }
}

echo "Completed"
Stop-Transcript > $null
