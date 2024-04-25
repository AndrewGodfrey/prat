# Given a location/pwd, finds what codebase it's 'in'.
# This controls the behavior of various other tools.
#
# Relies on information kept in '*.cbTable.ps1' files.
# These can either be included in a git repo (for projects you own), or
# in a parent folder.
# 
#
# Limitations: 
#   Currently, only the nearest parent directory containing a cbTable.ps1 file is used.
#   I could imagine one day needing to override a *.cbTable.ps1 that's checked in.
#
# Design: 
#   The contents of a *.cbTable.ps1 files need to be kept simple, because they are going to be executed by the prompt when the current directory
#   changes. I tried putting a scriptblock for 'howToTest' in there and had problems that were hard to debug. So, making it a string instead
#   and avoiding scriptblocks.
using module PratBase\PratBase.psd1

[CmdletBinding()]
param ([string] $Location = $pwd)

function normalizeTableItem($item, $key, $cbFile) {
    $item.id = $key
    if ($item.root -eq $null) {
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

$cbFile = &$PSScriptRoot\Get-ContainingItem "*.cbTable.ps1" $Location
if ($cbFile -eq $null) { return $null }

$cbTable = . $cbFile

[System.IO.DirectoryInfo] $locationDI = $Location

$results = @()

foreach ($key in $cbTable.Keys) {
    $item = normalizeTableItem $cbTable[$key] $key $cbFile
    [System.IO.DirectoryInfo] $rootDI = $item.root
    if ($locationDI.FullName.StartsWith($rootDI.FullName)) {
        Write-Verbose "Found: $(ConvertTo-Expression $item)"
        $results += $item
    }
}

if ($results.Length -eq 0) { return $null }
if ($results.Length -gt 1) { throw "Found too many matches in $cbFile" }

$item = $results[0]
$item.subdir = Get-RelativePath $item.root $Location
return $item

