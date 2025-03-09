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

function checkSubDirs($dir) {
    $candidate = Join-Path $dir "tests"
    if (Test-Path -PathType Container $candidate) { return $candidate }

    $candidate = Join-Path $dir "test"  # I prefer to use this name for test data, not tests. But some codebases use it for tests.
    if (Test-Path -PathType Container $candidate) { return $candidate }
    return $null
}


function findIt($CodeDir) {
    # First, see if there's codebase-specific logic
    $cbt = &$PSScriptRoot/../lib/Get-CodebaseTable $CodeDir
    if (($null -ne $cbt) -and ($null -ne $cbt.testDirFromDevDir)) {
        $candidate = &$cbt.testDirFromDevDir $CodeDir $cbt.root
        if ($null -ne $candidate) {
            # First check for 'test' subdirectories
            $candidate = checkSubDirs $candidate
            if ($null -ne $candidate) { return $candidate }

            # Otherwise, return whatever we were given, provided it exists.
            if (Test-Path -PathType Container $candidate) { return $candidate }
        }
    }

    # Otherwise, look nearby to the input code dir.
    return checkSubDirs $CodeDir
}

$result = findIt $CodeDir
if ($JustReturnIt) { return $result }

if ($null -eq $result) {
    Write-Host -ForegroundColor Yellow "Not found"
    return
}

Push-Location $result