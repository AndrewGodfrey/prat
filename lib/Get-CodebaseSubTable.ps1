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
    if ($locationDI.FullName.StartsWith($destDI.FullName)) {
        Write-Verbose "Found: $key"
        if ($dest.Length -gt ($longestMatch.dest.Length)) {
            $longestMatch.key = $key
            $longestMatch.dest = $dest
        }
    }
}

if ($null -eq $longestMatch.key) { return $cbt }
Write-Verbose "Found: $($longestMatch.key)"
$item = @{
    cbt = $cbt
    id = "$($cbt.id)/$($longestMatch.key)"
    root = $longestMatch.dest
    buildKind = $cbt.buildKind
}
$item.subdir = Get-RelativePath $item.root $Location

return $item
