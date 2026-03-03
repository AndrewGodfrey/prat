# .SYNOPSIS
# Event handler, called by function:prompt on startup, and whenever Get-Location changes
param($newLocation, $oldLocation)

# Write-Warning "Testing: On-PromptLocationChanged.ps1 was called. oldLocation=$oldLocation"

$project = &$PSScriptRoot\Get-PratProject $newLocation
if ($null -eq $project) {
    $global:__prat_currentLocation = $newLocation
} else {
    $id = $project.id
    $subdir = $project.subdir
    $buildKind = ""
    if ($null -ne $project.buildKind) {
        $buildKind = "(" + $project.buildKind + ")"
    }

    if ($subdir -ne "") { $subdir = " $subdir/" -replace '\\', '/' }
    $global:__prat_currentLocation = "[" + $id.ToLower() + "]$buildKind$subdir"
}

