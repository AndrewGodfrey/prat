# .SYNOPSIS
# Given a path to a directory:
#   If the directory doesn't exist: Exits without an error.
#   Otherwise: Applies the given file retention policy recursively - deleting
#      all files older than the given number of days. (By CreationTime, not LastWriteTime).
# 
# On error, continues to delete other files, but doesn't do much about the error. It's assumed the cause is temporary.

param(
    [string] $path = $(throw ("path parameter is required")),
    [int] $retentionDays = $(throw ("retentionDays parameter is required")),
    [string] $optionalFilenameMatch="")


function FilenameIsUnderRetention([string] $filename, [string] $reportFilename, [string] $optionalFilenameMatch) {
#    Write-Host $filename
    if ($filename -Match "^$reportFilename$") {
        return $false
    }

    if (($null -ne $optionalFilenameMatch) -and ($filename -NotMatch $optionalFilenameMatch)) {
        return $false
    }

    return $true
}

function GetReport {
    "$retentionDays days"
    if ($optionalFilenameMatch -ne "") {
        "Only filenames matching Powershell regex: $optionalFilenameMatch"
    }
    ""
    "Last run: " + (Get-Date)
}

function RemoveDirectory($item) {
    # get-smbshare | Where-Object { $_.Path -eq "X:\sharedWith\test" } | Remove-SmbShare -Force
    $item | Remove-Item -Force -Recurse
}

if (!(Test-Path -PathType Container $path)) { 
    Write-Host -ForegroundColor Green "Ignoring: $path"
    return 
}

Write-Host -ForegroundColor Yellow "Cleaning: $path ($retentionDays days)"

$ErrorActionPreference = "stop"

$reportFilename = "retentionpolicy.txt"

$threshold = (Get-Date).AddDays(-$retentionDays)
#    Write-Host $threshold

$ErrorActionPreference = "continue"

# Delete old files (by CreationTime, not LastWriteTime)
Get-ChildItem -Path $path -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $threshold -and (FilenameIsUnderRetention $_.Name $reportFilename $optionalFilenameMatch)} | Remove-Item -Force

# Now, delete any old empty directories left behind
Get-ChildItem -Path $path -Recurse -Force | Where-Object { $_.PSIsContainer -and $_.CreationTime -lt $threshold -and ($null -eq (Get-ChildItem -Path $_.FullName -Recurse -Force | Where-Object { !$_.PSIsContainer })) } | % { RemoveDirectory $_ }

# Write report file
$report = GetReport
echo $report > "$path\$reportFilename"

