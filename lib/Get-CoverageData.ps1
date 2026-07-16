# .SYNOPSIS
# Parses a coverage XML file (CoverageGutters/JaCoCo or Cobertura format).
#
# Returns @{ totals; perFileReport; perFileMethodData; instructionUnit }:
#   totals            - @{ INSTRUCTION; LINE; METHOD } aggregated across all files
#   perFileReport     - hashtable keyed by absolute file path → @{ INSTRUCTION; LINE; METHOD }
#   perFileMethodData - hashtable keyed by absolute file path → list of
#                       @{ name; startLine; INSTRUCTION=@{missed;covered}; LINE=@{missed;covered} }
#   instructionUnit   - "Instructions" for JaCoCo/CoverageGutters; "Branches" for Cobertura
#
# Cobertura: INSTRUCTION uses branch condition-coverage as a proxy (counting branch outcomes
# rather than instructions); for non-branching lines, 1 covered/missed per line as before.
# METHOD is derived from per-method line coverage (a method is covered if it has ≥1 hit > 0).
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
    # Determine source roots: <sources><source> entries (other than '.') that relative filenames
    # resolve against. coverage.py stores every filename relative to the first root; a class only
    # needs a later root when the first root's copy of that relative path doesn't exist on disk.
    $sourceRoots = @(
        $xml.SelectNodes("/coverage/sources/source") |
            ForEach-Object { ($_.InnerText -replace '\\', '/').TrimEnd('/') } |
            Where-Object { $_ -and $_ -ne '.' }
    )

    $normalizedRepoRoot = if ($RepoRoot) { ($RepoRoot -replace '\\', '/').TrimEnd('/') } else { $null }

    function resolveCoberturaFilePath($filename) {
        if ([System.IO.Path]::IsPathRooted($filename)) { return $filename }
        if ($sourceRoots.Count -gt 0) {
            foreach ($root in $sourceRoots) {
                $candidate = "$root/$filename"
                if (Test-Path -LiteralPath $candidate) { return $candidate }
            }
            return "$($sourceRoots[0])/$filename"
        }
        if ($normalizedRepoRoot) { return "$normalizedRepoRoot/$filename" }
        return $filename
    }

    function countCoberturaLines($lines) {
        $methodLines = @($lines | Where-Object { $_ })
        $lineCovered = ($methodLines | Where-Object { [int]$_.hits -gt 0 }).Count
        $lineMissed  = $methodLines.Count - $lineCovered
        $startLine = if ($methodLines.Count -gt 0) {
            [int]($methodLines | ForEach-Object { [int]$_.number } | Measure-Object -Minimum).Minimum
        } else { 0 }

        $instrCovered = 0; $instrMissed = 0
        foreach ($line in $methodLines) {
            if ($line.branch -eq 'True' -and $line.'condition-coverage' -match '\((\d+)/(\d+)\)') {
                $instrCovered += [int]$Matches[1]
                $instrMissed  += [int]$Matches[2] - [int]$Matches[1]
            } else {
                if ([int]$line.hits -gt 0) { $instrCovered++ } else { $instrMissed++ }
            }
        }

        @{ lineCovered = $lineCovered; lineMissed = $lineMissed; startLine = $startLine
           instrCovered = $instrCovered; instrMissed = $instrMissed }
    }

    function addCoberturaMethodEntry($filePath, $name, $counts) {
        $methodCovered = if ($counts.lineCovered -gt 0) { 1 } else { 0 }
        $methodMissed  = 1 - $methodCovered

        $perFileReport[$filePath].LINE.covered        += $counts.lineCovered
        $perFileReport[$filePath].LINE.missed         += $counts.lineMissed
        $perFileReport[$filePath].INSTRUCTION.covered += $counts.instrCovered
        $perFileReport[$filePath].INSTRUCTION.missed  += $counts.instrMissed
        $perFileReport[$filePath].METHOD.covered      += $methodCovered
        $perFileReport[$filePath].METHOD.missed       += $methodMissed
        $totals.LINE.covered        += $counts.lineCovered
        $totals.LINE.missed         += $counts.lineMissed
        $totals.INSTRUCTION.covered += $counts.instrCovered
        $totals.INSTRUCTION.missed  += $counts.instrMissed
        $totals.METHOD.covered      += $methodCovered
        $totals.METHOD.missed       += $methodMissed

        [void]$perFileMethodData[$filePath].Add(@{
            name        = $name
            startLine   = $counts.startLine
            INSTRUCTION = @{missed=$counts.instrMissed; covered=$counts.instrCovered}
            LINE        = @{missed=$counts.lineMissed;  covered=$counts.lineCovered}
        })
    }

    foreach ($package in $xml.coverage.packages.package) {
        foreach ($class in $package.classes.class) {
            $filename = $class.filename -replace '\\', '/'
            $filePath = resolveCoberturaFilePath $filename

            if ($null -eq $perFileReport[$filePath]) {
                $perFileReport[$filePath]     = newCounters
                $perFileMethodData[$filePath] = [System.Collections.ArrayList]@()
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
    instructionUnit   = if ($format -eq 'report') { "Instructions" } else { "Branches" }
}
