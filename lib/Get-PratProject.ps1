# .SYNOPSIS
# An extension of Get-PratRepo.
# Useful for codebases that have sub-projects.
#
# Uses the 'subprojects' property to decide which project we're in. (Picks the longest-prefix match).
# If no project is found, returns what Get-PratRepo returns.
using module PratBase\PratBase.psd1

[CmdletBinding()]
param ([string] $Location = $pwd)

$Location = Resolve-Path $Location
$repo = &$PSScriptRoot/Get-PratRepo $Location
if ($null -eq $repo) { return $null }

Write-Verbose "Search subprojects for $($repo.id)"
[System.IO.DirectoryInfo] $locationDI = $Location

$longestMatch = @{ key = $null; dest = "" }

if ($null -ne $repo.subprojects) {
    foreach ($key in $repo.subprojects.Keys) {
        $subproject = $repo.subprojects[$key]
        $dest = $repo.root + "/" + $subproject.path
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
}

if ($null -eq $longestMatch.key) {
    return $repo
}
Write-Verbose "Found: $($longestMatch.key)"
$matchedSubproject = $repo.subprojects[$longestMatch.key]
$item = @{
    parentId = $repo.id
    id       = "$($repo.id)/$($longestMatch.key)"
    root     = $longestMatch.dest
    subdir   = $(Get-RelativePath $longestMatch.dest $Location)
}

if ($null -ne $matchedSubproject.workspace) {
    $item.workspace = $matchedSubproject.workspace
}

# Inherit any properties, that aren't already overridden, from $repo.
#   e.g. it's useful for these properties: 'buildKind', 'workspace', 'cachedEnvDelta'
foreach ($key in $repo.Keys) {
    if (!$item.ContainsKey($key)) { # Using ContainsKey, so that subtables can override a non-null value with $null if they really want to.
        $item[$key] = $repo[$key]
    }
}

return $item
