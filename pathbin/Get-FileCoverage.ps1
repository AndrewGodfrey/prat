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
    $CoverageFile = "$PSScriptRoot/../auto/testRuns/last/coverage.xml",
    [switch] $Detail,
    [string] $Function
)

$data = & "$PSScriptRoot/../lib/Get-CoverageData.ps1" -CoverageFile $CoverageFile

$resolved = Resolve-Path $FilePath -ErrorAction SilentlyContinue
$normalizedPath = ($resolved ? $resolved.Path : $FilePath).Replace('\', '/')
$methods = $data.perFileMethodData[$normalizedPath]
if ($null -eq $methods) { return @() }

if ($Function) { $methods = $methods | Where-Object { $_.name -eq $Function } }

if (-not $Detail) {
    $methods | ForEach-Object {
        [pscustomobject] @{
            Function = $_.name
            Line     = $_.startLine
            Covered  = $_.INSTRUCTION.covered
            Missed   = $_.INSTRUCTION.missed
        }
    }
    return
}

$lines = $data.perFileLineData[$normalizedPath]
if (-not $lines) { return @() }

$sortedMethods = @($methods | Sort-Object { $_.startLine })
for ($i = 0; $i -lt $sortedMethods.Count; $i++) {
    $method    = $sortedMethods[$i]
    $nextStart = if ($i + 1 -lt $sortedMethods.Count) { $sortedMethods[$i + 1].startLine } else { [int]::MaxValue }
    $methodLines = @($lines | Where-Object { $_.nr -ge $method.startLine -and $_.nr -lt $nextStart })
    if (-not $methodLines) { continue }

    $rangeStart = $null; $rangeEnd = $null; $rangeStatus = $null
    foreach ($line in $methodLines) {
        $status = if ($line.covered) { 'covered' } else { 'missed' }
        if ($null -eq $rangeStart) {
            $rangeStart = $line.nr; $rangeEnd = $line.nr; $rangeStatus = $status
        } elseif ($status -eq $rangeStatus) {
            $rangeEnd = $line.nr
        } else {
            [pscustomobject] @{ Function = $method.name; StartLine = $rangeStart; EndLine = $rangeEnd; Status = $rangeStatus }
            $rangeStart = $line.nr; $rangeEnd = $line.nr; $rangeStatus = $status
        }
    }
    if ($null -ne $rangeStart) {
        [pscustomobject] @{ Function = $method.name; StartLine = $rangeStart; EndLine = $rangeEnd; Status = $rangeStatus }
    }
}
