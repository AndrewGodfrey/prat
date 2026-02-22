# .SYNOPSIS
# Runs tests on Prat
param (
    [ValidateSet("None", "Standard", "Subset")] [string] $CoverageType = "None",
    [switch] $CodeCoverage,
    [string] $TestFocus)


$resolvedFocus = if ($TestFocus) { $TestFocus } else { Get-TestFocus }
if ($null -eq $resolvedFocus) {
    # Note: Using 'current directory' - as in how most build tools work. 
    $pathToTest = "."
    if ($CodeCoverage) {
        # ... but code coverage (if enabled) will be calculated against the whole repo.
        # Which will give incomplete data, but lets you evaluate coverage of other parts of the repo.
        $CoverageType = "Standard"
    }
} else {
    $pathToTest = $resolvedFocus
    if ($CodeCoverage) {
        $CoverageType = "Subset"
    }
}
Invoke-PesterWithCodeCoverage -CoverageType $CoverageType -PathToTest $pathToTest -RepoRoot (Resolve-Path "$PSScriptRoot\..")
