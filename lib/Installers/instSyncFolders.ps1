# Move selected subdirectories of an app's config folder to a sync folder (OneDrive, Dropbox, etc.),
# using directory junctions. Any existing contents are migrated to $syncRoot first.
#
# $appName: Display name for warnings, e.g. ".claude"
# $appDir: The app's config directory, e.g. "$home\.claude"
# $syncRoot: The sync folder root, e.g. "$home\OneDrive\.claude-sync"
# $syncDirs: Directories to junction into the sync folder
# $knownLocalDirs: Additional directories that are expected but should stay local
function Install-SyncFolders($stage, [string] $appName, [string] $appDir, [string] $syncRoot, [string[]] $syncDirs) {
    if (-not (Test-Path -PathType Container $syncRoot)) {
        mkdir $syncRoot -Force | Out-Null
    }

    foreach ($dir in $syncDirs) {
        Install-DirectoryJunction $stage "$syncRoot\$dir" "$appDir\$dir" -MigrateExisting
    }
}
