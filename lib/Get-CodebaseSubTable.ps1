# An extension of Get-CodebaseTable.
# Useful for codebases that have sub-projects.
#
# Uses the 'shortcuts' list to decide which project we're in. (Only works for locations that have exactly one shortcut).
# If no project is found, returns what Get-CodebaseTable returns.
using module PratBase\PratBase.psd1

[CmdletBinding()]
param ([string] $Location = $pwd)

$Location = Resolve-Path $Location
$cbt = &$PSScriptRoot/Get-CodebaseTable $Location
if ($null -eq $cbt) { return $null }

Write-Verbose "Search shortcuts for $($cbt.id)"
[System.IO.DirectoryInfo] $locationDI = $Location

$longestMatch = @{ key = $null; dest = "" }

foreach ($key in $cbt.shortcuts.Keys) {
    if ($cbt.shortcuts[$key] -eq "") { continue }

    $dest = $cbt.root + "/" + $cbt.shortcuts[$key]
    Write-Verbose "Considering: $key"
    [System.IO.DirectoryInfo] $destDI = $dest
    Write-Verbose "Compare: '$($destDI.FullName)' vs '$($locationDI.FullName)'"
    if ($locationDI.FullName.StartsWith($destDI.FullName, 'InvariantCultureIgnoreCase')) {
        Write-Verbose "Found: $key"
        if ($dest.Length -gt ($longestMatch.dest.Length)) {
            $longestMatch.key = $key
            $longestMatch.dest = $dest
        }
    }
}

if ($null -eq $longestMatch.key) {
    # TODO: Make an object more similar in type to the other cases - don't want 'subworkspaces' or 'shortcuts' properties
    # TODO: Maybe we can hide Get-CodebaseTable completely behind Get-CodebaseSubTable? Change what we call a 'codebase' to refer to this object, unrelated to a repo.
    return $cbt
}
Write-Verbose "Found: $($longestMatch.key)"
$item = @{
    cbt = $cbt
    id = "$($cbt.id)/$($longestMatch.key)"
    root = $longestMatch.dest
    subdir = $(Get-RelativePath $longestMatch.dest $Location)
}

if ($null -ne $cbt.subworkspaces) {
    if ($cbt.subworkspaces.Keys.Contains($longestMatch.key)) {
        $item.workspace = $cbt.subworkspaces[$longestMatch.key]
    }
}

# Inherit any properties, that aren't already overridden, form $cbt. 
#   e.g. it's useful for these properties: 'buildKind', 'workspace', 'cachedEnvDelta'
foreach ($key in $cbt.Keys) {
    if (!$item.ContainsKey($key)) { # Using ContainsKey, so that subtables can override a non-null value with $null if they really want to.
        $item[$key] = $cbt[$key]
    }
}

return $item
