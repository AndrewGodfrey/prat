# .SYNOPSIS
# Event handler, called by function:prompt on startup, and whenever Get-Location changes
param($newLocation, $oldLocation)

# Write-Warning "Testing: On-PromptLocationChanged.ps1 was called. oldLocation=$oldLocation"

$cbt = &$PSScriptRoot\Get-CodebaseSubTable $newLocation
if ($cbt -eq $null) {
    $global:__prat_currentLocation = $newLocation
} else {
    $id = $cbt.id
    $subdir = $cbt.subdir
    $buildKind = ""
    if ($cbt.buildKind -ne $null) {
        $buildKind = "(" + $cbt.buildKind + ")"
    }

    if ($subdir -ne "") { $subdir = " $subdir/" -replace '\\', '/' }
    $global:__prat_currentLocation = "[" + $id.ToLower() + "]$buildKind$subdir"
}

