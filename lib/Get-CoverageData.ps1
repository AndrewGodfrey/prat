# .SYNOPSIS
# Parses a coverage XML file (CoverageGutters/JaCoCo or Cobertura format).
#
# Returns @{ totals; perFileReport; perFileMethodData }:
#   totals            - @{ INSTRUCTION; LINE; METHOD } aggregated across all files
#   perFileReport     - hashtable keyed by absolute file path → @{ INSTRUCTION; LINE; METHOD }
#   perFileMethodData - hashtable keyed by absolute file path → list of
#                       @{ name; startLine; INSTRUCTION=@{missed;covered}; LINE=@{missed;covered} }
#
# Cobertura: LINE is used as a proxy for INSTRUCTION; METHOD is derived from per-method line
# coverage (a method is covered if it has at least one hit > 0).
#
# .PARAMETER CoverageFile
# Path to the coverage XML file. Auto-detects format from the root element.
#
# .PARAMETER RepoRoot
# Repository root. Required for JaCoCo format (sourcefilenames are relative to it) and for
# Cobertura files with workspace-relative filenames and no <sources><source> element.
# Not needed for CoverageGutters or Cobertura files with absolute filenames.

param (
    $CoverageFile,
    $RepoRoot = $null,
    [switch] $ValidateRepoRoot
)

if (!(Test-Path $CoverageFile)) { throw "Coverage file not found: $CoverageFile" }

[xml]$xml = Get-Content $CoverageFile
$format = $xml.DocumentElement.LocalName
if ($format -ne 'report' -and $format -ne 'coverage') {
    throw "Invalid coverage file: $CoverageFile - unrecognized root element '$format'"
}

function newCounters { @{ INSTRUCTION = @{missed=0; covered=0}; LINE = @{missed=0; covered=0}; METHOD = @{missed=0; covered=0} } }

function addCounters($target, $counters) {
    foreach ($c in $counters) {
        if ($null -ne $target[$c.type]) {
            $target[$c.type].missed  += [int]$c.missed
            $target[$c.type].covered += [int]$c.covered
        }
    }
}

function resolveFilePath($package, $class) {
    if (Split-Path -IsAbsolute $package.name) {
        # CoverageGutters: class.name is absolute path without extension; sourcefilename is leaf
        $path = Join-Path (Split-Path -Parent $class.name) $class.sourcefilename
    } else {
        # JaCoCo: sourcefilename is relative from RepoRoot
        $path = Join-Path $RepoRoot $class.sourcefilename
    }
    $normalized = $path.Replace('\', '/')
    if ($ValidateRepoRoot -and $RepoRoot -and (Split-Path -IsAbsolute $package.name)) {
        $normalizedRoot = ([string]$RepoRoot).Replace('\', '/').TrimEnd('/')
        if (-not $normalized.StartsWith("$normalizedRoot/")) {
            throw "Coverage file path '$normalized' is outside RepoRoot '$normalizedRoot'"
        }
    }
    return $normalized
}

$totals        = newCounters
$perFileReport = @{}
$perFileMethodData = @{}
$perFileLineData   = @{}

if ($format -eq 'report') {
    foreach ($package in $xml.report.package) {
        # Build leaf→absolutePath map from class elements for use when resolving sourcefiles
        $leafToAbsPath = @{}
        foreach ($class in $package.class) {
            $leafToAbsPath[$class.sourcefilename] = resolveFilePath $package $class
        }

        foreach ($class in $package.class) {
            $filePath = resolveFilePath $package $class

            if ($null -eq $perFileReport[$filePath]) {
                $perFileReport[$filePath]     = newCounters
                $perFileMethodData[$filePath] = [System.Collections.ArrayList]@()
            }

            foreach ($method in $class.method) {
                $mc = newCounters
                addCounters $mc                      $method.counter
                addCounters $perFileReport[$filePath] $method.counter
                addCounters $totals                  $method.counter

                [void]$perFileMethodData[$filePath].Add(@{
                    name        = $method.name
                    startLine   = [int]$method.line
                    INSTRUCTION = @{missed=$mc.INSTRUCTION.missed; covered=$mc.INSTRUCTION.covered}
                    LINE        = @{missed=$mc.LINE.missed;        covered=$mc.LINE.covered}
                })
            }
        }

        foreach ($sourcefile in $package.sourcefile) {
            $absPath = $leafToAbsPath[$sourcefile.name]
            if ($null -eq $absPath) { continue }
            $perFileLineData[$absPath] = @(
                $sourcefile.line | ForEach-Object { @{ nr = [int]$_.nr; covered = [int]$_.ci -gt 0 } }
            )
        }
    }
} else {
    # Cobertura format
    # Determine source root: if <sources><source> is present and not '.', filenames are relative to it.
    $sourceNodes = $xml.SelectNodes("/coverage/sources/source")
    $sourceRoot = if ($sourceNodes.Count -eq 1 -and $sourceNodes[0].InnerText -ne '.') {
        ($sourceNodes[0].InnerText -replace '\\', '/').TrimEnd('/')
    } else { $null }

    $normalizedRepoRoot = if ($RepoRoot) { ($RepoRoot -replace '\\', '/').TrimEnd('/') } else { $null }

    foreach ($package in $xml.coverage.packages.package) {
        foreach ($class in $package.classes.class) {
            $filename = $class.filename -replace '\\', '/'
            $filePath = if ([System.IO.Path]::IsPathRooted($filename)) {
                $filename
            } elseif ($sourceRoot) {
                "$sourceRoot/$filename"
            } elseif ($normalizedRepoRoot) {
                "$normalizedRepoRoot/$filename"
            } else {
                $filename
            }

            if ($null -eq $perFileReport[$filePath]) {
                $perFileReport[$filePath]     = newCounters
                $perFileMethodData[$filePath] = [System.Collections.ArrayList]@()
            }

            foreach ($method in $class.methods.method) {
                $methodLines = @($method.lines.line | Where-Object { $_ })
                $covered  = ($methodLines | Where-Object { [int]$_.hits -gt 0 }).Count
                $missed   = $methodLines.Count - $covered
                $startLine = if ($methodLines.Count -gt 0) {
                    [int]($methodLines | ForEach-Object { [int]$_.number } | Measure-Object -Minimum).Minimum
                } else { 0 }

                $methodCovered = if ($covered -gt 0) { 1 } else { 0 }
                $methodMissed  = 1 - $methodCovered

                $perFileReport[$filePath].LINE.covered        += $covered
                $perFileReport[$filePath].LINE.missed         += $missed
                $perFileReport[$filePath].INSTRUCTION.covered += $covered
                $perFileReport[$filePath].INSTRUCTION.missed  += $missed
                $perFileReport[$filePath].METHOD.covered      += $methodCovered
                $perFileReport[$filePath].METHOD.missed       += $methodMissed
                $totals.LINE.covered        += $covered
                $totals.LINE.missed         += $missed
                $totals.INSTRUCTION.covered += $covered
                $totals.INSTRUCTION.missed  += $missed
                $totals.METHOD.covered      += $methodCovered
                $totals.METHOD.missed       += $methodMissed

                [void]$perFileMethodData[$filePath].Add(@{
                    name        = $method.name
                    startLine   = $startLine
                    INSTRUCTION = @{missed=$missed; covered=$covered}
                    LINE        = @{missed=$missed; covered=$covered}
                })
            }

            $perFileLineData[$filePath] = @(
                $class.lines.line | Where-Object { $_ } | ForEach-Object { @{ nr = [int]$_.number; covered = [int]$_.hits -gt 0 } }
            )
        }
    }
}

@{
    totals            = $totals
    perFileReport     = $perFileReport
    perFileMethodData = $perFileMethodData
    perFileLineData   = $perFileLineData
}
