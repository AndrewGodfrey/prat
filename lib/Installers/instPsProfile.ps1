# Installs Powershell profile. Assumes Windows PowerShell (not PS core).
function Install-PsProfile($installationTracker) {
    $stage = $installationTracker.StartStage("profile.ps1")

    # Save a copy of the 'original' file we found before Prat first ran.
    $targetDir = "$home\Documents\WindowsPowerShell"
    $targetFile = "profile.ps1"
    $backupFile = "$targetDir\profile.original.prat.ps1"
    
    if (!(Test-Path $backupFile)) {
        if (Test-Path "$targetDir\$targetFile") {
            copy $targetDir\$targetFile -Destination $backupFile
        } else {
            Set-Content $backupFile "# Install-PsProfile found no profile.ps1"
        }
    }

    Install-File $stage $PSScriptRoot $targetDir "installedProfile.ps1" $targetFile
    $installationTracker.EndStage($stage)
}

