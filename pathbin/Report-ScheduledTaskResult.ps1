# .SYNOPSIS
# Reports the outcome of a scheduled task (success or failure).
# Writes to the current transcript/stdout (captured in the task's log), and records the latest result for
# Get-ScheduledTaskAlerts to surface at shell startup.
param(
    [string] $TaskName,
    [ValidateSet('Success', 'Failure')] [string] $Status,
    [string] $Message,
    [string] $ResultDir
)

$prefix = if ($Status -eq 'Failure') { '[FAILURE]' } else { '[SUCCESS]' }
Write-Host "$prefix $TaskName`: $Message"

. "$PSScriptRoot/../lib/schtasks/scheduledTaskResults.ps1"
$saveArgs = @{ TaskName = $TaskName; Status = $Status; Message = $Message }
if ($ResultDir) { $saveArgs.ResultDir = $ResultDir }
# A failure to record is logged here; if it persists, the stale-result alert surfaces it.
try { Save-ScheduledTaskResult @saveArgs } catch { Write-Host "[FAILURE] Couldn't record result for '$TaskName': $_" }
