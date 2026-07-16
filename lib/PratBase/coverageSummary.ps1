# Private wrapper for testability
function Get-CoveragePercentTarget {
    & (Resolve-PratLibFile "lib/Get-CoveragePercentTarget.ps1")
}

# .SYNOPSIS
# Parses a coverage XML file and returns a data hashtable.
# Auto-detects JaCoCo (root <report>) and Cobertura (root <coverage>) formats.
# Returns null if $Path is null, the file does not exist, or total count is zero.
# Keys: Covered, Total, FileCount, Pct, Unit, Target
#
# -CoverageUnitForJaCoco: optional label for the JaCoCo INSTRUCTION counter ('commands', 'lines',
# 'instructions'). Defaults to 'instructions'. Not valid for Cobertura — that format is
# self-describing and its unit is derived from the XML content.
function Get-CoverageSummary {
    param($Path, [string] $CoverageUnitForJaCoco = '')

    if (-not $Path -or !(Test-Path $Path)) { return $null }

    [xml]$xml = Get-Content $Path
    if (-not $xml.DocumentElement) { return $null }
    $target = Get-CoveragePercentTarget

    if ($xml.DocumentElement.LocalName -eq 'report') {
        # JaCoCo format — reads INSTRUCTION counters; caller names the unit, defaulting to 'instructions'
        $instr = $xml.report.counter | Where-Object { $_.type -eq "INSTRUCTION" }
        $cls   = $xml.report.counter | Where-Object { $_.type -eq "CLASS" }
        $covered   = [int]$instr.covered
        $total     = [int]$instr.missed + $covered
        if ($total -eq 0) { return $null }
        $fileCount = [int]$cls.missed + [int]$cls.covered
        $pct  = [math]::Round($covered * 100.0 / $total, 1)
        $unit = if ($CoverageUnitForJaCoco) { $CoverageUnitForJaCoco } else { 'instructions' }
    } elseif ($xml.DocumentElement.LocalName -eq 'coverage') {
        # Cobertura is self-describing: unit derived from XML; -CoverageUnitForJaCoco is not applicable.
        if ($CoverageUnitForJaCoco) {
            throw "Get-CoverageSummary: -CoverageUnitForJaCoco is not valid for Cobertura format (unit is derived from XML content)"
        }
        $branchesValid = [int]$xml.coverage.'branches-valid'
        if ($branchesValid -gt 0) {
            $covered = [int]$xml.coverage.'branches-covered'
            $total   = $branchesValid
            $pct     = [math]::Round([double]$xml.coverage.'branch-rate' * 100, 1)
            $unit    = 'branches'
        } else {
            $covered = [int]$xml.coverage.'lines-covered'
            $total   = [int]$xml.coverage.'lines-valid'
            $pct     = [math]::Round([double]$xml.coverage.'line-rate' * 100, 1)
            $unit    = 'lines'
        }
        if ($total -eq 0) { return $null }
        $fileCount = ($xml.coverage.packages.package.classes.class | Measure-Object).Count
    } else {
        throw "Get-CoverageSummary: unrecognized XML root element '$($xml.DocumentElement.LocalName)'"
    }

    @{ Covered = $covered; Total = $total; FileCount = $fileCount; Pct = $pct; Unit = $unit; Target = $target }
}

# .SYNOPSIS
# Formats a CoverageData hashtable (from Get-CoverageSummary) as a human-readable summary string.
# Returns null if $Data is null.
function Format-CoverageData {
    param($Data)
    if (-not $Data) { return $null }
    "Covered $($Data.Pct)% / $($Data.Target)%. $($Data.Covered)/$($Data.Total) $($Data.Unit) in $($Data.FileCount) Files."
}
