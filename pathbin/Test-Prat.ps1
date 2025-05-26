# .SYNOPSIS
# Runs tests on Prat
#
# .PARAMETER CodeCoverage
# Enables code coverage measurement
#
# .PARAMETER SubdirCodeCoverage
# A slight tweak on -CodeCoverage - enables measurement and reports
# coverage percentage just relative to the code in the current directory (instead of all of Prat)
param ([switch] $CodeCoverage, [switch] $SubdirCodeCoverage)

Import-Module Pester
$Configuration = [PesterConfiguration]::Default
$Configuration.Run.Path = "."

if ($SubdirCodeCoverage) { $CodeCoverage = $true }

if ($CodeCoverage) {
    $pratRoot = Resolve-Path "$PSScriptRoot\.."
    $Configuration.CodeCoverage.Enabled = [bool] $true
    $Configuration.CodeCoverage.OutputFormat = "CoverageGutters"
    if ($SubdirCodeCoverage) {
        $Configuration.CodeCoverage.Path = $Configuration.Run.Path
    } else {
        $Configuration.CodeCoverage.Path = $pratRoot
    }
    $Configuration.CodeCoverage.OutputPath = "$pratRoot/auto/coverage.xml"
    $Configuration.CodeCoverage.CoveragePercentTarget = 70
}

Invoke-Pester -Configuration $Configuration
