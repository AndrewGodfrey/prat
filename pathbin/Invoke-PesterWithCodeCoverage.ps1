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
    [ValidateSet("Summary", "Normal", "Debugging")] [string] $Verbosity = "Normal"
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

function writeTestRunSummary($result, $coverageSrc, $summaryDest) {
    $components = @()

    $coverageSummary = getCoverageSummary $coverageSrc
    if ($null -ne $coverageSummary) { $components += $coverageSummary }
    $components += getTestSummary $result

    ($components -join " ") | Out-File $summaryDest -Encoding utf8NoBOM
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

$pesterVerbosity = switch ($Verbosity) {
    "Summary"   { "None" }
    "Normal"    { "Normal" }
    "Debugging" { "Diagnostic" }
}
if ($VerbosePreference -ne "SilentlyContinue") {
    # -Verbose flag overrides intent-level verbosity for pinpointing unwanted output.
    $pesterVerbosity = "Detailed"
}

$Configuration = [PesterConfiguration]::Default
$Configuration.Run.PassThru = [bool] $true
$Configuration.Run.Path = $PathToTest
$Configuration.Output.Verbosity = $pesterVerbosity

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

# Run Pester: let the information stream flow naturally to the console so that Pester's
# terminal rendering (carriage-return line overwrites, ANSI colors) works correctly.
# -InformationVariable captures the records for the log file without intercepting them.
$result = Invoke-PesterAsJob -Configuration $Configuration -InformationVariable capturedInfo

# Write log file. Records contain ANSI codes (PSStyle.OutputRendering='Ansi' in child job).
$capturedInfo | ForEach-Object { "$_" } | Out-File $logFile -Encoding utf8NoBOM

$coverageDest = $null

if (!$NoCoverage) {
    if (Test-Path $tempFile) {
        $coverageDest = "$runDir/coverage.xml"
        moveCoverageFile $tempFile $coverageDest
    }
}

writeTestRunSummary $result $coverageDest "$runDir/test-run-summary.txt"

if ($Verbosity -eq "Summary") {
    $summaryPath = "$runDir/test-run-summary.txt"
    if (Test-Path $summaryPath) {
        Get-Content $summaryPath
    }
}
