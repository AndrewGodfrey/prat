# .SYNOPSIS
# Returns per-function instruction coverage for a single source file.
# Output is compact enough for an agent to act on directly.
#
# .PARAMETER FilePath
# Absolute path to the source file to query.
#
# .PARAMETER CoverageFile
# Path to the coverage XML file. Supports JaCoCo, CoverageGutters, and Cobertura formats.
# Defaults to <repo root>/auto/testRuns/<project leaf>/last/coverage.xml, inferred via
# Get-PratProject and Get-ProjectTestOutputDir.

param (
    [Parameter(Mandatory)] $FilePath,
    $CoverageFile = $null,
    [switch] $Detail,
    [string] $Function
)

$project = try { Get-PratProject -Location $FilePath } catch { $null }

if ($null -eq $CoverageFile) {
    if (-not $project) {
        throw "Cannot infer coverage file: $FilePath is not in a registered prat project. Pass -CoverageFile explicitly."
    }
    $CoverageFile = "$(Get-ProjectTestOutputDir $project)/last/coverage.xml"
}

# PathBase: the project root when $FilePath is registered (and the registration has a usable
# root - guards a sloppy mock, real registrations always have one), else the git root, else $null
# (both the query key and Get-CoverageDetails' keys then stay absolute).
$pathBase = if ($project -and $project.root) { $project.root } else { Resolve-GitRoot $FilePath }
$normalizedPathBase = if ($pathBase) { ([string]$pathBase -replace '\\', '/').TrimEnd('/') } else { $null }

$data = & "$PSScriptRoot/../lib/Get-CoverageDetails.ps1" -CoverageFile $CoverageFile -PathBase $pathBase
$unitName = $data.instructionUnit ?? "Instructions"

$resolved = Resolve-Path $FilePath -ErrorAction SilentlyContinue
$absolutePath = ($resolved ? $resolved.Path : $FilePath).Replace('\', '/')
$queryKey = if ($normalizedPathBase -and $absolutePath.StartsWith("$normalizedPathBase/", [System.StringComparison]::OrdinalIgnoreCase)) {
    $absolutePath.Substring($normalizedPathBase.Length + 1)
} else {
    $absolutePath
}

$methods = $data.perFileMethodData[$queryKey]
if ($null -eq $methods) {
    $baseDescription = if ($normalizedPathBase) { $normalizedPathBase } else { "<none>" }
    Write-Warning "No coverage data for key '$queryKey' (PathBase: $baseDescription) in '$CoverageFile'."
    return @()
}

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

$lines = $data.perFileLineData[$queryKey]
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
