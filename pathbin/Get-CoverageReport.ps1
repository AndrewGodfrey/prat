# Gets a simple code-coverage report from the result of Invoke-PesterWithCodeCoverage.ps1
# This is useful to find files that need more coverage.
#
# Expects a Pester-generated coverage XML file in CoverageGutters format.

param ($coverageFile = "$PSScriptRoot/../auto/coverage.xml",
    [switch] $ShowAll, 
    $CoverageGoalPercent = $(& (Resolve-PratLibFile "lib/Get-CoveragePercentTarget.ps1"))
    )

$exclusionFilter = & (Resolve-PratLibFile "lib/Get-CoverageExclusionFilter.ps1")

function LoadCoverageReport($coverageFile) {
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

    if ($null -eq $xml.report) { throw "Invalid coverage file: $coverageFile - missing <report> element" }

    foreach ($package in $xml.report.package) { # This glosses over $xml.report.Count being 2. The first one is empty. I guess the doctype element?
        foreach ($class in $package.class) {
            $filename = Join-Path $class.name $class.sourcefilename

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