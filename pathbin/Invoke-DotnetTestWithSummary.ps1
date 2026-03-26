# .SYNOPSIS
# Runs dotnet test with output filtering, log capture, and a colored summary line.
#
# Parallels Invoke-PesterWithCodeCoverage for .NET test projects.
#
# .PARAMETER TestArgs
# Arguments to pass to `dotnet test` (project path, filters, coverage flags, etc.).
#
# .PARAMETER OutputDir
# Directory for test run logs. Defaults to `<RepoRoot>/auto`.
#
# .PARAMETER RepoRoot
# Repository root. Defaults to git toplevel.
#
# .PARAMETER Debugging
# Show all output unfiltered (for diagnosing build/test issues).

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]] $TestArgs,

    [string] $OutputDir,
    [string] $RepoRoot,
    [switch] $NoCoverage,
    [switch] $NoBuild,
    [switch] $Debugging
)

if (-not $RepoRoot) {
    $RepoRoot = (git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0) { throw "Not in a git repository" }
}
$RepoRoot = $RepoRoot -replace '\\', '/'

$startTime = [DateTimeOffset]::UtcNow

function getAutoDir($root) {
    $dir = "$root/auto"
    if (!(Test-Path $dir)) { New-Item $dir -ItemType Directory | Out-Null }
    $dir
}

function getRetention() { & (Resolve-PratLibFile "lib/Get-TestRunRetention.ps1") }
function getTimestamp() { Get-Date -Format "yyyy-MM-ddTHH-mm-ss-fff" }

function prepareRunDir($outputDir) {
    $ProgressPreference = 'SilentlyContinue'
    $testRunsDir = "$outputDir/testRuns"
    $lastDir = "$testRunsDir/last"

    if (Test-Path $lastDir) {
        $timestamp = getTimestamp
        Move-Item $lastDir "$testRunsDir/$timestamp"

        $retention = getRetention
        $oldDirs = Get-ChildItem $testRunsDir -Directory |
            Where-Object { $_.Name -ne 'last' } |
            Sort-Object CreationTime, Name
        if ($oldDirs.Count -gt $retention) {
            $oldDirs | Select-Object -First ($oldDirs.Count - $retention) | ForEach-Object {
                [System.IO.Directory]::Delete($_.FullName, $true)
            }
        }
    }

    New-Item $lastDir -ItemType Directory -Force | Out-Null
    $lastDir
}

function ansiColor($text, $colorCode) {
    return "`e[$($colorCode)m$text`e[0m"
}

# Parse cobertura XML for a coverage summary line
function getCoverageSummary($coveragePath) {
    if (-not $coveragePath -or -not (Test-Path $coveragePath)) { return $null }

    [xml]$cov = Get-Content $coveragePath
    $totalLines = 0
    $coveredLines = 0
    $files = 0
    foreach ($pkg in $cov.coverage.packages.package) {
        if (-not $pkg.classes) { continue }
        foreach ($cls in $pkg.classes.class) {
            if (-not $cls) { continue }
            $hasLines = $false
            foreach ($ln in $cls.lines.line) {
                $totalLines++
                if ([int]$ln.hits -gt 0) { $coveredLines++ }
                $hasLines = $true
            }
            if ($hasLines) { $files++ }
        }
    }
    if ($totalLines -eq 0) { return $null }
    $pct = [math]::Round($coveredLines * 100.0 / $totalLines, 2)
    "Covered $pct%. $coveredLines/$totalLines Lines in $files Files."
}

# Parse dotnet test summary line. Handles both terminal logger and classic formats:
#   "Test summary: total: 197, failed: 0, succeeded: 197, skipped: 0, duration: 1.7s"
#   "Passed!  - Failed:     0, Passed:   197, Skipped:     0, Total:   197, Duration: 628 ms"
function parseTestResult($line) {
    if ($line -match 'Failed:\s*(\d+).*Passed:\s*(\d+).*Skipped:\s*(\d+).*Total:\s*(\d+).*Duration:\s*(.+)') {
        return @{
            Failed   = [int]$Matches[1]
            Passed   = [int]$Matches[2]
            Skipped  = [int]$Matches[3]
            Total    = [int]$Matches[4]
            Duration = $Matches[5].Trim()
        }
    }
    if ($line -match 'total:\s*(\d+).*failed:\s*(\d+).*succeeded:\s*(\d+).*skipped:\s*(\d+).*duration:\s*(.+)') {
        return @{
            Total    = [int]$Matches[1]
            Failed   = [int]$Matches[2]
            Passed   = [int]$Matches[3]
            Skipped  = [int]$Matches[4]
            Duration = $Matches[5].Trim()
        }
    }
    return $null
}

$resolvedOutputDir = if ($OutputDir) { $OutputDir } else { getAutoDir $RepoRoot }
if ($OutputDir -and !(Test-Path $resolvedOutputDir)) { New-Item $resolvedOutputDir -ItemType Directory | Out-Null }
$runDir = prepareRunDir $resolvedOutputDir
$logFile = "$runDir/test-run.txt"
@("RepoRoot: $RepoRoot", "TestArgs: $TestArgs", "") | Out-File $logFile -Encoding utf8NoBOM

$failureThreshold = 5
$filterScript = "$PSScriptRoot/../lib/Invoke-WithOutputFilter.ps1"

$runState = @{
    result       = $null
    failuresSeen = 0
    inFailure    = $false
    pendingLine  = $null
    buildDone    = $false
}

# Use -tl:off so we get parseable line-by-line output instead of terminal logger's progress UI.
# Use -v:quiet to suppress per-project "succeeded" lines during build.
# The test runner's own output (pass/fail) still comes through.
$dotnetTestArgs = @("-tl:off", "-v:quiet") + $TestArgs
if ($NoBuild) { $dotnetTestArgs += "--no-build" }

$coverageDest = $null
if (-not $NoCoverage) {
    $coverageDest = "$runDir/coverage.xml"
    $commandAndArgs = @("dotnet-coverage", "collect", ($dotnetTestArgs -join ' '), "-f", "cobertura", "-o", $coverageDest)
} else {
    $commandAndArgs = @("dotnet", "test") + $dotnetTestArgs
}

# Build the command scriptblock. dotnet-coverage wraps "dotnet test" as a quoted command string;
# plain dotnet test uses splatted args.
if (-not $NoCoverage) {
    $testCommand = {
        $dtArgsString = $dotnetTestArgs -join ' '
        dotnet-coverage collect "dotnet test $dtArgsString" -f cobertura -o $coverageDest 2>&1
    }
} else {
    $testCommand = { dotnet test @dotnetTestArgs 2>&1 }
}

if ($Debugging) {
    & $testCommand | ForEach-Object {
        $text = "$_"
        $text | Add-Content $logFile -Encoding utf8NoBOM
        Write-Host $text
        $parsed = parseTestResult $text
        if ($parsed) { $runState.result = $parsed }
    }
} else {
    $PSStyle.OutputRendering = 'Ansi'
    & $filterScript `
        -InitialState $runState `
        -Command $testCommand `
        -ProcessLine {
            param($line, $state)

            $line.line | Add-Content $logFile -Encoding utf8NoBOM

            # Parse test result summary
            $parsed = parseTestResult $line.line
            if ($parsed) {
                $state.result = $parsed
                return $null  # we'll render our own summary
            }

            # Suppress build output (restore, compile, publish lines)
            if (-not $state.buildDone) {
                if ($line.line -match 'Starting test execution|Test run for') {
                    $state.buildDone = $true
                }
                return $null
            }

            # Show failure lines (red), up to threshold
            if ($line.line -match '^\s*Failed') {
                if ($state.failuresSeen -lt $failureThreshold) {
                    $state.failuresSeen++
                    $state.inFailure = $true
                    return ansiColor $line.line 91
                } else {
                    $state.inFailure = $false
                }
                return $null
            }

            # Continuation of a failure (stack trace, etc.)
            if ($state.inFailure) {
                if ($line.line -match '^\s*Passed|^\s*$' -or $line.line -match 'Test Run') {
                    $state.inFailure = $false
                } else {
                    return ansiColor $line.line 91
                }
            }

            return $null
        } `
        -RenderResult {
            param($state)
            if ($null -ne $state.pendingLine) {
                $state.pendingLine | Add-Content $logFile -Encoding utf8NoBOM
                $state.pendingLine = $null
            }
        }
}

# Summary
$result = $runState.result
$elapsed = [DateTimeOffset]::UtcNow - $startTime
$elapsedStr = " $(Format-Duration $elapsed.TotalSeconds)"

$coverageSummary = getCoverageSummary $coverageDest

if ($null -ne $result) {
    $components = @()
    if ($coverageSummary) { $components += $coverageSummary }
    $components += "Passed: $($result.Passed), Failed: $($result.Failed).$elapsedStr"
    $summary = $components -join " "
    $colorCode = if ($result.Failed -gt 0) {
        if ($result.Failed -ge $failureThreshold) { 91 } else { 93 }
    } else { 92 }
} else {
    $summary = "Test run completed (no result parsed).$elapsedStr"
    $colorCode = 93
}

$summary | Out-File "$runDir/summary.txt" -Encoding utf8NoBOM
ansiColor $summary $colorCode

if (-not $Debugging -and $null -ne $result -and $result.Failed -gt 0) {
    $suppressed = $result.Failed - $runState.failuresSeen
    $logFile = $logFile -replace '\\', '/'
    $hint = if ($suppressed -gt 0) {
        "$suppressed failure$(if ($suppressed -ne 1) {'s'}) suppressed - see $logFile"
    } else {
        "See $logFile"
    }
    ansiColor $hint 93
}
