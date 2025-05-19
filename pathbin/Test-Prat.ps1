param ([switch] $CodeCoverage)

Import-Module Pester
$Configuration = [PesterConfiguration]::Default
$Configuration.Run.Path = "."

if ($CodeCoverage) {
    $pratRoot = Resolve-Path "$PSScriptRoot\.."
    $Configuration.CodeCoverage.Enabled = [bool] $true
    $Configuration.CodeCoverage.OutputFormat = "CoverageGutters"
    $Configuration.CodeCoverage.Path = $Configuration.Run.Path
    $Configuration.CodeCoverage.OutputPath = "$pratRoot/auto/coverage.xml"
    $Configuration.CodeCoverage.CoveragePercentTarget = 70
}

Invoke-Pester -Configuration $Configuration