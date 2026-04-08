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
    $RepoRoot = $null,
    $OutputDir = $null,
    [switch] $UseAlternateCollector
)

if ($Focus -and [System.IO.Path]::IsPathRooted($Focus) -and -not $PSBoundParameters.ContainsKey('RepoRoot')) {
    $project = Get-PratProject -Location $Focus
    if ($project) { $PSBoundParameters['RepoRoot'] = $project.root }
}
&$PSScriptRoot\..\lib\Invoke-CodebaseCommand.ps1 "test" -CommandParameters:$PSBoundParameters
