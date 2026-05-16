using module ..\PratBase\PratBase.psd1

# SYNOPSIS
#   Set Prat's binpaths in $env:Path — idempotent. Removes inherited real-path equivalents of
#   junction paths before adding them, so the junction-island version takes precedence.

function addJunctionPath($path) {
    $realTarget = Resolve-JunctionInPath $path
    $entries = @(($env:Path -split ';') | Where-Object { $_ -ne '' } | Where-Object {
        (Resolve-JunctionInPath $_) -ine $realTarget
    })
    $env:Path = ($entries + $path) -join ';'
}

function Set-PratBinPaths {
    if (Test-Path $home\prat\auto\profile\Get-OverrideBinPaths.ps1) {
        foreach ($p in ((&$home\prat\auto\profile\Get-OverrideBinPaths.ps1) -split ';' | Where-Object { $_ -ne '' })) {
            addJunctionPath $p
        }
    }
    addJunctionPath (Resolve-Path "$PSScriptRoot\..\..\pathbin").Path
    addJunctionPath "$home\prat\auto\pathbin"
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $global:__prat_binPathsSet) {
        Set-PratBinPaths
        $global:__prat_binPathsSet = $true
    }
}
