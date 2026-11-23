# .SYNOPSIS
# Parses a coverage XML file (CoverageGutters/JaCoCo or Cobertura format).
#
# Returns @{ totals; perFileReport; perFileMethodData; instructionUnit }:
#   totals            - @{ INSTRUCTION?; LINE; METHOD } aggregated across all files
#   perFileReport     - hashtable keyed by file path (base-relative when -PathBase applies,
#                        else absolute) → @{ INSTRUCTION?; LINE; METHOD }
#   perFileMethodData - hashtable keyed the same way → list of
#                       @{ name; startLine; lineNumbers?; INSTRUCTION?; LINE=@{missed;covered} }
#   instructionUnit   - "Instructions" for JaCoCo/CoverageGutters; $null for Cobertura
#
# INSTRUCTION is present only for JaCoCo/CoverageGutters. Cobertura has no instruction measure -
# LINE is its counter - so the INSTRUCTION key is omitted and instructionUnit is $null.
# METHOD is derived from per-method line coverage (a method is covered if it has ≥1 hit > 0).
# lineNumbers (per method) is present for Cobertura only, which lists each method's own lines.
#
# .PARAMETER CoverageFile
# Path to the coverage XML file. Auto-detects format from the root element.
#
# .PARAMETER PathBase
# The directory that relative paths in the coverage artifact are relative to, and that output
# keys are expressed relative to. Required for JaCoCo format (sourcefilenames are relative to
# it). For CoverageGutters and Cobertura, when supplied, a resulting key under PathBase is
# stripped to base-relative (forward slashes, no leading "./"); a key outside PathBase (or when
# PathBase is $null) stays absolute. A Cobertura filename that is already relative is used as-is
# regardless of PathBase - coverage.py writes those project-relative already.
#
# .PARAMETER ValidatePathBase
# Throw if a resolved path falls outside PathBase, instead of leaving it absolute.

param (
    $CoverageFile,
    $PathBase = $null,
    [switch] $ValidatePathBase
)

if (!(Test-Path $CoverageFile)) { throw "Coverage file not found: $CoverageFile" }

[xml]$xml = Get-Content $CoverageFile
$format = $xml.DocumentElement.LocalName
if ($format -ne 'report' -and $format -ne 'coverage') {
    throw "Invalid coverage file: $CoverageFile - unrecognized root element '$format'"
}

function newCounters([switch]$NoInstruction) {
    $c = @{ LINE = @{missed=0; covered=0}; METHOD = @{missed=0; covered=0} }
    if (-not $NoInstruction) { $c.INSTRUCTION = @{missed=0; covered=0} }
    $c
}

function addCounters($target, $counters) {
    foreach ($c in $counters) {
        if ($null -ne $target[$c.type]) {
            $target[$c.type].missed  += [int]$c.missed
            $target[$c.type].covered += [int]$c.covered
        }
    }
}

$normalizedPathBase = if ($PathBase) { ([string]$PathBase -replace '\\', '/').TrimEnd('/') } else { $null }

# Strips $normalizedPathBase from the front of an already forward-slashed absolute path, when the
# path is under it (case-insensitive - Windows paths differ in case between writers). A path
# outside the base, or when there is no base, is left as-is unless -ValidatePathBase is set.
function stripBase($absPath) {
    if (-not $normalizedPathBase) { return $absPath }
    $prefix = "$normalizedPathBase/"
    if ($absPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $absPath.Substring($prefix.Length)
    }
    if ($ValidatePathBase) {
        throw "Coverage file path '$absPath' is outside PathBase '$normalizedPathBase'"
    }
    return $absPath
}

function resolveFilePath($package, $class) {
    if (Split-Path -IsAbsolute $package.name) {
        # CoverageGutters: class.name is absolute path without extension; sourcefilename is leaf
        $path = Join-Path (Split-Path -Parent $class.name) $class.sourcefilename
    } else {
        # JaCoCo: sourcefilename is relative from PathBase
        $path = Join-Path $PathBase $class.sourcefilename
    }
    return stripBase ($path.Replace('\', '/'))
}

$totals        = newCounters -NoInstruction:$($format -ne 'report')
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
            # `covered` and `missed` are both true for a line JaCoCo counts instructions on both
            # sides of - a one-line `if (...) { ... }` whose body never ran, say.
            $perFileLineData[$absPath] = @(
                $sourcefile.line | ForEach-Object {
                    @{ nr = [int]$_.nr; covered = [int]$_.ci -gt 0; missed = [int]$_.mi -gt 0 }
                }
            )
        }
    }
} else {
    # Cobertura format. The <sources><source> element is not read: coverage.py already writes
    # every filename relative to the project root (fixPythonCoverage's single-source `--cov=.`),
    # so a relative filename is used as-is; an absolute filename (dotnet-coverage/coverlet style)
    # goes through stripBase like the other formats.

    function countCoberturaLines($lines) {
        $methodLines = @($lines | Where-Object { $_ })
        $lineCovered = ($methodLines | Where-Object { [int]$_.hits -gt 0 }).Count
        $lineMissed  = $methodLines.Count - $lineCovered
        $startLine = if ($methodLines.Count -gt 0) {
            [int]($methodLines | ForEach-Object { [int]$_.number } | Measure-Object -Minimum).Minimum
        } else { 0 }

        @{ lineCovered = $lineCovered; lineMissed = $lineMissed; startLine = $startLine
           lineNumbers = @($methodLines | ForEach-Object { [int]$_.number }) }
    }

    function addCoberturaMethodEntry($filePath, $name, $counts) {
        $methodCovered = if ($counts.lineCovered -gt 0) { 1 } else { 0 }
        $methodMissed  = 1 - $methodCovered

        $perFileReport[$filePath].LINE.covered   += $counts.lineCovered
        $perFileReport[$filePath].LINE.missed    += $counts.lineMissed
        $perFileReport[$filePath].METHOD.covered += $methodCovered
        $perFileReport[$filePath].METHOD.missed  += $methodMissed
        $totals.LINE.covered   += $counts.lineCovered
        $totals.LINE.missed    += $counts.lineMissed
        $totals.METHOD.covered += $methodCovered
        $totals.METHOD.missed  += $methodMissed

        [void]$perFileMethodData[$filePath].Add(@{
            name        = $name
            startLine   = $counts.startLine
            lineNumbers = $counts.lineNumbers
            LINE        = @{missed=$counts.lineMissed;  covered=$counts.lineCovered}
        })
    }

    foreach ($package in $xml.coverage.packages.package) {
        foreach ($class in $package.classes.class) {
            $filename = $class.filename -replace '\\', '/'
            $filePath = if ([System.IO.Path]::IsPathRooted($filename)) { stripBase $filename } else { $filename }

            if ($null -eq $perFileReport[$filePath]) {
                $perFileReport[$filePath]     = newCounters -NoInstruction
                $perFileMethodData[$filePath] = [System.Collections.ArrayList]@()
                $perFileLineData[$filePath]   = @()
            }

            foreach ($method in $class.methods.method) {
                addCoberturaMethodEntry $filePath $method.name (countCoberturaLines $method.lines.line)
            }

            if ($null -eq $class.methods.method) {
                # coverage.py's Cobertura output emits an empty <methods/> element for every class;
                # synthesize one pseudo-method from the class's own line data so it isn't dropped.
                $classLines = @($class.lines.line | Where-Object { $_ })
                if ($classLines.Count -gt 0) {
                    addCoberturaMethodEntry $filePath "(file)" (countCoberturaLines $classLines)
                }
            }

            # A hit line is partly covered when some of its branches went untaken.
            # A file can hold several classes (e.g. nested ones), so its line data accumulates.
            $perFileLineData[$filePath] += @(
                $class.lines.line | Where-Object { $_ } | ForEach-Object {
                    $hit = [int]$_.hits -gt 0
                    $untakenBranch = $_.branch -eq 'True' -and $_.'condition-coverage' -match '\((\d+)/(\d+)\)' -and
                        [int]$Matches[1] -lt [int]$Matches[2]
                    @{ nr = [int]$_.number; covered = $hit; missed = (-not $hit) -or $untakenBranch }
                }
            )
        }
    }

    foreach ($key in @($perFileLineData.Keys)) {
        $perFileLineData[$key] = @($perFileLineData[$key] | Sort-Object { $_.nr })
    }
}

@{
    totals            = $totals
    perFileReport     = $perFileReport
    perFileMethodData = $perFileMethodData
    perFileLineData   = $perFileLineData
    instructionUnit   = if ($format -eq 'report') { "Instructions" } else { $null }
}
