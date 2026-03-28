# Initialize-TestRunDir: Creates (or rotates) the test run output directory.
#
# $OutputDir is the direct parent of the 'last/' subdirectory.
# If 'last/' exists, rotates it to a timestamped directory and applies retention.
# Returns the path to the newly-created 'last/' directory.
function Initialize-TestRunDir {
    param(
        [string] $OutputDir,
        [int] $Retention = 10,
        [string] $Timestamp = $null
    )
    $ProgressPreference = 'SilentlyContinue'
    if (-not $Timestamp) { $Timestamp = Get-Date -Format "yyyy-MM-ddTHH-mm-ss-fff" }

    $lastDir = "$OutputDir/last"

    if (Test-Path $lastDir) {
        Move-Item $lastDir "$OutputDir/$Timestamp"

        $oldDirs = Get-ChildItem $OutputDir -Directory |
            Where-Object { $_.Name -ne 'last' } |
            Sort-Object CreationTime, Name
        if ($oldDirs.Count -gt $Retention) {
            $oldDirs | Select-Object -First ($oldDirs.Count - $Retention) | ForEach-Object {
                [System.IO.Directory]::Delete($_.FullName, $true)
            }
        }
    }

    New-Item $lastDir -ItemType Directory -Force | Out-Null
    $lastDir
}

# Write-TestRunResult: Builds the summary line, writes summary.txt, emits it colored,
# and (unless -Debugging) emits a suppressed-hint when failures exceed the shown count.
#
# $Passed/$Failed accept $null to signal "no result parsed" (yellow summary, fallback text).
function Write-TestRunResult {
    param(
        $CoverageSummary = $null,
        $Passed = $null,
        $Failed = $null,
        [TimeSpan] $Elapsed = [TimeSpan]::Zero,
        [int] $FailuresSeen = 0,
        [string] $RunDir,
        [switch] $Debugging,
        [int] $FailureThreshold = 5
    )
    $failedCount = if ($null -ne $Failed) { [int]$Failed } else { 0 }
    $durationStr = Format-Duration $Elapsed.TotalSeconds

    $components = @()
    if ($CoverageSummary) { $components += $CoverageSummary }
    if ($null -ne $Passed -and $null -ne $Failed) {
        $components += "Passed: $Passed, Failed: $Failed. $durationStr"
    } else {
        $components += "Test run completed (no result parsed). $durationStr"
    }
    $summary = $components -join " "

    $colorCode = if ($null -eq $Failed) { 93 }
                 elseif ($failedCount -gt 0) { if ($failedCount -ge $FailureThreshold) { 91 } else { 93 } }
                 else { 92 }

    $summary | Out-File "$RunDir/summary.txt" -Encoding utf8NoBOM
    Format-AnsiText $summary $colorCode

    if (-not $Debugging -and $failedCount -gt 0) {
        $suppressed = $failedCount - $FailuresSeen
        $logFile = ("$RunDir/test-run.txt") -replace '\\', '/'
        $hint = if ($suppressed -gt 0) {
            "$suppressed failure$(if ($suppressed -ne 1) {'s'}) suppressed - see $logFile"
        } else {
            "See $logFile"
        }
        Format-AnsiText $hint 93
    }
}

function Format-AnsiText {
    param(
        [string] $Text,
        [int] $ColorCode
    )
    return "`e[$($ColorCode)m$Text`e[0m"
}
