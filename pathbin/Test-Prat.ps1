# .SYNOPSIS
# Runs tests on Prat
param (
    [ValidateSet("None", "Standard", "Subset")] [string] $CoverageType = "None",
    [switch] $CodeCoverage)


$testFocus = Get-TestFocus
if ($null -eq $testFocus) {
    if ($CodeCoverage) {
        $CoverageType = "Standard"
    }
    $pathToTest = "."
} else {
    $pathToTest = $testFocus
    if ($CodeCoverage) {
        $CoverageType = "Subset"
    }
}
Invoke-PesterWithCodeCoverage -CoverageType $CoverageType -PathToTest $pathToTest -RepoRoot (Resolve-Path "$PSScriptRoot\..")
