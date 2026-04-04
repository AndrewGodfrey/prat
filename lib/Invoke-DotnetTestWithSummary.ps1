# .SYNOPSIS
# Runs dotnet test with output filtering, log capture, and a colored summary line.
#
# Parallels Invoke-PesterWithSummary for .NET test projects.
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
    [switch] $UseAlternateCollector,
    [switch] $PassThru
)

$startTime = [DateTimeOffset]::UtcNow

if ($UseAlternateCollector) { $CoverageCollector = "dotnet-coverage" }

if (-not $RepoRoot) {
    $RepoRoot = (git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0) { throw "Not in a git repository" }
}
$RepoRoot = $RepoRoot -replace '\\', '/'

# Use -tl:off so we get parseable line-by-line output instead of terminal logger's progress UI.
# Use -v:quiet to suppress per-project "succeeded" lines during build.
# The test runner's own output (pass/fail) still comes through.
$dotnetTestArgs = @("-tl:off", "-v:quiet") + $TestArgs
if ($NoBuild) { $dotnetTestArgs += "--no-build" }

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

if (-not $NoCoverage -and $CoverageCollector -eq "dotnet-coverage") {
    if (-not (Get-Command dotnet-coverage -ErrorAction SilentlyContinue)) {
        throw "dotnet-coverage not found. Install it with: dotnet tool install --global dotnet-coverage"
    }
}

$runState = @{
    result      = $null
    failuresSeen = 0
    inFailure   = $false
    buildDone   = $false
    exitCode    = 0
}

$coverageCollectorLocal = $CoverageCollector  # capture for closures

$testCommand = if (-not $NoCoverage -and $coverageCollectorLocal -eq "dotnet-coverage") {
    {
        $savedEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        if ($WorkingDir) { Push-Location $WorkingDir }
        try {
            $dtArgsString = $dotnetTestArgs -join ' '
            dotnet-coverage collect "dotnet test $dtArgsString" -f cobertura -o "$($runState.runDir)/coverage.xml" 2>&1
        } finally {
            $runState.exitCode = $LASTEXITCODE
            if ($WorkingDir) { Pop-Location }
            [Console]::OutputEncoding = $savedEncoding
        }
    }
} else {
    {
        $savedEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        if ($WorkingDir) { Push-Location $WorkingDir }
        try {
            $coverageArgs = if (-not $NoCoverage) {
                @("--collect", "XPlat Code Coverage", "--results-directory", "$($runState.runDir)/testresults")
            } else { @() }
            dotnet test @dotnetTestArgs @coverageArgs 2>&1
        } finally {
            $runState.exitCode = $LASTEXITCODE
            if ($WorkingDir) { Pop-Location }
            [Console]::OutputEncoding = $savedEncoding
        }
    }
}

& "$PSScriptRoot/Invoke-TestWithSummary.ps1" `
    -StartTime     $startTime `
    -RepoRoot      $RepoRoot `
    -OutputDir     $OutputDir `
    -CoverageUnit  ($coverageCollectorLocal -eq "dotnet-coverage" ? "Blocks" : "Lines") `
    -InitialState  $runState `
    -LogHeader     @("RepoRoot: $RepoRoot", "TestArgs: $TestArgs", "") `
    -PassThru:$PassThru `
    -TestCommand   $testCommand `
    -ProcessLine {
        param($line, $state)

        $state.logWriter.WriteLine($line.line)

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
            if ($state.failuresSeen -lt $state.failureThreshold) {
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
    -RenderResult { } `
    -GetCoverageFile {
        param($runDir)
        if ($NoCoverage) { return $null }

        if ($coverageCollectorLocal -eq "dotnet-coverage") {
            $dest = "$runDir/coverage.xml"
            if (Test-Path $dest) { return $dest }
            return $null
        } else {
            $coverageFile = Get-ChildItem "$runDir/testresults" -Filter "coverage.cobertura.xml" -Recurse -ErrorAction SilentlyContinue |
                            Select-Object -First 1
            if ($coverageFile) {
                $dest = "$runDir/coverage.xml"
                Copy-Item $coverageFile.FullName $dest
                $pathPrefixes = if ($WorkspaceFile) { Get-PathPrefixesFromWorkspace -WorkspaceFile $WorkspaceFile } else { @() }
                Convert-CoberturaXmlFile -Path $dest -PathPrefixes $pathPrefixes
                return $dest
            }
            Write-Warning "Coverage was requested but no coverage file was produced. Is coverlet.collector installed in the test project?"
            return $null
        }
    } `
    -GetTestResult {
        param($state)
        $failedTool = if ($coverageCollectorLocal -eq "dotnet-coverage") { "dotnet-coverage" } else { "dotnet test" }
        $fatalError = if ($null -eq $state.result -and $state.exitCode -ne 0) {
            "$failedTool exit code: $($state.exitCode)"
        } else { $null }
        @{
            Passed     = if ($null -ne $state.result) { $state.result.Passed } else { $null }
            Failed     = if ($null -ne $state.result) { $state.result.Failed } else { $null }
            FatalError = $fatalError
        }
    }

if ($runState.exitCode -ne 0) { exit $runState.exitCode }
