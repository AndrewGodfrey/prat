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
# and emits a hint (log file path, suppression count) when there are failures.
#
# $Passed/$Failed accept $null to signal "no result parsed" (yellow summary, fallback text).
function Write-TestRunResult {
    param(
        [hashtable] $CoverageData = $null,
        $Passed = $null,
        $Failed = $null,
        [TimeSpan] $Elapsed = [TimeSpan]::Zero,
        [int] $FailuresSeen = 0,
        [string] $RunDir,
        [int] $FailureThreshold = 5,
        [string] $FatalError = $null
    )
    $failedCount = if ($null -ne $Failed) { [int]$Failed } else { 0 }
    $durationStr = Format-Duration $Elapsed.TotalSeconds

    $coverageMet = $CoverageData -and $CoverageData.Pct -ge $CoverageData.Target
    $covText = if ($CoverageData) {
        $targetSuffix = if ($coverageMet) { "" } else { " / $($CoverageData.Target)%" }
        "Covered $($CoverageData.Pct)%$targetSuffix. $($CoverageData.Covered)/$($CoverageData.Total) $($CoverageData.Unit) in $($CoverageData.FileCount) Files."
    } else { $null }

    $passFailText = if ($null -ne $Passed -and $null -ne $Failed) {
        "Passed: $Passed, Failed: $Failed. $durationStr"
    } elseif ($FatalError) {
        "Test run failed ($FatalError, no result parsed). $durationStr"
    } else {
        "Test run completed (no result parsed). $durationStr"
    }

    $plainSummary = (@($covText, $passFailText) | Where-Object { $_ }) -join " "

    $colorCode = if ($FatalError) { 91 }
                 elseif ($null -eq $Failed) { 93 }
                 elseif ($failedCount -gt 0) { if ($failedCount -ge $FailureThreshold) { 91 } else { 93 } }
                 else { 92 }

    $plainSummary | Out-File "$RunDir/summary.txt" -Encoding utf8NoBOM

    # When all tests pass but coverage is below target, color coverage yellow within the green line.
    if ($covText -and -not $coverageMet -and $colorCode -eq 92) {
        (Format-AnsiText $covText 93) + " " + (Format-AnsiText $passFailText 92)
    } else {
        Format-AnsiText $plainSummary $colorCode
    }

    if ($FatalError) {
        $logFile = ("$RunDir/test-run.txt") -replace '\\', '/'
        if (Test-Path $logFile) {
            Get-Content $logFile -Tail 20 | ForEach-Object { Format-AnsiText $_ 91 }
        }
        Format-AnsiText "See $logFile" 93
    } elseif ($failedCount -gt 0) {
        $logFile = ("$RunDir/test-run.txt") -replace '\\', '/'
        $suppressed = $failedCount - $FailuresSeen
        $hint = if ($suppressed -gt 0) {
            "$suppressed failure$(if ($suppressed -ne 1) {'s'}) suppressed - see $logFile"
        } else {
            "See $logFile"
        }
        Format-AnsiText $hint 93
    }
}

# Merge-TestSummary: Combines N PassThru result objects (from Invoke-TestWithSummary) into a
# single summary line. Coverage counts are merged using unit weighting (1 command = 1, 1 line|block = 3).
# Unit name is preserved when all sides share the same unit; when mixing units, the coarsest
# (lowest-rank) unit name is used with an "-ish" suffix (e.g. "commands-ish", "lines-ish").
function Merge-TestSummary {
    param(
        [hashtable[]] $Summaries,
        [TimeSpan]    $Elapsed
    )

    $errors = $Summaries | ForEach-Object { $_.FatalError } | Where-Object { $_ }
    $fatalError = if ($errors) { $errors -join '; ' } else { $null }
    $passed = if ($fatalError) { $null } else { ($Summaries | ForEach-Object { $_.Passed ?? 0 } | Measure-Object -Sum).Sum }
    $failed = if ($fatalError) { $null } else { ($Summaries | ForEach-Object { $_.Failed ?? 0 } | Measure-Object -Sum).Sum }

    # Granularity rank: commands < lines ≈ blocks ≈ instructions < branches. Used to pick the "-ish" label when units differ.
    $unitRank   = @{ commands = 1; lines = 2; blocks = 2; instructions = 2; branches = 3 }
    $unitWeight = @{ commands = 1; lines = 3; blocks = 3; instructions = 3; branches = 3 }
    $withCoverage = @($Summaries | Where-Object { $_.CoverageData })
    if ($withCoverage) {
        $coveredRaw = 0; $totalRaw = 0; $coveredW = 0; $totalW = 0; $fileCount = 0; $target = $null; $units = @()
        foreach ($s in $withCoverage) {
            $d = $s.CoverageData
            $w = $unitWeight[$d.Unit] ?? 1
            $coveredRaw += $d.Covered
            $totalRaw   += $d.Total
            $coveredW   += $d.Covered * $w
            $totalW     += $d.Total   * $w
            $fileCount  += $d.FileCount
            if (-not $target) { $target = $d.Target }
            $units += $d.Unit
        }
        $distinctUnits = @($units | Sort-Object -Unique)
        $sameUnit = $distinctUnits.Count -eq 1
        if ($sameUnit) {
            $unit    = $distinctUnits[0]
            $covered = $coveredRaw
            $total   = $totalRaw
        } else {
            $lowestRankUnit = $distinctUnits | Sort-Object { $unitRank[$_] ?? 99 } | Select-Object -First 1
            $unit    = "$lowestRankUnit-ish"
            $covered = $coveredW
            $total   = $totalW
        }
        if ($total -gt 0) {
            $pct = [int][math]::Round($covered * 10000.0 / $total) / 100
            $covData = @{ Pct = $pct; Target = $target; Covered = $covered; Total = $total; Unit = $unit; FileCount = $fileCount }
        }
    }

    $failuresSeen     = ($Summaries | ForEach-Object { $_.FailuresSeen     ?? 0 } | Measure-Object -Sum).Sum
    $failureThreshold = ($Summaries | ForEach-Object { $_.FailureThreshold ?? 0 } | Measure-Object -Sum).Sum
    $runDir           = ($Summaries | Where-Object { $_.RunDir } | Select-Object -First 1).RunDir

    Write-TestRunResult `
        -CoverageData     $covData `
        -Passed           $passed `
        -Failed           $failed `
        -Elapsed          $Elapsed `
        -FailuresSeen     $failuresSeen `
        -FailureThreshold $failureThreshold `
        -RunDir           $runDir `
        -FatalError       $fatalError
}

# .SYNOPSIS
# Post-processes a Cobertura XML coverage file for Coverage Gutters compatibility:
# - Adds <sources><source>.</source></sources> if missing (prevents parser crash)
# - Strips given path prefixes from filename attributes (enables workspace-relative matching)
function Convert-CoberturaXmlFile {
    param(
        [string] $Path,
        [string[]] $PathPrefixes = @()
    )
    [xml]$xml = Get-Content $Path -Raw

    # Resolve source root and ensure <sources> element is present
    $sourceNodes = $xml.SelectNodes("/coverage/sources/source")
    if ($sourceNodes.Count -gt 1) {
        throw "Convert-CoberturaXmlFile: multiple <source> elements are not supported (found $($sourceNodes.Count))"
    }
    if ($sourceNodes.Count -eq 0) {
        # dotnet-coverage case: no <sources>, filenames are already absolute.
        # Add placeholder source so Coverage Gutters doesn't crash.
        $sources = $xml.CreateElement("sources")
        $source  = $xml.CreateElement("source")
        $source.InnerText = "."
        $sources.AppendChild($source) | Out-Null
        $xml.coverage.PrependChild($sources) | Out-Null
        $sourceRoot = $null
    } else {
        # coverlet case: one <source>, filenames are relative to it.
        $sourceRoot = ($sourceNodes[0].InnerText -replace '\\', '/').TrimEnd('/')
    }

    $anyStripped = $false
    foreach ($node in $xml.SelectNodes("//*[@filename]")) {
        $filename = $node.GetAttribute("filename") -replace '\\', '/'
        $absolutePath = if ($sourceRoot) { "$sourceRoot/$filename" } else { $filename }
        foreach ($prefix in $PathPrefixes) {
            $normalizedPrefix = ($prefix.TrimEnd('/\') -replace '\\', '/') + '/'
            if ($absolutePath.StartsWith($normalizedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                $node.SetAttribute("filename", $absolutePath.Substring($normalizedPrefix.Length))
                $anyStripped = $true
                break
            }
        }
    }

    # When filenames have been made workspace-relative, update <source> to "." so that
    # Coverage Gutters doesn't re-join the old source root with the now-relative filenames,
    # producing a wrong absolute path.
    if ($anyStripped) {
        $xml.SelectNodes("/coverage/sources/source") | ForEach-Object { $_.InnerText = "." }
    }

    $xml.Save($Path)
}

# .SYNOPSIS
# Returns the absolute folder paths from a VS Code .code-workspace file, for use as
# PathPrefixes with Convert-CoberturaXmlFile.
#
# Workspace files commonly use relative folder paths (e.g. "." or "../sibling"). These must
# be resolved to absolute paths before they can be used as prefixes to strip from coverage
# filenames — coverage tools emit absolute paths, so the prefix must also be absolute.
function Get-PathPrefixesFromWorkspace {
    param([string] $WorkspaceFile)
    $workspace = Get-Content $WorkspaceFile -Raw | ConvertFrom-Json
    $workspaceDir = Split-Path $WorkspaceFile -Parent
    return $workspace.folders | ForEach-Object {
        # GetFullPath handles both absolute paths and relative ones (resolved against workspaceDir).
        # Join-Path is not used because it doesn't treat forward-slash absolute paths (e.g. "C:/foo")
        # as rooted on Windows, causing them to be joined as if relative.
        [System.IO.Path]::GetFullPath($_.path, $workspaceDir) -replace '\\', '/'
    }
}

function Format-AnsiText {
    param(
        [string] $Text,
        [int] $ColorCode
    )
    return "`e[$($ColorCode)m$Text`e[0m"
}
