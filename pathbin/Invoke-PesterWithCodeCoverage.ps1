# .SYNOPSIS
# Runs Pester with optional code coverage.
# Coverage scope is inferred from PathToTest: directories cover themselves,
# single test files cover their corresponding production file (or fall back to RepoRoot).
[CmdletBinding()]
param (
    [switch] $NoCoverage,
    $PathToTest = ".",
    $RepoRoot = (Resolve-Path "$PSScriptRoot\.."),
    [ValidateSet("CoverageGutters", "JaCoCo")] [string] $CoverageFormat = "CoverageGutters",
    [ValidateSet("Summary", "Normal", "Failures", "Debugging")] [string] $Verbosity = "Normal"
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

function moveCoverageFile($tempFile, $coverageDest = "$RepoRoot/auto/coverage.xml") {
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

$savedVerbosePreference = $VerbosePreference
if ($VerbosePreference -ne "SilentlyContinue") { $VerbosePreference = "SilentlyContinue" }
    Import-Module Pester
$VerbosePreference = $savedVerbosePreference

$pesterVerbosity = switch ($Verbosity) {
    "Summary"   { "None" }
    "Normal"    { "Normal" }
    "Failures"  { "Detailed" }
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

$result = Invoke-PesterAsJob -Configuration $Configuration

$autoDir = getAutoDir $RepoRoot
$coverageDest = $null

if (!$NoCoverage) {
    if (Test-Path $tempFile) {
        $coverageDest = "$autoDir/coverage.xml"
        moveCoverageFile $tempFile $coverageDest
    }
}

 writeTestRunSummary $result $coverageDest "$autoDir/test-run-summary.txt"
