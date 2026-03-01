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

if (!$Focus) {
    # Note: Using 'current directory' - as in how most build tools work.
    $pathToTest = "."
} elseif ([System.IO.Path]::IsPathRooted($Focus)) {
    $pathToTest = $Focus
} else {
    $pathToTest = Join-Path $RepoRoot $Focus
}

Invoke-PesterWithCodeCoverage -NoCoverage:$NoCoverage -PathToTest $pathToTest -RepoRoot $RepoRoot -Debugging:$Debugging -OutputDir $OutputDir -IncludeIntegrationTests:$IncludeIntegrationTests
