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

function Format-AnsiText {
    param(
        [string] $Text,
        [int] $ColorCode
    )
    return "`e[$($ColorCode)m$Text`e[0m"
}
