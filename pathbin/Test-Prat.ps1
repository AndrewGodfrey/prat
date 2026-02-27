# .SYNOPSIS
# Runs tests in Prat
[CmdletBinding(DefaultParameterSetName="Unfocused")]
param (
    [Parameter(ParameterSetName="Focused")]
    [string] $Focus,
    [Parameter(ParameterSetName="Unfocused")]
    [switch] $NoFocus,
    [switch] $NoCoverage,
    [switch] $Debugging,
    [switch] $IncludeIntegrationTests,
    $RepoRoot = (Resolve-Path "$PSScriptRoot\.."),
    $OutputDir = $null
)

$resolvedFocus = if ($NoFocus) { $null } elseif ($Focus) { $Focus } else { Get-TestFocus }
if ($null -eq $resolvedFocus) {
    # Note: Using 'current directory' - as in how most build tools work.
    $pathToTest = "."
} else {
    $pathToTest = $resolvedFocus
}

Invoke-PesterWithCodeCoverage -NoCoverage:$NoCoverage -PathToTest $pathToTest -RepoRoot $RepoRoot -Debugging:$Debugging -OutputDir $OutputDir -IncludeIntegrationTests:$IncludeIntegrationTests
