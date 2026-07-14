# .SYNOPSIS
# Runs Delete-OldFiles on each 'managed directory'

# Timestamped so each run keeps its own log (history), and so the active log is never old enough
# for the log dir's own retention rule to target it while the transcript holds it open.
Start-Transcript -Path "$home\prat\auto\log\daily_cleanManagedDirectories_$(Get-Date -Format 'yyyyMMdd_HHmmss').log" > $null

try {
    &$PSScriptRoot\..\profile\Set-PratBinPaths.ps1

    foreach ($md in &(Resolve-PratLibFile "lib/schtasks/Get-ManagedDirectories.ps1")) {
        &$home\prat\lib\Delete-OldFiles.ps1 $md.path $md.days
    }
} finally {
    Stop-Transcript > $null
}
