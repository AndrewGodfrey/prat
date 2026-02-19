# Sync selected .copilot subdirectories to a sync folder (OneDrive, Dropbox, etc.)
# using directory junctions.
#
# $syncRoot: The sync folder root for copilot data, e.g. "$home\OneDrive\.copilot-sync"
# $copilotDir: Override for testing. Defaults to "$home\.copilot".
function Install-CopilotSyncFolders($stage, [string] $syncRoot, [string] $copilotDir = "$home\.copilot") {
    if (-not (Test-Path -PathType Container $syncRoot)) {
        mkdir $syncRoot -Force | Out-Null
    }

    # Directories to junction into the sync folder.
    $syncDirs = @("session-state")

    foreach ($dir in $syncDirs) {
        Install-DirectoryJunction $stage "$syncRoot\$dir" "$copilotDir\$dir" -MigrateExisting
    }

    # Warn about unknown directories. Files are left alone - we haven't seen any
    # that need syncing, and tracking them by name adds maintenance burden for no benefit.
    # ide: IDE integration data
    # marketplace-cache: extension marketplace cache
    # pkg: package data
    $knownDirs = $syncDirs + @("ide", "marketplace-cache", "pkg")

    if (Test-Path -PathType Container $copilotDir) {
        $entries = Get-ChildItem $copilotDir -Force -Directory
        foreach ($entry in $entries) {
            $name = $entry.Name
            if ($name -notin $knownDirs) {
                Write-Warning "Unknown directory in .copilot: '$name' - consider adding to sync or known-local list"
            }
        }
    }
}
