function formatDuration([double] $durationInSeconds) {
    if ($durationInSeconds -lt 12) {
        return [String]::Format("{0:F1}s", $durationInSeconds)
    } elseif ($durationInSeconds -lt 60) {
        return [String]::Format("{0:F0}s", $durationInSeconds)
    } elseif ($durationInSeconds -lt 100) {
        return [String]::Format("{0:F0}m {1:F0}s", [Math]::Floor($durationInSeconds / 60), $durationInSeconds % 60)
    } elseif ($durationInSeconds -lt 720) {
        return [String]::Format("{0:F1}m", $durationInSeconds / 60)
    } elseif ($durationInSeconds -lt 3600) {
        return [String]::Format("{0:F0}m", [Math]::Round($durationInSeconds / 60))
    } else {
        return [String]::Format("{0:F1}h", $durationInSeconds / 3600)
    }
}
# Test: . .\lastCommandTime.ps1; @(0.03, 0.05, 1.53, 1.56, 10.3, 12.3, 59.3, 65, 100, (58*60 + 20), (58*60 + 40), 3900, 4200) | % { formatDuration $_ }

function getLastCommandTime($historyInfo) {
    return ($historyInfo.EndExecutionTime - $historyInfo.StartExecutionTime).TotalSeconds
}

function displayLastCommandTime($duration) {
    if ($duration -le 3) { return }
    $s = formatDuration $duration
    Write-Host $s -ForegroundColor Magenta
}

function reportOnSlowCommands($duration, $historyInfo, $lastCommandErrorStatus) {
    if ($duration -le 15) { return }
    MaybeReport-SlowCommand $historyInfo $lastCommandErrorStatus
}


