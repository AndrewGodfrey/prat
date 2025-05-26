# .SYNOPSIS
# Runs tests on Prat
param (
    [ValidateSet("None", "Standard", "Subset")] [string] $CoverageType = "None",
    [switch] $CodeCoverage)

if ($CodeCoverage) {
    $CoverageType = "Standard"
}
Invoke-PesterWithCodeCoverage -CoverageType $CoverageType -PathToTest "." -RepoRoot (Resolve-Path "$PSScriptRoot\..")
