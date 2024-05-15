# Installs Powershell profile, for both Powershell, and for Windows Powershell [the older version of Powershell that is included in Windows].
function Install-PsProfile($installationTracker) {
    $stage = $installationTracker.StartStage("profile.ps1")

    @('Powershell', 'WindowsPowerShell') | % {
        $targetDir = "$home\Documents\$_"
        if (!(Test-Path $targetDir)) {
            Write-Host "Create dir: $targetDir"
            New-Item -Type Directory $targetDir | Out-Null
        }
        $targetFile = "profile.ps1"

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
    $installationTracker.EndStage($stage)
}

