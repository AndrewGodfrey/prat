# Installs Powershell profile, for both Powershell, and for Windows Powershell [the older version of Powershell that is included in Windows].
function installOne($targetDir, $targetFile) {
    if (!(Test-Path $targetDir)) {
        Write-Host "Create dir: $targetDir"
        New-Item -Type Directory $targetDir | Out-Null
    }

    # Save a copy of the 'original' file we found before Prat first ran.
    $backupFile = "$targetDir\profile.original.prat.ps1"
    
    if (!(Test-Path $backupFile)) {
        if (Test-Path "$targetDir\$targetFile") {
            copy $targetDir\$targetFile -Destination $backupFile
        } else {
            Set-Content $backupFile "# Install-PsProfile found no profile.ps1"
        }
    }

    Install-File $stage $PSScriptRoot $targetDir "installedProfile.ps1" $targetFile
}

function Install-PsProfile($installationTracker) {
    $stage = $installationTracker.StartStage("profile.ps1")

    # OneDrive may have moved the profile, sigh.
    $targetDir = Split-Path -Parent $profile.CurrentUserAllHosts
    $targetFile = Split-Path -Leaf $profile.CurrentUserAllHosts
    installOne $targetDir $targetFile

    # We'll just guess that the WindowsPowerShell profile is nearby, and has a default name.
    installOne "$targetDir\..\WindowsPowerShell" "profile.ps1"

    $installationTracker.EndStage($stage)
}

