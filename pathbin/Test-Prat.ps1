# .SYNOPSIS
# Runs tests on Prat
param (
    [ValidateSet("None", "Standard", "Subset")] [string] $CoverageType = "None",
    [switch] $CodeCoverage)


$testFocus = Get-TestFocus
if ($null -eq $testFocus) {
    # Note: Using 'current directory' - as in how most build tools work. 
    $pathToTest = "." 
    if ($CodeCoverage) {
        # ... but code coverage (if enabled) will be calculated against the whole repo.
        # Which will give incomplete data, but lets you evaluate coverage of other parts of the repo.
        $CoverageType = "Standard"
    }
} else {
    $pathToTest = $testFocus
    if ($CodeCoverage) {
        $CoverageType = "Subset"
    }
}
Invoke-PesterWithCodeCoverage -CoverageType $CoverageType -PathToTest $pathToTest -RepoRoot (Resolve-Path "$PSScriptRoot\..")
