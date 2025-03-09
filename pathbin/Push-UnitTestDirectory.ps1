# .SYNOPSIS
# Finds the unit test directory for a given code directory.
#
# Some codebases keep unit tests in the same place as the corresponding code.
# Others put a varying distance away.
#
# (For my own code, I prefer using the same directory, if the tooling allows it. But e.g. prat\pathbin has a 'tests' subdirectory because
# tests shouldn't be in $env:Path).
#
# Individual codebases can hook into this by defining 'testDirFromDevDir' in their codebase table.
#
# Alias: pt
#
# .PARAMETER JustReturnIt
# Just returns the result. By default, will Push-Location to the directory.

param ($CodeDir = $pwd, [switch] $JustReturnIt)

function findIt($CodeDir) {
    $candidate = Join-Path $CodeDir "tests"
    if (Test-Path -PathType Container $candidate) { return $candidate }
    $candidate = Join-Path $CodeDir "test"
    if (Test-Path -PathType Container $candidate) { return $candidate }
    return $null
}

$result = findIt $CodeDir
if ($JustReturnIt) { return $result }

if ($null -eq $result) {
    Write-Host -ForegroundColor Yellow "Not found"
    return
}

Push-Location $result