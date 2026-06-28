# .SYNOPSIS
# Runs pytest with output filtering, log capture, and a colored summary line.
#
# Parallels Invoke-DotnetTestWithSummary.ps1 for Python test projects.
#
# .PARAMETER Modules
# Module name(s) to collect branch coverage for (passed as --cov=<module> for each).
#
# .PARAMETER TestArgs
# Additional arguments to pass to pytest (e.g. a focus path).
#
# .PARAMETER OutputDir
# Direct parent of the `last/` run directory. Defaults to `<RepoRoot>/auto/testRuns`.
#
# .PARAMETER RepoRoot
# Repository root. Defaults to git toplevel.
#
# .PARAMETER WorkingDir
# Directory to run pytest from. Defaults to current directory.

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]] $Modules,

    [string[]] $TestArgs = @(),
    [string]   $OutputDir,
    [string]   $RepoRoot,
    [string]   $WorkingDir,
    [switch]   $NoCoverage,
    [switch]   $PassThru
)

$startTime = [DateTimeOffset]::UtcNow

if (-not $RepoRoot) {
    $RepoRoot = (git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0) { throw "Not in a git repository" }
}
$RepoRoot = $RepoRoot -replace '\\', '/'

function parsePytestSummary($line) {
    if ($line -notmatch '^=') { return $null }
    if ($line -match 'test session starts|short test summary') { return $null }
    $p = if ($line -match '(\d+) passed')  { [int]$Matches[1] } else { 0 }
    $f = if ($line -match '(\d+) failed')  { [int]$Matches[1] } else { 0 }
    $e = if ($line -match '(\d+) errors?') { [int]$Matches[1] } else { 0 }
    if ($line -match '\d+ (passed|failed|errors?)' -or $line -match 'no tests ran') {
        return @{ Passed = $p; Failed = $f + $e }
    }
    return $null
}

$runState = @{ passed = $null; failed = $null; failuresSeen = 0; exitCode = 0 }

$noCoverageLocal = $NoCoverage
$modulesLocal    = $Modules
$testArgsLocal   = $TestArgs
$workingDirLocal = $WorkingDir

& "$PSScriptRoot/Invoke-TestWithSummary.ps1" `
    -StartTime    $startTime `
    -RepoRoot     $RepoRoot `
    -OutputDir    $OutputDir `
    -InitialState $runState `
    -LogHeader    @("RepoRoot: $RepoRoot", "Modules: $($modulesLocal -join ', ')", "") `
    -PassThru:$PassThru `
    -TestCommand {
        if ($workingDirLocal) { Push-Location $workingDirLocal }
        $env:COVERAGE_FILE = "$($runState.runDir)/.coverage"
        try {
            $pytestArgs = @('-v', '-p', 'no:cacheprovider') + $testArgsLocal
            if (-not $noCoverageLocal) {
                foreach ($m in $modulesLocal) { $pytestArgs += "--cov=$m" }
                $pytestArgs += @('--cov-branch', "--cov-report=xml:$($runState.runDir)/coverage.xml")
            }
            python -B -m pytest @pytestArgs 2>&1
        } finally {
            $runState.exitCode = $LASTEXITCODE
            Remove-Item env:COVERAGE_FILE -ErrorAction SilentlyContinue
            if ($workingDirLocal) { Pop-Location }
        }
    } `
    -ProcessLine {
        param($line, $state)
        $state.logWriter.WriteLine($line.line)
        $parsed = parsePytestSummary $line.line
        if ($parsed) { $state.passed = $parsed.Passed; $state.failed = $parsed.Failed; return $null }
        if ($line.line -match '^(FAILED|ERROR) ') {
            if ($state.failuresSeen -lt $state.failureThreshold) {
                $state.failuresSeen++
                return Format-AnsiText $line.line 91
            }
            return $null
        }
        return $null
    } `
    -RenderResult { } `
    -GetCoverageFile {
        param($runDir)
        if ($noCoverageLocal) { return $null }
        $covFile = "$runDir/coverage.xml"
        if (Test-Path $covFile) { $covFile } else { $null }
    } `
    -GetTestResult {
        param($state)
        $fatalError = if ($null -eq $state.passed -and $state.exitCode -ne 0) {
            "pytest exit code: $($state.exitCode)"
        } else { $null }
        @{ Passed = $state.passed; Failed = $state.failed; FatalError = $fatalError }
    }

if ($runState.exitCode -ne 0) { exit $runState.exitCode }
