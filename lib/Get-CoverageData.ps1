# .SYNOPSIS
# Parses a Pester code coverage XML file (CoverageGutters or JaCoCo format).
#
# Returns @{ totals; perFileReport; perFileMethodData }:
#   totals            - @{ INSTRUCTION; LINE; METHOD } aggregated across all files
#   perFileReport     - hashtable keyed by absolute file path → @{ INSTRUCTION; LINE; METHOD }
#   perFileMethodData - hashtable keyed by absolute file path → list of
#                       @{ name; startLine; INSTRUCTION=@{missed;covered}; LINE=@{missed;covered} }
#
# .PARAMETER CoverageFile
# Path to the coverage XML file.
#
# .PARAMETER RepoRoot
# Repository root. Required for JaCoCo format, where sourcefilenames are relative to it.
# Not needed for CoverageGutters format (paths are absolute in the XML).

param (
    $CoverageFile,
    $RepoRoot = $null
)

if (!(Test-Path $CoverageFile)) { throw "Coverage file not found: $CoverageFile" }

[xml]$xml = Get-Content $CoverageFile
if ($null -eq $xml.report) { throw "Invalid coverage file: $CoverageFile - missing <report> element" }

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
    return $path.Replace('\', '/')
}

$totals        = newCounters
$perFileReport = @{}
$perFileMethodData = @{}

foreach ($package in $xml.report.package) {
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
}

@{
    totals            = $totals
    perFileReport     = $perFileReport
    perFileMethodData = $perFileMethodData
}
