# .SYNOPSIS
# Runs Pester with optional code coverage.
# Coverage scope is inferred from PathToTest: directories cover themselves,
# single test files cover their corresponding production file (or fall back to RepoRoot).
#
# .PARAMETER CoverageFormat
# Controls the XML format written to auto/coverage.xml.
#
# CoverageGutters (default): package and class names are absolute paths; sourcefilename is leaf-only.
#   The VS Code Coverage Gutters extension detects format by content (DOCTYPE contains "JACOCO"), then
#   resolves source files by joining the absolute package path with the leaf sourcefilename. This is
#   why absolute paths are required — relative paths (as in JaCoCo format) cannot be anchored to disk.
#
# JaCoCo: package and class names are relative (e.g. "prat/lib/Foo"); sourcefilename is a relative
#   path (e.g. "lib/Foo.ps1"). This makes the sourcefile directly searchable by relative path, which
#   is easier for agents. However, Coverage Gutters cannot resolve files from these relative paths and
#   reports no coverage — so JaCoCo is only useful when the output is consumed by agents, not the IDE.
#

[CmdletBinding()]
param (
    [switch] $NoCoverage,
    $PathToTest = ".",
    $RepoRoot = (Resolve-Path "$PSScriptRoot\.."),
    $OutputDir = $null,
    [ValidateSet("CoverageGutters", "JaCoCo")] [string] $CoverageFormat = "CoverageGutters",
    [switch] $Debugging,
    [switch] $IncludeIntegrationTests
)

function getCoverageSummary($coverageSrc) {
    if (($null -eq $coverageSrc) -or !(Test-Path $coverageSrc)) { return $null }

    [xml]$xml = Get-Content $coverageSrc
    $instr = $xml.report.counter | Where-Object { $_.type -eq "INSTRUCTION" }
    $cls = $xml.report.counter | Where-Object { $_.type -eq "CLASS" }
    $covered = [int]$instr.covered
    $total = [int]$instr.missed + $covered
    $files = [int]$cls.missed + [int]$cls.covered
    $pct = if ($total -gt 0) { [int][math]::Round($covered * 10000.0 / $total)/100 } else { 0 }
    $target = & (Resolve-PratLibFile "lib/Get-CoveragePercentTarget.ps1")

    "Covered $pct% / $target%. $covered/$total Commands in $files Files."
}

function getTestSummary($result) {
    $passedCount = if ($null -ne $result) { $result.PassedCount } else { "?" }
    $failedCount = if ($null -ne $result) { $result.FailedCount } else { "?" }

    "Passed: $passedCount, Failed: $failedCount."
}

function getTestRunSummary($result, $coverageSrc, $summaryDest) {
    $components = @()

    $coverageSummary = getCoverageSummary $coverageSrc
    if ($null -ne $coverageSummary) { $components += $coverageSummary }
    $components += getTestSummary $result

    return ($components -join " ")
}

function getAutoDir($repoRoot) {
    # TODO: Also check if .gitignore is set up to ignore it.
    # TODO: Share code with other scripts that use auto
    $dir = "$repoRoot/auto"
    if (!(Test-Path $dir)) {
        New-Item $dir -ItemType Directory | Out-Null
    }
    $dir
}

function moveCoverageFile($tempFile, $coverageDest = "$RepoRoot/auto/testRuns/last/coverage.xml") {
    # We send the coverage data to a temp file and then move it.
    # Why: Otherwise, Pester 5.5.0 puts relative path names in coverage.xml for any .ps1 files it finds under auto/.
    #      Which causes trouble e.g. in Get-CoverageReport.ps1.

    # TODO: Extract this into a function which create the 'auto' directory and also checks if .gitignore is set up to ignore it.
    $dir = Split-Path $coverageDest
    if (!(Test-Path $dir)) {
        New-Item $dir -ItemType Directory | Out-Null
    }
    try {
        Move-Item $tempFile $coverageDest -ErrorAction Stop -Force
    } catch {
        Write-Warning "Failed to move coverage file '$tempFile' to destination '$coverageDest': $_"
    }
}

function getRetention() { & (Resolve-PratLibFile "lib/Get-TestRunRetention.ps1") }
function getTimestamp() { Get-Date -Format "yyyy-MM-ddTHH-mm-ss-fff" }

function prepareRunDir($outputDir) {
    $testRunsDir = "$outputDir/testRuns"
    $lastDir = "$testRunsDir/last"

    if (Test-Path $lastDir) {
        # Rotate last → timestamp directory
        $timestamp = getTimestamp
        Move-Item $lastDir "$testRunsDir/$timestamp"

        # Apply retention: keep only the N most recent timestamp dirs
        $retention = getRetention
        $oldDirs = Get-ChildItem $testRunsDir -Directory |
            Where-Object { $_.Name -ne 'last' } |
            Sort-Object CreationTime, Name
        if ($oldDirs.Count -gt $retention) {
            $oldDirs | Select-Object -First ($oldDirs.Count - $retention) |
                Remove-Item -Recurse -Force
        }
    }

    New-Item $lastDir -ItemType Directory -Force | Out-Null
    $lastDir
}

$savedVerbosePreference = $VerbosePreference
if ($VerbosePreference -ne "SilentlyContinue") { $VerbosePreference = "SilentlyContinue" }
    Import-Module Pester
$VerbosePreference = $savedVerbosePreference

$pesterVerbosity = if ($Debugging) { "Diagnostic" } elseif ($VerbosePreference -ne "SilentlyContinue") { "Detailed" } else { "Normal" }

$Configuration = [PesterConfiguration]::Default
$Configuration.Run.PassThru = [bool] $true
$Configuration.Run.Path = $PathToTest
$Configuration.Output.Verbosity = $pesterVerbosity
if (!$IncludeIntegrationTests) { $Configuration.Filter.ExcludeTag = @('Integration') }

if (!$NoCoverage) {
    $tempFile = [IO.Path]::GetTempFileName()
    $Configuration.CodeCoverage.OutputPath = $tempFile
    $Configuration.CodeCoverage.Enabled = [bool] $true
    $Configuration.CodeCoverage.OutputFormat = $CoverageFormat
    $Configuration.CodeCoverage.Path = & "$PSScriptRoot/../lib/Get-CoverageScope" -PathToTest $PathToTest -RepoRoot $RepoRoot
    $Configuration.CodeCoverage.CoveragePercentTarget = & (Resolve-PratLibFile "lib/Get-CoveragePercentTarget.ps1")
}

$resolvedOutputDir = if ($OutputDir) { $OutputDir } else { getAutoDir $RepoRoot }
if ($OutputDir -and !(Test-Path $resolvedOutputDir)) { New-Item $resolvedOutputDir -ItemType Directory | Out-Null }
$runDir = prepareRunDir $resolvedOutputDir
$logFile = "$runDir/test-run.txt"

function ansiColor($text, $colorCode) {
    return "`e[$($colorCode)m$text`e[0m"
}    

$failureThreshold = 5

if ($Debugging) {
    # Bypass filter: stream everything directly to the host (full Pester diagnostic output).
    $result = Invoke-PesterAsJob -Configuration $Configuration -InformationVariable capturedInfo
    $capturedInfo | ForEach-Object { "$_" } | Out-File $logFile -Encoding utf8NoBOM
} else {
    # Smart filter: stream [+] lines live; emit first n failures; suppress the rest.
    $filterScript = "$PSScriptRoot/../lib/Invoke-WithOutputFilter.ps1"
    $runState = @{
        result       = $null
        failuresSeen = 0
        inFailure    = $false
        pendingLine  = $null
    }

    # Pre-create the log file so it exists even if the run produces no loggable output.
    $null | Out-File $logFile -Encoding utf8NoBOM

    $PSStyle.OutputRendering = 'Ansi'
    & $filterScript `
        -InitialState $runState `
        -Command {
            $InformationPreference = 'SilentlyContinue'
            # Extract the Pester.Run result here before it reaches the filter.
            Invoke-PesterAsJob -Configuration $Configuration 6>&1 | Where-Object {
                if ($null -ne $_.PSObject.Properties['PassedCount'] -and
                    $null -ne $_.PSObject.Properties['FailedCount']) {
                    $runState.result = $_
                    $false  # exclude from stream
                } else {
                    $true
                }
            }
        } `
        -ProcessLine {
            param($line, $state)

            if ($line.noNewLine) {
                # Buffer partial line — Pester's start record (Write-Host -NoNewLine).
                # The next record (timing) will complete it.
                $state.pendingLine = if ($null -ne $state.pendingLine) {
                    $state.pendingLine + $line.line
                } else {
                    $line.line
                }
                return $null
            }

            # Combine with any buffered partial line.
            $text = if ($null -ne $state.pendingLine) {
                $combined = $state.pendingLine + $line.line
                $state.pendingLine = $null
                $combined
            } else {
                $line.line
            }

            # Write to log progressively so the file survives a mid-run crash or kill.
            $text | Add-Content $logFile -Encoding utf8NoBOM

            if ($text -match '^\s*\[-\]') {
                if ($state.failuresSeen -lt $failureThreshold) {
                    $state.failuresSeen++
                    $state.inFailure = $true
                    return ansiColor $text 91
                } else {
                    $state.inFailure = $false
                }
                return $null
            }
            if ($state.inFailure) {
                if ($text -match '^(\s*\[\+\]|Tests completed)') {
                    $state.inFailure = $false
                    # Fall through
                } else {
                    return ansiColor $text 91
                }
            }
            if ($text -match '^\s*\[\+\].*[\\/]([^\\/]+\.ps1) .*$') {
                Write-Progress "Ran tests" $matches[1]
                return $null
            }
            return $null
        } `
        -RenderResult {
            param($state)
            # Flush any incomplete buffered line (edge case: run ended mid-line).
            if ($null -ne $state.pendingLine) {
                $state.pendingLine | Add-Content $logFile -Encoding utf8NoBOM
                $state.pendingLine = $null
            }
        }

    $result = $runState.result
}

$coverageDest = $null

if (!$NoCoverage) {
    if (Test-Path $tempFile) {
        $coverageDest = "$runDir/coverage.xml"
        moveCoverageFile $tempFile $coverageDest
    }
}

$testRunSummary = getTestRunSummary $result $coverageDest 
$testRunSummary | Out-File "$runDir/test-run-summary.txt" -Encoding utf8NoBOM

$colorCode = if ($result.FailedCount -gt 0) {
    if ($result.FailedCount -ge $failureThreshold) { 91 } else { 93 }
} else { 92 }
ansiColor $testRunSummary $colorCode

if (!$Debugging -and $null -ne $result -and $result.FailedCount -gt 0) {
    $suppressed = $result.FailedCount - $runState.failuresSeen
    $logFile = $logFile -replace '\\', '/'
    $hint = if ($suppressed -gt 0) {
        "$suppressed failure$(if ($suppressed -ne 1) {'s'}) suppressed — see $logFile"
    } else {
        "See $logFile"
    }
    ansiColor $hint 93
}

