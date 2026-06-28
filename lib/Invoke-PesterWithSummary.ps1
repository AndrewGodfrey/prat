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
    [switch] $IncludeIntegrationTests,
    [switch] $Integration,
    [switch] $UseAlternateCollector,
    [switch] $PassThru
)

$startTime = [DateTimeOffset]::UtcNow

if ($UseAlternateCollector) { Write-Warning "No alternate collector for Pester; continuing." }

function moveCoverageFile($tempFile, $coverageDest) {
    # We send the coverage data to a temp file and then move it.
    # Why: Otherwise, Pester 5.5.0 puts relative path names in coverage.xml for any .ps1 files it finds under auto/.
    #      Which causes trouble e.g. in Get-CoverageReport.ps1.
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

$Configuration = [PesterConfiguration]::Default
$Configuration.Run.PassThru = [bool] $true
$Configuration.Run.Path = $PathToTest
$Configuration.Output.Verbosity = "Normal"
if ($Integration -and $IncludeIntegrationTests) {
    Write-Warning "-Integration takes precedence over -IncludeIntegrationTests; running only Integration-tagged tests."
}
if ($Integration) {
    $Configuration.Filter.Tag = @('Integration')
} elseif (!$IncludeIntegrationTests) {
    $Configuration.Filter.ExcludeTag = @('Integration')
}

$tempFile = $null
if (!$NoCoverage) {
    $tempFile = [IO.Path]::GetTempFileName()
    $Configuration.CodeCoverage.OutputPath = $tempFile
    $Configuration.CodeCoverage.Enabled = [bool] $true
    $Configuration.CodeCoverage.OutputFormat = 'CoverageGutters'  # This is a flavor of JaCoCo that CoverageGutters prefers.
    $Configuration.CodeCoverage.Path = & "$PSScriptRoot/Get-CoverageScope" -PathToTest $PathToTest -RepoRoot $RepoRoot
    $Configuration.CodeCoverage.CoveragePercentTarget = & (Resolve-PratLibFile "lib/Get-CoveragePercentTarget.ps1")
}

$runState = @{
    result      = $null
    failuresSeen = 0
    inFailure   = $false
    pendingLine = $null
}

& "$PSScriptRoot/Invoke-TestWithSummary.ps1" `
    -StartTime     $startTime `
    -RepoRoot      $RepoRoot `
    -OutputDir     $OutputDir `
    -CoverageUnitForJaCoco 'commands' `
    -InitialState  $runState `
    -LogHeader     @("RepoRoot: $RepoRoot", "PathToTest: $PathToTest", "") `
    -PassThru:$PassThru `
    -TestCommand {
        $InformationPreference = 'SilentlyContinue'
        # Extract the Pester.Run result before it reaches the filter.
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
        $state.logWriter.WriteLine($text)

        if ($text -match '^\s*\[-\]') {
            if ($state.failuresSeen -lt $state.failureThreshold) {
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
            $state.pendingLine | Add-Content $state.logFile -Encoding utf8NoBOM
            $state.pendingLine = $null
        }
    } `
    -GetCoverageFile {
        param($runDir)
        if ((-not $NoCoverage) -and $tempFile -and (Test-Path $tempFile)) {
            $dest = "$runDir/coverage.xml"
            moveCoverageFile $tempFile $dest
            return $dest
        }
        return $null
    } `
    -GetTestResult {
        param($state)
        @{
            Passed     = if ($null -ne $state.result) { $state.result.PassedCount } else { $null }
            Failed     = if ($null -ne $state.result) { $state.result.FailedCount } else { $null }
            FatalError = $null
        }
    }
