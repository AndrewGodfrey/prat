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
    [string] $Focus,
    [switch] $NoCoverage,
    [switch] $Debugging,
    [switch] $IncludeIntegrationTests,
    $RepoRoot = $null,
    $OutputDir = $null
)

if (-not $PSBoundParameters.ContainsKey('Focus') -and $PSBoundParameters.ContainsKey('RepoRoot')) {
    $PSBoundParameters['Focus'] = $RepoRoot
}
&$PSScriptRoot\..\lib\Invoke-ProjectCommand.ps1 "test" -CommandParameters:$PSBoundParameters
