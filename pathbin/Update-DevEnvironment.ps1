# .SYNOPSIS
# Does 'git pull' and 'deploy' on both prat and (if present) your custom dev environment.
# Uses Set-LocationUsingShortcut to find those things, specifically these shortcuts:
#   'de': your custom dev enviroment
#   'pr': prat

function say($msg) { Write-Host -ForegroundColor Green $msg }

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
        Deploy-Codebase
    } finally {
        Pop-Location
    }
}

updateEnvironment pr
updateEnvironment de -EnvironmentMayNotExist
