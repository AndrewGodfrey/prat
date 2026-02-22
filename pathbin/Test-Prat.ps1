# .SYNOPSIS
# Runs tests in Prat
param (
    [switch] $Coverage,
    [string] $TestFocus,
    [switch] $NoFocus)

$resolvedFocus = if ($NoFocus) { $null } elseif ($TestFocus) { $TestFocus } else { Get-TestFocus }
if ($null -eq $resolvedFocus) {
    # Note: Using 'current directory' - as in how most build tools work. 
    $pathToTest = "."
} else {
    $pathToTest = $resolvedFocus
}

Invoke-PesterWithCodeCoverage -Coverage:$Coverage -PathToTest $pathToTest -RepoRoot (Resolve-Path "$PSScriptRoot\..")
