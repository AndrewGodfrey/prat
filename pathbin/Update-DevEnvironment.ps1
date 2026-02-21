# .SYNOPSIS
# Does 'git pull' and 'deploy' on prat - plus, if present, your custom dev environment.
#
# Alias: ude
#
# .NOTES
# Uses Set-LocationUsingShortcut to find those things, specifically these shortcuts:
#   'de': your custom dev enviroment
#   'prat': prat

function say($msg) { Write-Host -ForegroundColor Green $msg }

function Invoke-DeployCodebase($location) {
    pwsh -NoLogo -Command "Set-Location '$location'; Deploy-Codebase"
}

function updateEnvironment($environmentShortcut, [switch] $EnvironmentMayNotExist = $false) {
    Push-Location
    try {
        try {
            Set-LocationUsingShortcut $environmentShortcut
        } catch {
            if ($EnvironmentMayNotExist) { return }
            throw
        }
        say "$($environmentShortcut): pull: $(Get-Location)"
        git pull --ff-only
        say "$($environmentShortcut): deploy"
        # Run this in a separate pwsh, for the case when modules have been updated
        Invoke-DeployCodebase $PWD
    } finally {
        Pop-Location
    }
}

updateEnvironment prat
updateEnvironment de -EnvironmentMayNotExist
