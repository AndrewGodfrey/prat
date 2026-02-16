# .SYNOPSIS
# Runs Delete-OldFiles on each 'managed directory'

Start-Transcript -Path "$home\prat\auto\log\daily_cleanManagedDirectories.log" > $null

try {
    &$PSScriptRoot\..\profile\Add-PratBinPaths.ps1

    foreach ($md in &(Resolve-PratLibFile "lib/schtasks/Get-ManagedDirectories.ps1")) {
        &$home\prat\lib\Delete-OldFiles.ps1 $md.path $md.days
    }
} finally {
    Stop-Transcript > $null
}
