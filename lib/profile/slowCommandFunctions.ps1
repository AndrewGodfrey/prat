function getLastCommandTime($historyInfo) {
    return ($historyInfo.EndExecutionTime - $historyInfo.StartExecutionTime).TotalSeconds
}

function displayLastCommandTime($duration) {
    if ($duration -le 3) { return }
    $s = Format-Duration $duration
    Write-Host $s -ForegroundColor Magenta
}

function reportOnSlowCommands($duration, $historyInfo, $lastCommandErrorStatus) {
    if ($duration -le 15) { return }
    & "$PSScriptRoot/../On-SlowCommand.ps1" $historyInfo $lastCommandErrorStatus
}


