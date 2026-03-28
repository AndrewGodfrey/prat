# Private wrapper for testability
function Get-CoveragePercentTarget {
    & (Resolve-PratLibFile "lib/Get-CoveragePercentTarget.ps1")
}

# .SYNOPSIS
# Parses a coverage XML file and returns a summary string.
# Auto-detects JaCoCo (root <report>) and Cobertura (root <coverage>) formats.
# Returns null if $Path is null or the file does not exist.
function Get-CoverageSummary {
    param($Path, [Parameter(Mandatory)] [string] $Unit)

    if (-not $Path -or !(Test-Path $Path)) { return $null }

    [xml]$xml = Get-Content $Path
    $target = Get-CoveragePercentTarget

    if ($xml.DocumentElement.LocalName -eq 'report') {
        # JaCoCo format
        $instr = $xml.report.counter | Where-Object { $_.type -eq "INSTRUCTION" }
        $cls   = $xml.report.counter | Where-Object { $_.type -eq "CLASS" }
        $covered   = [int]$instr.covered
        $total     = [int]$instr.missed + $covered
        $fileCount = [int]$cls.missed + [int]$cls.covered
        $pct = if ($total -gt 0) { [int][math]::Round($covered * 10000.0 / $total) / 100 } else { 0 }
    } elseif ($xml.DocumentElement.LocalName -eq 'coverage') {
        # Cobertura format
        $covered   = [int]$xml.coverage.'lines-covered'
        $total     = [int]$xml.coverage.'lines-valid'
        if ($total -eq 0) { return $null }
        $pct       = [math]::Round([double]$xml.coverage.'line-rate' * 100, 1)
        $fileCount = ($xml.coverage.packages.package.classes.class | Measure-Object).Count
    } else {
        throw "Get-CoverageSummary: unrecognized XML root element '$($xml.DocumentElement.LocalName)'"
    }

    "Covered $pct% / $target%. $covered/$total $Unit in $fileCount Files."
}
