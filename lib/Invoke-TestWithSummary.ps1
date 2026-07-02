# .SYNOPSIS
# Common scaffolding for test runners: runDir setup, output filtering, coverage summary, result reporting.
#
# Existing adapters (use as pattern for adding new ones):
#   Invoke-PesterWithSummary.ps1       — Pester (.ps1 tests)
#   Invoke-DotnetTestWithSummary.ps1   — dotnet test (.csproj)
#   Invoke-PytestWithSummary.ps1       — pytest (.py tests)
#
# The adapter (caller) provides scriptblock params for the framework-specific parts:
#   TestCommand     — runs the tests, streams output
#   ProcessLine     — filters/passes each output line; receives ($line, $state); returns string|$null
#   RenderResult    — post-run flush (e.g. pending partial lines); receives ($state)
#   GetCoverageFile — locates/copies the coverage file; receives ($runDir); returns path|$null
#   GetTestResult   — extracts pass/fail counts from state; receives ($state); returns @{Passed;Failed;FatalError}
#
# The harness injects these keys into $state before the run:
#   .logFile          — path to the run's test-run.txt
#   .logWriter        — open StreamWriter for test-run.txt; use instead of Add-Content for performance
#   .failureThreshold — max failures shown before suppression (default: 5)
#
# .PARAMETER LogHeader
# Lines written to test-run.txt before the run starts (e.g. "RepoRoot: ...", "TestArgs: ...").

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [scriptblock] $TestCommand,
    [Parameter(Mandatory)] [scriptblock] $ProcessLine,
    [Parameter(Mandatory)] [scriptblock] $RenderResult,
    [Parameter(Mandatory)] [scriptblock] $GetCoverageFile,
    [Parameter(Mandatory)] [scriptblock] $GetTestResult,
    [ValidateSet('commands', 'lines', 'instructions', '')]
    [string] $CoverageUnitForJaCoco = '',
    [Parameter(Mandatory)] [string]      $RepoRoot,
    [Parameter(Mandatory)] [DateTimeOffset] $StartTime,
    [hashtable]   $InitialState = @{},
    [string]      $OutputDir    = $null,
    [string[]]    $LogHeader    = @(),
    [switch]      $PassThru
)

function getAutoDir($root) {
    # TODO: Also check if .gitignore is set up to ignore it.
    # TODO: Share code with other scripts that use auto
    $dir = "$root/auto"
    if (!(Test-Path $dir)) { New-Item $dir -ItemType Directory | Out-Null }
    $dir
}

function getRetention() { & (Resolve-PratLibFile "lib/Get-TestRunRetention.ps1") }

$resolvedOutputDir = if ($OutputDir) { $OutputDir } else { "$(getAutoDir $RepoRoot)/testRuns" }
if (!(Test-Path $resolvedOutputDir)) { New-Item $resolvedOutputDir -ItemType Directory | Out-Null }
$runDir  = Initialize-TestRunDir -OutputDir $resolvedOutputDir -Retention (getRetention)
$logFile = "$runDir/test-run.txt"
$LogHeader | Out-File $logFile -Encoding utf8NoBOM

$failureThreshold = 5
$runState = $InitialState
$runState.runDir           = $runDir
$runState.logFile          = $logFile
$runState.failureThreshold = $failureThreshold

$logWriter = [System.IO.StreamWriter]::new($logFile, $true, [System.Text.UTF8Encoding]::new($false))
$runState.logWriter = $logWriter

$PSStyle.OutputRendering = 'Ansi'
$filterParams = @{
    InitialState = $runState
    Command      = $TestCommand
    ProcessLine  = $ProcessLine
    RenderResult = $RenderResult
}
try {
    if ($PassThru) {
        # -PassThru's contract is that the result hashtable is the only pipeline output;
        # live lines (e.g. failure reporting) go straight to the host instead.
        & "$PSScriptRoot/Invoke-WithOutputFilter.ps1" @filterParams | Out-Host
    } else {
        & "$PSScriptRoot/Invoke-WithOutputFilter.ps1" @filterParams
    }
} finally {
    $logWriter.Close()
}

$coveragePath = & $GetCoverageFile $runDir
$testResult   = & $GetTestResult $runState

$failuresSeen = $runState.failuresSeen ?? 0
$coverageData = Get-CoverageData -Path $coveragePath -CoverageUnitForJaCoco $CoverageUnitForJaCoco
if ($PassThru) {
    return @{
        CoverageData     = $coverageData
        Passed           = $testResult.Passed
        Failed           = $testResult.Failed
        FatalError       = $testResult.FatalError
        FailuresSeen     = $failuresSeen
        FailureThreshold = $failureThreshold
        RunDir           = $runDir
    }
}

Write-TestRunResult `
    -CoverageData $coverageData `
    -Passed      $testResult.Passed `
    -Failed      $testResult.Failed `
    -Elapsed     ([DateTimeOffset]::UtcNow - $StartTime) `
    -FailuresSeen $failuresSeen -FailureThreshold $failureThreshold `
    -RunDir      $runDir `
    -FatalError  $testResult.FatalError
