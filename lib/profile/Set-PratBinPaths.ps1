# SYNOPSIS
#   Add Prat's binpaths to $env:Path if they have not been added already in this session.

function addPath($path) {
    # I find that some packages - like gsudo - leave $env:path with a trailing ';'. So I won't assume there isn't one.
    if (!$env:Path.EndsWith(";")) {
        $env:Path += ";"
    }
    $env:Path += $path
}

if (-not $global:__prat_binPathsSet) {
    if (Test-Path $home\prat\auto\profile\Get-OverrideBinPaths.ps1) {
        addPath (&$home\prat\auto\profile\Get-OverrideBinPaths.ps1)
    }
    addPath (Resolve-Path "$PSScriptRoot\..\..\pathbin").Path 
    addPath "$home\prat\auto\pathbin"
    $global:__prat_binPathsSet = $true
}

