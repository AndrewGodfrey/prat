# .SYNOPSIS
# Returns per-function instruction coverage for a single source file.
# Output is compact enough for an agent to act on directly.
#
# .PARAMETER FilePath
# Absolute path to the source file to query.
#
# .PARAMETER CoverageFile
# Path to the coverage XML file. Supports JaCoCo, CoverageGutters, and Cobertura formats.
# Defaults to <git repo root>/auto/testRuns/[<subproject>/]last/coverage.xml, inferred via
# Get-PratProject and Resolve-GitRoot.

param (
    [Parameter(Mandatory)] $FilePath,
    $CoverageFile = $null,
    [switch] $Detail,
    [string] $Function
)

if ($null -eq $CoverageFile) {
    $repoRoot = Resolve-GitRoot $FilePath
    if (-not $repoRoot) { throw "Cannot infer coverage file: not in a git repo." }
    $project  = try { Get-PratProject -Location $FilePath } catch { $null }
    $isNested = $project -and (
        $project.ContainsKey('parentId') -or
        ($project.root -replace '\\', '/') -ine $repoRoot
    )
    $subDir = if ($isNested) { "$($project.id)/" } else { '' }
    $CoverageFile = "$repoRoot/auto/testRuns/$($subDir)last/coverage.xml"
}

$data = & "$PSScriptRoot/../lib/Get-CoverageData.ps1" -CoverageFile $CoverageFile
$unitName = $data.instructionUnit ?? "Instructions"

$resolved = Resolve-Path $FilePath -ErrorAction SilentlyContinue
$normalizedPath = ($resolved ? $resolved.Path : $FilePath).Replace('\', '/')
$methods = $data.perFileMethodData[$normalizedPath]
if ($null -eq $methods) { return @() }

if ($Function) { $methods = $methods | Where-Object { $_.name -eq $Function } }

if (-not $Detail) {
    $methods | ForEach-Object {
        [pscustomobject] @{
            Function  = $_.name
            Line      = $_.startLine
            $unitName = $_.INSTRUCTION.covered
            Missed    = $_.INSTRUCTION.missed
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
