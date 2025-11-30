# .SYNOPSIS
# Given a location/pwd, loads & normalizes the relevant 'cbTable.*.ps1' file.
# Compare with Get-CodebaseTable.ps1 (which needs to be renamed for clarity).

using module PratBase\PratBase.psd1

[CmdletBinding()]
param ([string] $Location = $pwd)

function normalizeTableItem($item, $key, $cbFile) {
    $item.id = $key
    if ($null -eq $item.root) {
        # In this case, we'd expect $cbFile to have just one entry in it, describing the codebase rooted at the same location as $cbFile
        $item.root = Split-Path -parent $cbFile
    }

    # Remove trailing \ from subdirectories, but leave cases like "F:\" alone.
    if ($item.root.EndsWith([IO.Path]::DirectorySeparatorChar)) {
        if ((Split-Path -parent $item.root) -ne "") {
            $item.root = $item.root.SubString(0, $item.root - 1)
        }
    }
    return $item
}

$Location = Resolve-Path $Location
$cbFile = &$PSScriptRoot\Get-ContainingItem "cbTable.*.ps1" $Location
if ($null -eq $cbFile) { return $null }

Write-Verbose "Get-CodebaseTables: Load: $cbFile"

$cbTable = . $cbFile
# TODO: Validate cbTable. For one thing, the keys should -match '^[a-z0-9_]+$'.

$result = @{}

foreach ($key in $cbTable.Keys) {
    Write-Verbose "Get-CodebaseTables: Adding: $key"
    $item = normalizeTableItem $cbTable[$key] $key $cbFile
    $result[$key] = $item
}

return $result

