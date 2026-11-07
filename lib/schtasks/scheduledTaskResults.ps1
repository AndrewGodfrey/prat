# Latest result of each scheduled task, recorded by pathbin/Report-ScheduledTaskResult.ps1 and surfaced at shell startup.

$script:defaultScheduledTaskResultDir = "$home\prat\auto\scheduledTaskResults"

function Save-ScheduledTaskResult {
    param(
        [Parameter(Mandatory)] [string] $TaskName,
        [Parameter(Mandatory)] [ValidateSet('Success', 'Failure')] [string] $Status,
        [string] $Message,
        [string] $ResultDir = $script:defaultScheduledTaskResultDir,
        [datetime] $Now = (Get-Date)
    )
    assertValidScheduledTaskName $TaskName
    $dir = (New-Item -ItemType Directory $ResultDir -Force -ErrorAction Stop).FullName
    @{ status = $Status; message = $Message; time = $Now.ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dir "$TaskName.json") -Encoding utf8 -ErrorAction Stop
}

# Returns whether there was a result to remove.
function Remove-ScheduledTaskResult {
    param(
        [Parameter(Mandatory)] [string] $TaskName,
        [string] $ResultDir = $script:defaultScheduledTaskResultDir
    )
    assertValidScheduledTaskName $TaskName
    $file = Join-Path $ResultDir "$TaskName.json"
    if (-not (Test-Path -LiteralPath $file)) { return $false }
    Remove-Item -LiteralPath $file -ErrorAction Stop
    return $true
}

# The name becomes a file name in the result dir, so it mustn't be able to point outside it.
function assertValidScheduledTaskName([string] $TaskName) {
    if (($TaskName -notmatch '^[\w .-]+$') -or ($TaskName -match '\.\.')) { throw "Invalid task name: '$TaskName'" }
}

# Called from the interactive profile, so it must be fast and must not throw for bad data.
function Get-ScheduledTaskAlerts {
    param(
        [string] $ResultDir = $script:defaultScheduledTaskResultDir,
        [datetime] $Now = (Get-Date),
        [timespan] $StaleAfter = [timespan]::FromDays(3)
    )
    if (-not (Test-Path -LiteralPath $ResultDir)) { return }

    $inv = [cultureinfo]::InvariantCulture
    foreach ($file in Get-ChildItem -LiteralPath $ResultDir -Filter '*.json' | Sort-Object Name) {
        $name = $file.BaseName
        try {
            $result = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
            $time = [datetime] $result.time
        } catch {
            "'$name' has an unreadable result file"
            continue
        }

        if ($result.status -eq 'Failure') {
            $line = "$($result.message)" -split "`r?`n" | Select-Object -First 1
            if ($line.Length -gt 120) { $line = $line.Substring(0, 117) + '...' }
            "'$name' failed $($time.ToString('MM/dd HH:mm', $inv)): $line"
        } elseif (($Now - $time) -gt $StaleAfter) {
            "'$name' hasn't reported since $($time.ToString('MM/dd HH:mm', $inv))"
        }
    }
}
# Called from the interactive profile.
function Write-ScheduledTaskAlerts {
    param(
        [string] $ResultDir = $script:defaultScheduledTaskResultDir,
        [datetime] $Now = (Get-Date)
    )
    $alerts = @(Get-ScheduledTaskAlerts -ResultDir $ResultDir -Now $Now)
    if ($alerts.Count -eq 0) { return }

    Write-Host -ForegroundColor Yellow "Scheduled task alerts (details in each task's own log):"
    foreach ($alert in $alerts) { Write-Host -ForegroundColor Yellow "  $alert" }
    Write-Host -ForegroundColor Yellow "Each clears when its task next succeeds. To dismiss one sooner, delete '<task>.json' in $ResultDir"
}

# Runs a scheduled task's body and records its outcome. A throw counts as failure; it's recorded, then rethrown
# so the task still exits with an error. Non-terminating errors don't count.
function Invoke-ReportedScheduledTask {
    param(
        [Parameter(Mandatory)] [string] $TaskName,
        [Parameter(Mandatory)] [scriptblock] $ScriptBlock,
        [string] $ResultDir = $script:defaultScheduledTaskResultDir
    )
    $report = "$PSScriptRoot/../../pathbin/Report-ScheduledTaskResult.ps1"
    try {
        & $ScriptBlock
    } catch {
        & $report -TaskName $TaskName -Status Failure -Message "$_" -ResultDir $ResultDir
        throw
    }
    & $report -TaskName $TaskName -Status Success -Message 'Completed' -ResultDir $ResultDir
}
