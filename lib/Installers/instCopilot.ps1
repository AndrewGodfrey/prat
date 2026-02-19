# Sync selected .copilot subdirectories to a sync folder (OneDrive, Dropbox, etc.)
# using directory junctions.
#
# $syncRoot: The sync folder root for copilot data, e.g. "$home\OneDrive\.copilot-sync"
# $copilotDir: Override for testing. Defaults to "$home\.copilot".
function Install-CopilotSyncFolders($stage, [string] $syncRoot, [string] $copilotDir = "$home\.copilot") {
    $syncDirs = @("session-state")

    # ide: IDE integration data
    # marketplace-cache: extension marketplace cache
    # pkg: package data
    $knownLocalDirs = @("ide", "marketplace-cache", "pkg")

    Install-SyncFolders $stage ".copilot" $copilotDir $syncRoot $syncDirs $knownLocalDirs
}
