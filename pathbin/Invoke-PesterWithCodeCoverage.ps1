# .SYNOPSIS
# Runs Pester with optional code coverage.
# Coverage scope is inferred from PathToTest: directories cover themselves,
# single test files cover their corresponding production file (or fall back to RepoRoot).
#

[CmdletBinding()]
param (
    [switch] $NoCoverage,
    $PathToTest = ".",
    $RepoRoot = (Resolve-Path "$PSScriptRoot\.."),
    $OutputDir = $null,
    [switch] $DisableFilter,
    [switch] $IncludeIntegrationTests,
    [switch] $Integration,
    [switch] $UseAlternateCollector
)

if ($UseAlternateCollector) { Write-Warning "No alternate collector for Pester; continuing." }

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


function getAutoDir($repoRoot) {
    # TODO: Also check if .gitignore is set up to ignore it.
    # TODO: Share code with other scripts that use auto
    $dir = "$repoRoot/auto"
    if (!(Test-Path $dir)) {
        New-Item $dir -ItemType Directory | Out-Null
    }
    $dir
}

function moveCoverageFile($tempFile, $coverageDest) {
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

$startTime = [DateTimeOffset]::UtcNow

$savedVerbosePreference = $VerbosePreference
if ($VerbosePreference -ne "SilentlyContinue") { $VerbosePreference = "SilentlyContinue" }
    Import-Module Pester
$VerbosePreference = $savedVerbosePreference

$pesterVerbosity = if ($DisableFilter) { "Diagnostic" } else { "Normal" }

$Configuration = [PesterConfiguration]::Default
$Configuration.Run.PassThru = [bool] $true
$Configuration.Run.Path = $PathToTest
$Configuration.Output.Verbosity = $pesterVerbosity
if ($Integration -and $IncludeIntegrationTests) {
    Write-Warning "-Integration takes precedence over -IncludeIntegrationTests; running only Integration-tagged tests."
}
if ($Integration) {
    $Configuration.Filter.Tag = @('Integration')
} elseif (!$IncludeIntegrationTests) {
    $Configuration.Filter.ExcludeTag = @('Integration')
}

if (!$NoCoverage) {
    $tempFile = [IO.Path]::GetTempFileName()
    $Configuration.CodeCoverage.OutputPath = $tempFile
    $Configuration.CodeCoverage.Enabled = [bool] $true
    $Configuration.CodeCoverage.OutputFormat = 'CoverageGutters'  # This is a flavor of JaCoCo that CoverageGutters prefers.
    $Configuration.CodeCoverage.Path = & "$PSScriptRoot/../lib/Get-CoverageScope" -PathToTest $PathToTest -RepoRoot $RepoRoot
    $Configuration.CodeCoverage.CoveragePercentTarget = & (Resolve-PratLibFile "lib/Get-CoveragePercentTarget.ps1")
}

$resolvedOutputDir = if ($OutputDir) { $OutputDir } else { "$(getAutoDir $RepoRoot)/testRuns" }
if (!(Test-Path $resolvedOutputDir)) { New-Item $resolvedOutputDir -ItemType Directory | Out-Null }
$runDir = Initialize-TestRunDir -OutputDir $resolvedOutputDir -Retention (getRetention)
$logFile = "$runDir/test-run.txt"
@("RepoRoot: $RepoRoot", "PathToTest: $PathToTest", "") | Out-File $logFile -Encoding utf8NoBOM


$failureThreshold = 5

if ($DisableFilter) {
    # Bypass filter: stream everything directly to the host (full Pester diagnostic output).
    # Note: Invoke-PesterAsJob emits InformationRecords on stream 1 (via ReadAll()), not stream 6,
    # so -InformationVariable cannot capture them. Process each item explicitly instead.
    Invoke-PesterAsJob -Configuration $Configuration | ForEach-Object {
        if ($_ -is [System.Management.Automation.InformationRecord]) {
            $msgData = $_.MessageData
            $isHostInfo = $null -ne ($msgData.PSObject.Properties['Message']) -and
                          $null -ne ($msgData.PSObject.Properties['NoNewLine'])
            if ($isHostInfo) {
                Write-Host $msgData.Message -NoNewline:$msgData.NoNewLine
                $msgData.Message | Add-Content $logFile -Encoding utf8NoBOM
            } else {
                $text = "$($msgData)"
                Write-Host $text
                $text | Add-Content $logFile -Encoding utf8NoBOM
            }
        } elseif ($null -ne $_.PSObject.Properties['PassedCount'] -and
                  $null -ne $_.PSObject.Properties['FailedCount']) {
            $result = $_
        }
    }
} else {
    # Smart filter: stream [+] lines live; emit first n failures; suppress the rest.
    $filterScript = "$PSScriptRoot/../lib/Invoke-WithOutputFilter.ps1"
    $runState = @{
        result       = $null
        failuresSeen = 0
        inFailure    = $false
        pendingLine  = $null
    }

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
                    return Format-AnsiText $text 91
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
                    return Format-AnsiText $text 91
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

$passed = if ($null -ne $result) { $result.PassedCount } else { $null }
$failed = if ($null -ne $result) { $result.FailedCount } else { $null }
$failuresSeen = if ($DisableFilter) { 0 } else { $runState.failuresSeen }
Write-TestRunResult -CoverageSummary (getCoverageSummary $coverageDest) `
    -Passed $passed -Failed $failed -Elapsed ([DateTimeOffset]::UtcNow - $startTime) `
    -FailuresSeen $failuresSeen -FailureThreshold $failureThreshold `
    -RunDir $runDir -DisableFilter:$DisableFilter

