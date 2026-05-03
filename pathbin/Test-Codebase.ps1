# .SYNOPSIS
# Tests a codebase
# (i.e. Runs unit tests)
#
# Recommended alias: t
#
# .NOTES
# What this does, depends on the codebase. It might do nothing.
# The purpose of this is to provide a consistent dev inner loop. I alias 't' to run this directly, or 'x' to run it as part of a larger loop.

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string] $Focus,
    [switch] $NoCoverage,
    [switch] $NoBuild,
    [switch] $IncludeIntegrationTests,
    [switch] $Integration,
    $OutputDir = $null,
    [switch] $UseAlternateCollector
)

if ($Focus) { $Focus = Expand-TildePath $Focus }
if ($Focus -and [System.IO.Path]::IsPathRooted($Focus)) {
    $project = Get-PratProject -Location $Focus
    if ($project) { $PSBoundParameters['RepoRoot'] = $project.root }
    else { Write-Warning "No registered project found for path '$Focus'" }
}
&$PSScriptRoot\..\lib\Invoke-CodebaseCommand.ps1 "test" -CommandParameters:$PSBoundParameters
