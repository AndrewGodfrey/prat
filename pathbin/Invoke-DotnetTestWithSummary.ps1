# .SYNOPSIS
# Runs dotnet test with output filtering, log capture, and a colored summary line.
#
# Parallels Invoke-PesterWithCodeCoverage for .NET test projects.
#
# .PARAMETER TestArgs
# Arguments to pass to `dotnet test` (project path, filters, etc.).
#
# .PARAMETER OutputDir
# Direct parent of the `last/` run directory. Defaults to `<RepoRoot>/auto/testRuns`.
# Callers that want project-namespaced runs (e.g. multiple projects under one repo root)
# should append their own namespace: `"$auto/testRuns/myproject"`.
#
# .PARAMETER WorkingDir
# Directory to run dotnet from. Affects global.json SDK selection (resolved from CWD upward).
# Defaults to current directory. Pass the project root when using strict version pinning.
#
# .PARAMETER RepoRoot
# Repository root. Defaults to git toplevel.
#
# .PARAMETER CoverageCollector
# Coverage tool to use. Default is `coverlet` (XPlat Code Coverage data collector — requires
# coverlet.collector NuGet package in the test project). Use `dotnet-coverage` to match CI
# pipelines that use `dotnet-coverage collect` (requires the dotnet-coverage global tool).
#
# .PARAMETER DisableFilter
# Show all output unfiltered (for diagnosing build/test issues).

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]] $TestArgs,

    [string] $OutputDir,
    [string] $RepoRoot,
    [string] $WorkingDir,
    [switch] $NoCoverage,
    [switch] $NoBuild,
    [ValidateSet("coverlet", "dotnet-coverage")] [string] $CoverageCollector = "coverlet",
    [string] $WorkspaceFile,
    [switch] $DisableFilter
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

# Parse cobertura XML for a coverage summary line
function getCoverageSummary($coveragePath, $unit) {
    if (-not $coveragePath -or -not (Test-Path $coveragePath)) { return $null }

    [xml]$xml = Get-Content $coveragePath
    $covered   = [int]$xml.coverage.'lines-covered'
    $total     = [int]$xml.coverage.'lines-valid'
    if ($total -eq 0) { return $null }
    $pct       = [math]::Round([double]$xml.coverage.'line-rate' * 100, 1)
    $fileCount = ($xml.coverage.packages.package.classes.class | Measure-Object).Count
    $target    = & (Resolve-PratLibFile "lib/Get-CoveragePercentTarget.ps1")

    "Covered $pct% / $target%. $covered/$total $unit in $fileCount Files."
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

$resolvedOutputDir = if ($OutputDir) { $OutputDir } else { "$(getAutoDir $RepoRoot)/testRuns" }
if (!(Test-Path $resolvedOutputDir)) { New-Item $resolvedOutputDir -ItemType Directory | Out-Null }
$runDir = Initialize-TestRunDir -OutputDir $resolvedOutputDir -Retention (getRetention)
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
    exitCode     = 0
}

# Use -tl:off so we get parseable line-by-line output instead of terminal logger's progress UI.
# Use -v:quiet to suppress per-project "succeeded" lines during build.
# The test runner's own output (pass/fail) still comes through.
$dotnetTestArgs = @("-tl:off", "-v:quiet") + $TestArgs
if ($NoBuild) { $dotnetTestArgs += "--no-build" }

if (-not $NoCoverage -and $CoverageCollector -eq "coverlet") {
    $dotnetTestArgs += "--collect", "XPlat Code Coverage", "--results-directory", "$runDir/testresults"
}

if (-not $NoCoverage -and $CoverageCollector -eq "dotnet-coverage") {
    if (-not (Get-Command dotnet-coverage -ErrorAction SilentlyContinue)) {
        throw "dotnet-coverage not found. Install it with: dotnet tool install --global dotnet-coverage"
    }
    $coverageDest = "$runDir/coverage.xml"
    $testCommand = {
        $savedEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        if ($WorkingDir) { Push-Location $WorkingDir }
        try {
            $dtArgsString = $dotnetTestArgs -join ' '
            dotnet-coverage collect "dotnet test $dtArgsString" -f cobertura -o $coverageDest 2>&1
        } finally {
            $runState.exitCode = $LASTEXITCODE
            if ($WorkingDir) { Pop-Location }
            [Console]::OutputEncoding = $savedEncoding
        }
    }
} else {
    $testCommand = {
        $savedEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        if ($WorkingDir) { Push-Location $WorkingDir }
        try {
            dotnet test @dotnetTestArgs 2>&1
        } finally {
            $runState.exitCode = $LASTEXITCODE
            if ($WorkingDir) { Pop-Location }
            [Console]::OutputEncoding = $savedEncoding
        }
    }
}

if ($DisableFilter) {
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

            # Show warnings regardless of build phase
            if ($line.line -match '^\s*warning') {
                return Format-AnsiText $line.line 93
            }

            # Suppress build output (restore, compile, publish lines)
            if (-not $state.buildDone) {
                if ($line.line -match 'Starting test execution|Test run for') {
                    $state.buildDone = $true
                }
                return $null
            }

            # Show failure lines (red), up to threshold
            if ($line.line -match '^\s*Failed|\[FAIL\]') {
                if ($state.failuresSeen -lt $failureThreshold) {
                    $state.failuresSeen++
                    $state.inFailure = $true
                    return Format-AnsiText $line.line 91
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
                    return Format-AnsiText $line.line 91
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

# Locate coverage file: dotnet-coverage writes directly to $coverageDest; coverlet puts it
# under testresults/<guid>/coverage.cobertura.xml and needs discovery + copy.
$coveragePath = $null
if (-not $NoCoverage) {
    if ($CoverageCollector -eq "dotnet-coverage") {
        if (Test-Path $coverageDest) { $coveragePath = $coverageDest }
    } else {
        $coverageFile = Get-ChildItem "$runDir/testresults" -Filter "coverage.cobertura.xml" -Recurse -ErrorAction SilentlyContinue |
                        Select-Object -First 1
        if ($coverageFile) {
            $coveragePath = "$runDir/coverage.xml"
            Copy-Item $coverageFile.FullName $coveragePath
        }
    }
}

if ($coveragePath) {
    $pathPrefixes = if ($WorkspaceFile) { Get-PathPrefixesFromWorkspace -WorkspaceFile $WorkspaceFile } else { @() }
    Convert-CoberturaXmlFile -Path $coveragePath -PathPrefixes $pathPrefixes
}

if (-not $NoCoverage -and -not $coveragePath) {
    $reason = if ($CoverageCollector -eq "coverlet") { " Is coverlet.collector installed in the test project?" } else { "" }
    Write-Warning "Coverage was requested but no coverage file was produced.$reason"
}

# Summary
$result = $runState.result
$coverageUnit = if ($CoverageCollector -eq "dotnet-coverage") { "Blocks" } else { "Lines" }
$passed = if ($null -ne $result) { $result.Passed } else { $null }
$failed = if ($null -ne $result) { $result.Failed } else { $null }
$failedTool = if ($CoverageCollector -eq "dotnet-coverage") { "dotnet-coverage" } else { "dotnet test" }
$fatalError = if ($null -eq $result -and $runState.exitCode -ne 0) { "$failedTool exit code: $($runState.exitCode)" } else { $null }
Write-TestRunResult -CoverageSummary (getCoverageSummary $coveragePath $coverageUnit) `
    -Passed $passed -Failed $failed -Elapsed ([DateTimeOffset]::UtcNow - $startTime) `
    -FailuresSeen $runState.failuresSeen -FailureThreshold $failureThreshold `
    -RunDir $runDir -DisableFilter:$DisableFilter -FatalError $fatalError

if ($runState.exitCode -ne 0) { exit $runState.exitCode }
