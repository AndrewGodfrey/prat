# .SYNOPSIS
# Does 'git pull' and 'deploy' on all codebase layers (prat, plus any layered environments present).
# Fails if any layer is not on the 'main' branch.
#
# Alias: ude

function Invoke-DeployCodebase($location) {
    pwsh -NoLogo -Command "Set-Location '$location'; Deploy-Codebase"
}

$layers = @(Get-CodebaseLayers)

Push-Location
try {
    foreach ($layer in $layers) {
        Set-Location $layer.Path
        $branch = git rev-parse --abbrev-ref HEAD
        if ($branch -ne 'main') {
            throw "$($layer.Name): not on main (on '$branch') — switch to main before running ude"
        }
    }

    foreach ($layer in $layers) {
        Write-Host -ForegroundColor Green "$($layer.Name): pull: $($layer.Path)"
        Set-Location $layer.Path
        git pull origin main --ff-only -q
    }

    Write-Host -ForegroundColor Green "$($layers[0].Name): deploy"
    Invoke-DeployCodebase $layers[0].Path
} finally {
    Pop-Location
}
