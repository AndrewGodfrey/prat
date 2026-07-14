# .SYNOPSIS
# Given a path to a directory:
#   If the directory doesn't exist: Exits without an error.
#   Otherwise: Applies the given deletion policy recursively - deleting
#      all files older than the given number of days. (By CreationTime, not LastWriteTime).
#
# On access-denied, grants the current user access (icacls) and retries; warns only if the retry
# also fails. Other errors are non-fatal - it's assumed the cause is temporary.

param(
    [string] $path = $(throw ("path parameter is required")),
    [int] $retentionDays = $(throw ("retentionDays parameter is required")),
    [string] $optionalFilenameMatch = "")

function FilenameIsDeletionCandidate([string] $filename, [string] $reportFilename, [string] $optionalFilenameMatch) {
    if ($filename -Match "^$reportFilename$") {
        return $false
    }

    if (($null -ne $optionalFilenameMatch) -and ($filename -NotMatch $optionalFilenameMatch)) {
        return $false
    }

    return $true
}

function IsOldDeletableFile($item, $threshold, [string] $reportFilename, [string] $optionalFilenameMatch) {
    return (!$item.PSIsContainer -and $item.CreationTime -lt $threshold -and
        (FilenameIsDeletionCandidate $item.Name $reportFilename $optionalFilenameMatch))
}

function GetDeletionReport($retentionDays, $optionalFilenameMatch, $date = (Get-Date)) {
    "$retentionDays days"
    if ($optionalFilenameMatch -ne "") {
        "Only filenames matching Powershell regex: $optionalFilenameMatch"
    }
    ""
    "Last run: " + $date
}

# Best-effort: grant the current user full control over $target and everything under it.
function GrantSelfAccess([string] $target) {
    icacls $target /grant "$($env:USERNAME):F" /T /C /Q *> $null
}

function RemoveDirectory($item) {
    $item | Remove-Item -Force -Recurse -ErrorAction Stop
}

# Delete the old files under $root. Returns the paths that failed: subtrees that couldn't be
# enumerated, and files whose deletion failed.
function RemoveOldFiles([string] $root, $threshold, [string] $reportFilename, [string] $optionalFilenameMatch) {
    $failed = @()
    $enumErrors = @()
    $oldFiles = @(Get-ChildItem -Path $root -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable enumErrors |
        Where-Object { IsOldDeletableFile $_ $threshold $reportFilename $optionalFilenameMatch })
    foreach ($file in $oldFiles) {
        try {
            Remove-Item $file.FullName -Force -ErrorAction Stop
        } catch {
            $failed += $file.FullName
        }
    }
    $failed += @($enumErrors | ForEach-Object { "$($_.TargetObject)" })
    return @($failed | Where-Object { $_ })
}

# Retry one failed path (after GrantSelfAccess). Returns the paths that still fail.
function RetryFailedPath([string] $target, $threshold, [string] $reportFilename, [string] $optionalFilenameMatch) {
    if (Test-Path -PathType Container $target) {
        return RemoveOldFiles $target $threshold $reportFilename $optionalFilenameMatch
    }
    if (!(Test-Path $target)) { return @() }
    try {
        Remove-Item $target -Force -ErrorAction Stop
        return @()
    } catch {
        return @($target)
    }
}

if ($MyInvocation.InvocationName -ne ".") {
    if (!(Test-Path -PathType Container $path)) {
        Write-Host -ForegroundColor Green "Ignoring: $path"
        return
    }

    Write-Host -ForegroundColor Yellow "Cleaning: $path ($retentionDays days)"

    $ErrorActionPreference = "continue"

    $reportFilename = "deletion_report.txt"

    $threshold = (Get-Date).AddDays(-$retentionDays)

    # Delete old files (by CreationTime, not LastWriteTime); on failure, grant ourselves access and retry
    $warned = @{}
    $failed = @(RemoveOldFiles $path $threshold $reportFilename $optionalFilenameMatch | Sort-Object -Unique)
    foreach ($target in $failed) {
        GrantSelfAccess $target
        foreach ($f in @(RetryFailedPath $target $threshold $reportFilename $optionalFilenameMatch)) {
            Write-Warning "Failed to clean '$f' (even after granting access)"
            $warned[$f] = $true
            $warned[$target] = $true
        }
    }

    # Now, delete any old empty directories left behind. (A subtree that denies enumeration even
    # after the grant above looks empty here; its removal failure is already covered by $warned.)
    Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.PSIsContainer -and $_.CreationTime -lt $threshold -and
            ($null -eq (Get-ChildItem -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { !$_.PSIsContainer })) } |
        ForEach-Object {
            $dir = $_
            try {
                RemoveDirectory $dir
            } catch {
                if (!$warned[$dir.FullName]) { Write-Warning "Failed to remove old directory '$($dir.FullName)'" }
            }
        }

    # Write report file
    $report = GetDeletionReport $retentionDays $optionalFilenameMatch
    Write-Output $report > "$path\$reportFilename"
}
