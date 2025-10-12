# Gets a simple code-coverage report from the result of Invoke-PesterWithCodeCoverage.ps1
# This is useful to find files that need more coverage.
#
# Expects a Pester-generated coverage XML file in CoverageGutters format.

param ($coverageFile = "$PSScriptRoot/../auto/coverage.xml",
    [switch] $ShowAll, 
    [switch] $FullPaths,
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
    if ($AsDouble) {
        if ($total -eq 0) {
            return 0.0
        } else {
            return ($covered * 100.0) / $total
        }
    }
    if ($total -eq 0) {
        return "n/a"
    } else {
        return [string] [math]::Round(($covered * 100.0) / $total, 0)
    }
}

function FileMeetsGoal($data, $goalPercent) {
    foreach ($counterType in @("METHOD", "LINE", "INSTRUCTION")) {
        $coverage = CalculateCoverage $data[$counterType] -AsDouble
        if ($coverage -lt $goalPercent) {
            return $false
        }
    }
    return $true
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
    if ($fileMeetsGoal) {
        $filesMeetingGoal += 1
    }

    if ($ShowAll -or !$fileMeetsGoal) {
        return [pscustomobject] @{
            File = $name
            MethodsCovered = CalculateCoverage $data.METHOD
            LinesCovered = CalculateCoverage $data.LINE
            InstructionsCovered = CalculateCoverage $data.INSTRUCTION
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
    if ($commonPrefix.Length -gt 0) {
        for ([int] $i=0; $i -lt $mungedPerFileReport.Count; $i++) {
            $mungedPerFileReport[$i].File = $mungedPerFileReport[$i].File.Substring($commonPrefix.Length)
        }
    }
}

$mungedPerFileReport += [pscustomobject] @{}
$mungedPerFileReport +=  
    [pscustomobject] @{
        File = "TOTALS"
        MethodsCovered = CalculateCoverage $report.totals.METHOD
        LinesCovered = CalculateCoverage $report.totals.LINE
        InstructionsCovered = CalculateCoverage $report.totals.INSTRUCTION
    }
    
$mungedPerFileReport | Format-Table -AutoSize
$notShown = ""
if ($ShowAll -eq $false) {
    $notShown = " (not shown)"
}
Write-Host "`nFiles meeting goal: $($filesMeetingGoal)$notShown"