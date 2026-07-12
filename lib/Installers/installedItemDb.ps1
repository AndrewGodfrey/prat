# Set-InstalledItemVersion, Get-InstalledItemVersion, Test-InstalledItemVersion:
# 
# Keeps track of what version of each item has been installed e.g. for the current user.
#
# Formats:
# $itemId: A string containing [A-Za-z0-9_/]+.
#    '/' symbols are for nesting and (in the current schema at least) create actual subdirectories.
# 
# Examples for $itemIdAndVersion:
#   "Shortcuts/DE/props:1.1"
#   "gitrepos/llamacpp/VSDevCmd"

function getSchemaVersionFile($dbLocation) { return "$dbLocation\installationDb.schemaVersion.txt" }

# Schema 1.0 means:
#   - Each record is a separate file. Filenames are a particular mapping from $itemId.
#   - Each file simply holds a version number.
function getCurrentSchemaVersion { return "1.0" }

function checkSchemaVersion($dbLocation) {
    $actualVersion = Get-Content (getSchemaVersionFile $dbLocation)
    $expectedVersion = (getCurrentSchemaVersion)
    if ($actualVersion -ne $expectedVersion) {
        throw "Schema version mismatch. Expected: '$expectedVersion'  Actual: '$actualVersion'"
    }
}

function ensureDb($dbLocation) {
    if (-not (Test-Path -PathType Container $dbLocation)) {
        New-Subfolder $dbLocation

        # Create schema version file.
        Set-Content (getSchemaVersionFile $dbLocation) (getCurrentSchemaVersion)
    }
}

function getStateFilePath($dbLocation, $itemId) { 
    if ($itemId -notmatch '^[a-z0-9][a-z0-9_/\\]*$') {
        throw "Unsupported format for itemId '$itemId'. Use only alphanumeric, underscore and slash; first char an alphanumeric."
    }
    return "$dbLocation\$itemId.txt" 
}

function getForkpointCacheStateFilePath($dbLocation, $itemId) {
    if ($itemId -notmatch '^[a-z0-9][a-z0-9_/\\]*$') {
        throw "Unsupported format for itemId '$itemId'. Use only alphanumeric, underscore and slash; first char an alphanumeric."
    }
    return "$dbLocation\_forkpointCache\$itemId.ps1"
}

function getItemStateFilePath($dbLocation, $itemId) {
    if ($itemId -notmatch '^[a-z0-9][a-z0-9_/\\]*$') {
        throw "Unsupported format for itemId '$itemId'. Use only alphanumeric, underscore and slash; first char an alphanumeric."
    }
    return "$dbLocation\_state\$itemId.txt"
}

# Set/update a version record for a given installed item.
function Set-InstalledItemVersion($dbLocation, $itemId, $newVersion = "1.0") {
    ensureDb $dbLocation
    checkSchemaVersion $dbLocation

    $stateFilePath = getStateFilePath $dbLocation $itemId

    New-FolderAndParents (Split-Path $stateFilePath -parent)
    Set-Content $stateFilePath $newVersion
}


# Get the version record for a given installed item ($null if not present)
function Get-InstalledItemVersion($dbLocation, $itemId) {
    if (-not (Test-Path -PathType Container $dbLocation)) { 
        # This is expected for a 'clean install' situation. If the DB location doesn't exist, then it's treated as an empty db so that
        # callers can begin installing things.
        return $null 
    }
    # Otherwise: Validate the schema version first
    checkSchemaVersion $dbLocation

    $stateFilePath = getStateFilePath $dbLocation $itemId
    if (-not (Test-Path $stateFilePath)) { return $null }
    $currentVersion = Get-Content $stateFilePath
    return $currentVersion
}

# Arbitrary-string state for an item, compared by equality (not the numeric version-ordering of
# Set/Get-InstalledItemVersion). Use for "what did we apply last time on this machine" state that
# doesn't fit a monotonic version - e.g. the agent ACL grant spec (see Install-LocalAgentSandbox).
# Stored under _state\ (mirrors _forkpointCache\); read with -Raw so multi-line content round-trips.
function Set-InstalledItemState($dbLocation, $itemId, $value) {
    ensureDb $dbLocation
    checkSchemaVersion $dbLocation

    $stateFilePath = getItemStateFilePath $dbLocation $itemId
    New-FolderAndParents (Split-Path $stateFilePath -parent)
    Set-Content $stateFilePath $value -NoNewline
}

# Get an item's state string ($null if the db or the item's state file is absent).
function Get-InstalledItemState($dbLocation, $itemId) {
    if (-not (Test-Path -PathType Container $dbLocation)) { return $null }
    checkSchemaVersion $dbLocation

    $stateFilePath = getItemStateFilePath $dbLocation $itemId
    if (-not (Test-Path $stateFilePath)) { return $null }
    return (Get-Content $stateFilePath -Raw)
}

# Note: Throws if the installed version is GREATER than expected. We expect version numbers to always go up.
#       For a downgrade, do a migration step or something - that's an error-prone situation that deserves thought.
function Test-InstalledItemVersion($dbLocation, $itemId, $expectedVersion = "1.0") {
    $currentVersion = Get-InstalledItemVersion $dbLocation $itemId
    if ($null -eq $currentVersion) { return $false }
    if ($currentVersion -eq $expectedVersion) { return $true }

    $currentVersion = [System.Version] $currentVersion
    $expectedVersion = [System.Version] $expectedVersion

    if ($currentVersion -lt $expectedVersion) { return $false }

    throw "Unexpected: $itemId" + ": Current version is newer: $currentVersion > $expectedVersion"
}


# Rare use case: Clear a record, e.g. if a previous step needs to be redone and it recreates something that depends on this step.
function Remove-InstalledItem($dbLocation, $itemId) {
    if (-not (Test-Path -PathType Container $dbLocation)) { return }

    checkSchemaVersion $dbLocation

    $stateFilePath = getStateFilePath $dbLocation $itemId
    if (-not (Test-Path $stateFilePath)) { return }
    Remove-Item $stateFilePath
}

