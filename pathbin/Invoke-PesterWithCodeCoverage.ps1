# .SYNOPSIS
# Runs Pester with various code-coverage options
#
# .PARAMETER CoverageType
# None:      No code coverage (runs faster)
# Standard:  Produces CoverageGutter output. Coverage percentage is measured against the entire repo.
# Subset:    Like Standard, but coverage percentage is measured against the code under the current directory only.
param (
    [ValidateSet("None", "Standard", "Subset")] [string] $CoverageType = "Standard",
    $PathToTest = ".",
    $RepoRoot = (Resolve-Path "$PSScriptRoot\..")
)

Import-Module Pester
$Configuration = [PesterConfiguration]::Default
$Configuration.Run.Path = $PathToTest
if ($VerbosePreference -ne "SilentlyContinue") {
    # This is handy for pinpointing some unwanted output - e.g. an uncaught Write-Warning.
    $Configuration.Output.Verbosity = "Detailed"
}

if ($CoverageType -ne "None") {
    $Configuration.CodeCoverage.OutputPath = "$RepoRoot/auto/coverage.xml"
    $Configuration.CodeCoverage.Enabled = [bool] $true
    $Configuration.CodeCoverage.OutputFormat = "CoverageGutters"
    if ($CoverageType -eq "Subset") {
        $Configuration.CodeCoverage.Path = $Configuration.Run.Path
    } else {
        $Configuration.CodeCoverage.Path = $RepoRoot
    }
    $Configuration.CodeCoverage.CoveragePercentTarget = 70
}

Invoke-Pester -Configuration $Configuration
