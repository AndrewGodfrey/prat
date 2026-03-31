# Private wrapper for testability
function Get-CoveragePercentTarget {
    & (Resolve-PratLibFile "lib/Get-CoveragePercentTarget.ps1")
}

# .SYNOPSIS
# Parses a coverage XML file and returns a data hashtable.
# Auto-detects JaCoCo (root <report>) and Cobertura (root <coverage>) formats.
# Returns null if $Path is null, the file does not exist, or total count is zero.
# Keys: Covered, Total, FileCount, Pct, Unit, Target
function Get-CoverageData {
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
        if ($total -eq 0) { return $null }
        $fileCount = [int]$cls.missed + [int]$cls.covered
        $pct = [math]::Round($covered * 100.0 / $total, 1)
    } elseif ($xml.DocumentElement.LocalName -eq 'coverage') {
        # Cobertura format
        $covered   = [int]$xml.coverage.'lines-covered'
        $total     = [int]$xml.coverage.'lines-valid'
        if ($total -eq 0) { return $null }
        $pct       = [math]::Round([double]$xml.coverage.'line-rate' * 100, 1)
        $fileCount = ($xml.coverage.packages.package.classes.class | Measure-Object).Count
    } else {
        throw "Get-CoverageData: unrecognized XML root element '$($xml.DocumentElement.LocalName)'"
    }

    @{ Covered = $covered; Total = $total; FileCount = $fileCount; Pct = $pct; Unit = $Unit; Target = $target }
}

# .SYNOPSIS
# Formats a CoverageData hashtable (from Get-CoverageData) as a human-readable summary string.
# Returns null if $Data is null.
function Format-CoverageData {
    param($Data)
    if (-not $Data) { return $null }
    "Covered $($Data.Pct)% / $($Data.Target)%. $($Data.Covered)/$($Data.Total) $($Data.Unit) in $($Data.FileCount) Files."
}
