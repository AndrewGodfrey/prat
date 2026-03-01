# .SYNOPSIS
# Runs tests in Prat
[CmdletBinding()]
param (
    [string] $Focus=$null,
    [switch] $NoCoverage,
    [switch] $Debugging,
    [switch] $IncludeIntegrationTests,
    $RepoRoot = (Resolve-Path "$PSScriptRoot\.."),
    $OutputDir = $null
)

$pathToTest = &$PSScriptRoot\..\lib\Resolve-TestFocus $Focus $RepoRoot

Invoke-PesterWithCodeCoverage -NoCoverage:$NoCoverage -PathToTest $pathToTest -RepoRoot $RepoRoot -Debugging:$Debugging -OutputDir $OutputDir -IncludeIntegrationTests:$IncludeIntegrationTests
