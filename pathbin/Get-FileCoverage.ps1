# .SYNOPSIS
# Returns per-function instruction coverage for a single source file.
# Output is compact enough for an agent to act on directly.
#
# .PARAMETER FilePath
# Absolute path to the source file to query.
#
# .PARAMETER CoverageFile
# Path to the coverage XML file. Supports both JaCoCo and Coverage Gutters formats.

param (
    [Parameter(Mandatory)] $FilePath,
    $CoverageFile = "$PSScriptRoot/../auto/coverage.xml"
)

$data = & "$PSScriptRoot/../lib/Get-CoverageData.ps1" -CoverageFile $CoverageFile

$resolved = Resolve-Path $FilePath -ErrorAction SilentlyContinue
$normalizedPath = ($resolved ? $resolved.Path : $FilePath).Replace('\', '/')
$methods = $data.perFileMethodData[$normalizedPath]
if ($null -eq $methods) { return @() }

$methods | ForEach-Object {
    [pscustomobject] @{
        Function = $_.name
        Line     = $_.startLine
        Covered  = $_.INSTRUCTION.covered
        Missed   = $_.INSTRUCTION.missed
    }
}
