# Gets a simple code-coverage report from the result of Invoke-PesterWithCodeCoverage.ps1
# This is useful to find files that need more coverage.
#
# Expects a Pester-generated coverage XML file in CoverageGutters format.

using namespace System.Diagnostics.CodeAnalysis

param ($coverageFile = "$PSScriptRoot/../auto/coverage.xml",
    [switch] $ShowAll, 
    [switch] $FullPaths,
    [switch] $Unformatted,
    [switch] $Ignore_OmitFromCoverageReport,
    $CoverageGoalPercent = $(& (Resolve-PratLibFile "lib/Get-CoveragePercentTarget.ps1"))
    )

$exclusionFilter = & (Resolve-PratLibFile "lib/Get-CoverageExclusionFilter.ps1")

function LoadCoverageReport($coverageFile) {
    function appendCounterData($filename, $counters) {
        if ($null -eq $report[$filename]) {
            $report[$filename] = @{
                INSTRUCTION = @{ missed = 0; covered = 0 }
                LINE = @{ missed = 0; covered = 0 } 
                METHOD = @{ missed = 0; covered = 0 }
            }
        }
        $r = $report[$filename]
        foreach ($counter in $counters) {
            if ($null -eq $r[$counter.type]) { throw "Internal error: unexpected counter type: $($counter.type)" }
            $r[$counter.type].missed += [int] $counter.missed
            $r[$counter.type].covered += [int] $counter.covered
            $totals[$counter.type].missed += [int] $counter.missed
            $totals[$counter.type].covered += [int] $counter.covered
        }
    }

    function calculateFullFilename($className, $sourceFileName) {
        # For some reason, className ends in the filename of the .ps1 file, without the extension. So remove that to avoid repeating it.
        $path = Split-Path -parent $className
        return Join-Path $path $sourcefilename
    }

    if (!(Test-Path $coverageFile)) {
        Write-Error "Coverage file not found: $coverageFile"
        exit 1
    }
    [xml]$xml = Get-Content $coverageFile
    $report = @{}
    $totals = @{
        INSTRUCTION = @{ missed = 0; covered = 0 }
        LINE = @{ missed = 0; covered = 0 } 
        METHOD = @{ missed = 0; covered = 0 }
    }

    if ($null -eq $xml.report) { throw "Invalid coverage file: $coverageFile - missing <report> element" }

    foreach ($package in $xml.report.package) { # This glosses over $xml.report.Count being 2. The first one is empty. I guess the doctype element?
        foreach ($class in $package.class) {
            $filename = calculateFullFilename $class.name $class.sourcefilename

            foreach ($method in $class.method) {
                appendCounterData $filename $method.counter
            }
        }
    }

    return @{totals = $totals; perFileReport = $report}
}

function CalculateCoverage($counter, [switch] $AsDouble) {
    $covered = [long] $counter.covered
    $total = ([long] $counter.missed) + $covered
    if ($AsDouble -or $Unformatted) {
        if ($total -eq 0) {
            return 0.0
        } else {
            return ($covered * 100.0) / $total
        }
    }
    if ($total -eq 0) {
        return "n/a"
    } else {
        $result = [string] [math]::Round(($covered * 100.0) / $total, 0)
        return " " * (3 - $result.Length) + $result
    }
}

function FileMeetsGoal($data, $goalPercent) {
    # We exclude "METHOD" counters because:
    #
    # It's common to add a wrapper method explicitly to create a safe point to mock. So then that wrapper isn't covered or worth covering.
    # A small script with 3 wrappers would be a very reasonable situation, but would count as only having  25% method coverage.
    foreach ($counterType in @("LINE", "INSTRUCTION")) {
        $coverage = CalculateCoverage $data[$counterType] -AsDouble
        if ($coverage -lt $goalPercent) {
            return $false
        }
    }
    return $true
}


function emitRows {
    [ExcludeFromCodeCoverageAttribute()] # Oops, I thought this was already supported in Pester 5.5 - but it's coming in Pester 6.
    param($rows, $unformatted)

    if ($unformatted) {
        $rows
    } else {
        $rows | Format-Table -AutoSize
    }
}

function emitBlankLine {
    [ExcludeFromCodeCoverageAttribute()] # Oops, I thought this was already supported in Pester 5.5 - but it's coming in Pester 6.    
    param ($Unformatted)

    if (!$Unformatted) {
        Write-Host ""
    }
}

function GetLastLine($filename) {
    $lines = Get-Content $filename
    if ($lines.Length -eq 0) { return "" }
    return $lines[$lines.Length - 1]
}

function IsFileOmitted($filename) {
    $lastLine = GetLastLine($filename)
    if ($lastLine -match '^\s*#\s*OmitFromCoverageReport\s*:\s*[^\s]') { # e.g. "# OmitFromCoverageReport: a unit test would just restate it"
        return $true
    }
    return $false
}

$report = LoadCoverageReport $coverageFile
# return $report.GetEnumerator() | Sort-Object Name
$filesMeetingGoal = 0

$mungedPerFileReport = @($report.perFileReport.GetEnumerator() | Sort-Object Name | ForEach-Object {
    $name = $_.Name
    $data = $_.Value

    if (& $exclusionFilter $name) {
        return
    }

    $fileMeetsGoal = FileMeetsGoal $data $CoverageGoalPercent
    if (!$fileMeetsGoal -and !$Ignore_OmitFromCoverageReport) {
        if (IsFileOmitted $name) {
            $fileMeetsGoal = $true
        }
    }
    if ($fileMeetsGoal) {
        $filesMeetingGoal += 1
    }

    if ($ShowAll -or !$fileMeetsGoal) {
        return [pscustomobject] @{
            File = $name
            Methods = CalculateCoverage $data.METHOD
            Lines = CalculateCoverage $data.LINE
            Instructions = CalculateCoverage $data.INSTRUCTION
        }
    }
})

if (!$FullPaths -and $mungedPerFileReport.Count -gt 1) {
    function GetCommonPrefix($s1, $s2) {
        $minLen = [math]::Min($s1.Length, $s2.Length)
        for ([int] $i=0; $i -lt $minLen; $i++) {
            if ($s1[$i] -ne $s2[$i]) {
                return $s1.Substring(0, $i)
            }
        }
        return $s1.Substring(0, $minLen)
    }
    $commonPrefix = $mungedPerFileReport[0].File;
    for ([int] $i=1; $i -lt $mungedPerFileReport.Count; $i++) {
        $commonPrefix = GetCommonPrefix $commonPrefix $mungedPerFileReport[$i].File
    }
    if ($commonPrefix -ne "") {
        # Trim to last path separator
        $lastSep = $commonPrefix.LastIndexOfAny(@('\', '/'))
        if ($lastSep -ge 0) {
            $commonPrefix = $commonPrefix.Substring(0, $lastSep + 1)
        } else {
            $commonPrefix = ""
        }
    }
    if ($commonPrefix.Length -gt 0) {
        for ([int] $i=0; $i -lt $mungedPerFileReport.Count; $i++) {
            $mungedPerFileReport[$i].File = $mungedPerFileReport[$i].File.Substring($commonPrefix.Length)
        }
    }
}


emitRows $mungedPerFileReport $Unformatted

$totals = @(
    [pscustomobject] @{
        Methods = CalculateCoverage $report.totals.METHOD
        Lines = CalculateCoverage $report.totals.LINE
        Instructions = CalculateCoverage $report.totals.INSTRUCTION
})

emitRows $totals $Unformatted

emitBlankLine $Unformatted

$notShown = ""
if ($ShowAll -eq $false -and $filesMeetingGoal -gt 0) {
    $notShown = " (not shown)"
}

"Files meeting goal: $($filesMeetingGoal)$notShown"
emitBlankLine $Unformatted
